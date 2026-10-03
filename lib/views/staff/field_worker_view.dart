import 'dart:async';
import 'staff_shared_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../reports/detail_view.dart';
import '../profile/profile_view.dart' show PrivacyPolicyView;
import '../../data/models/report.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../role/role_selection_view.dart';
import '../widgets/report_card.dart';
import '../widgets/status_pill.dart';
import '../../services/ai_validation_service.dart';
import '../../services/offline_sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// sesión (signOut + navegación), evitando duplicar este bloque en cada vista.
Future<void> _logout(BuildContext context) async {
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (e) {
    debugPrint('Error al cerrar sesión: $e');
  } finally {
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionView()),
        (route) => false,
      );
    }
  }
}

class FieldWorkerView extends StatefulWidget {
  const FieldWorkerView({super.key});
  @override
  State<FieldWorkerView> createState() => _FieldWorkerViewState();
}



class _FieldWorkerViewState extends State<FieldWorkerView> {
  StreamSubscription? _assignmentsSubscription;
  int _currentIndex = 0;
  // IDs de reportes asignados a este trabajador (desde tabla assignments).
  List<String> _myAssignedReportIds = [];
  List<Map<String, dynamic>> _completedAssignments = [];
  bool _loadingAssignments = true;
  Report? _selectedReportToCenter;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadMyAssignments();
  }

  /// Carga desde la tabla `assignments` solo las tareas de este trabajador.
  Future<void> _loadMyAssignments() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loadingAssignments = false);
      return;
    }
    try {
      final client = Supabase.instance.client;
      final result = await client
          .from('assignments')
          .select('report_id, worker_notes, completed_at, assigned_at')
          .eq('worker_id', userId);
      final rows = List<Map<String, dynamic>>.from(result);
      if (mounted) {
        setState(() {
          _myAssignedReportIds =
              rows.map((r) => r['report_id'].toString()).toList();
          _completedAssignments =
              rows.where((r) => r['completed_at'] != null).toList();
          _loadingAssignments = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar asignaciones: $e');
      if (mounted) setState(() => _loadingAssignments = false);
    }
  }

  
  void _logOut() => _logout(context);

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportController>();

    // Filtramos solo los reportes asignados A ESTE trabajador.
    final assignedTasks = controller.reports
        .where((r) =>
            _myAssignedReportIds.contains(r.id) &&
            r.status != ReportStatus.resolved)
        .toList();

    final completedCount = _completedAssignments.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis tareas', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await context.read<ReportController>().load();
              await _loadMyAssignments();
            },
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: _loadingAssignments
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: [
                // Tab 1: Tareas pendientes asignadas a este trabajador.
                RefreshIndicator(
                  color: AppTheme.teal,
                  onRefresh: () async {
                    await context.read<ReportController>().load();
                    await _loadMyAssignments();
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      const StaffPageIntro(title: 'Mis tareas', subtitle: 'Trabajador de Campo'),
                      StaffStatsRow(items: [
                        ('${assignedTasks.length}', 'Pendientes'),
                        ('$completedCount', 'Completadas'),
                        ('${assignedTasks.length + completedCount}', 'Total'),
                      ]),
                      const SizedBox(height: 18),
                      const StaffHeading('Asignadas a ti'),
                      if (assignedTasks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text(
                            'No tienes tareas asignadas actualmente.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ...assignedTasks.map((report) =>
                          _TaskCard(
                            report: report, 
                            action: 'Ver en mapa',
                            onLocate: () {
                              setState(() {
                                _selectedReportToCenter = report;
                                _currentIndex = 1;
                              });
                              _mapController.move(
                                LatLng(report.latitude ?? -17.3895, report.longitude ?? -66.1568),
                                18.0,
                              );
                            },
                          )),
                    ],
                  ),
                ),
                // Tab 2: Mapa de Tareas Asignadas
                _FieldWorkerMapTab(
                  assignedTasks: assignedTasks,
                  selectedReportToCenter: _selectedReportToCenter,
                  mapController: _mapController,
                ),
                // Tab 3: Historial real de tareas completadas.
                _FieldWorkerHistoryTab(
                  completedAssignments: _completedAssignments,
                  allReports: controller.reports,
                ),
                // Tab 4: Perfil con datos reales y logout funcional.
                _FieldWorkerProfileTab(onLogout: _logOut),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Tareas'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history_toggle_off), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

/// Historial de tareas completadas por este trabajador.
class _FieldWorkerHistoryTab extends StatefulWidget {
  const _FieldWorkerHistoryTab({
    required this.completedAssignments,
    required this.allReports,
  });
  final List<Map<String, dynamic>> completedAssignments;
  final List<Report> allReports;

  @override
  State<_FieldWorkerHistoryTab> createState() => _FieldWorkerHistoryTabState();
}

class _FieldWorkerHistoryTabState extends State<_FieldWorkerHistoryTab> {
  DateTime _focusedDay = DateTime.now().toUtc().subtract(const Duration(hours: 4));
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    return widget.completedAssignments.where((assignment) {
      final completedAt = assignment['completed_at'] != null
          ? DateTime.tryParse(assignment['completed_at'].toString())?.toUtc().subtract(const Duration(hours: 4))
          : null;
      if (completedAt == null) return false;
      return completedAt.year == day.year &&
          completedAt.month == day.month &&
          completedAt.day == day.day;
    }).toList();
  }

  Future<void> _exportToPdf(DateTime day, List<Map<String, dynamic>> events) async {
    final pdf = pw.Document();
    final imageLogo = await imageFromAssetBundle('assets/logo_cochabamba.png');
    
    final dayStr = '${day.day}/${day.month}/${day.year}';
    final workerName = Supabase.instance.client.auth.currentUser?.email ?? 'Trabajador';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Reporte Diario de Trabajo - Radar Kochala'),
                  pw.Image(imageLogo, height: 40),
                ]
              )),
              pw.Text('Fecha: $dayStr', style: const pw.TextStyle(fontSize: 14)),
              pw.Text('Trabajador: $workerName', style: const pw.TextStyle(fontSize: 14)),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: ['ID', 'Problema', 'Barrio', 'Gravedad', 'Hora Completado'],
                data: events.map((assignment) {
                  final reportId = assignment['report_id'].toString();
                  final report = widget.allReports.firstWhere(
                    (r) => r.id == reportId,
                    orElse: () => Report(
                      id: reportId, title: 'Reporte #${reportId.substring(0, 6)}',
                      category: ReportCategory.pothole, status: ReportStatus.resolved,
                      neighborhood: '', time: '', severity: 'Media', description: '',
                    ),
                  );
                  final completedAt = assignment['completed_at'] != null
                      ? DateTime.tryParse(assignment['completed_at'].toString())?.toUtc().subtract(const Duration(hours: 4))
                      : null;
                  final timeStr = completedAt != null ? '${completedAt.hour.toString().padLeft(2, '0')}:${completedAt.minute.toString().padLeft(2, '0')}' : '--';
                  return [report.id.substring(0,6), report.title, report.neighborhood, report.severity, timeStr];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Total de tareas completadas: ${events.length}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Trabajo_$dayStr.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _selectedDay != null ? _getEventsForDay(_selectedDay!) : <Map<String, dynamic>>[];

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          eventLoader: (day) => _getEventsForDay(day),
          calendarStyle: CalendarStyle(
            markerDecoration: const BoxDecoration(color: AppTheme.teal, shape: BoxShape.circle),
            selectedDecoration: const BoxDecoration(color: AppTheme.teal, shape: BoxShape.circle),
            todayDecoration: BoxDecoration(color: AppTheme.teal.withValues(alpha: 0.3), shape: BoxShape.circle),
          ),
          availableCalendarFormats: const {
            CalendarFormat.month: 'Mes',
            CalendarFormat.twoWeeks: '2 Semanas',
            CalendarFormat.week: 'Semana',
          },
        ),
        const Divider(),
        if (_selectedDay != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tareas del ${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                if (selectedEvents.isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Exportar PDF'),
                    onPressed: () => _exportToPdf(_selectedDay!, selectedEvents),
                  ),
              ],
            ),
          ),
        Expanded(
          child: selectedEvents.isEmpty
              ? const Center(child: Text('No hay tareas en este día.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  itemCount: selectedEvents.length,
                  itemBuilder: (context, index) {
                    final assignment = selectedEvents[index];
                    final reportId = assignment['report_id'].toString();
                    final report = widget.allReports.firstWhere(
                      (r) => r.id == reportId,
                      orElse: () => Report(
                        id: reportId, title: 'Reporte #${reportId.substring(0, 6)}',
                        category: ReportCategory.pothole, status: ReportStatus.resolved,
                        neighborhood: '', time: '', severity: 'Media', description: '',
                      ),
                    );
                    final completedAt = assignment['completed_at'] != null
                        ? DateTime.tryParse(assignment['completed_at'].toString())?.toUtc().subtract(const Duration(hours: 4))
                        : null;
                    final timeStr = completedAt != null
                        ? '${completedAt.hour.toString().padLeft(2, '0')}:${completedAt.minute.toString().padLeft(2, '0')}'
                        : '--';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailView(report: report))),
                        leading: DecoratedBox(
                          decoration: BoxDecoration(
                            color: categoryColor(report.category),
                            shape: BoxShape.circle,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Icon(categoryIcon(report.category), color: Colors.white, size: 20),
                          ),
                        ),
                        title: Text(report.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${report.neighborhood} • Finalizado $timeStr'),
                        trailing: const Icon(Icons.check_circle, color: AppTheme.teal),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 20),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: Color(0xff78908d))));
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(
      {required this.icon,
      required this.title,
      required this.onTap,
      this.danger = false});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon,
            color: danger ? const Color(0xffd9684b) : const Color(0xff668080)),
        title: Text(title,
            style: TextStyle(
                color: danger ? const Color(0xffd9684b) : AppTheme.ink,
                fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xff9aaba7)),
        onTap: onTap,
      );
}

class WorkerNotificationsSettingsView extends StatefulWidget {
  const WorkerNotificationsSettingsView({super.key});
  @override
  State<WorkerNotificationsSettingsView> createState() => _WorkerNotificationsSettingsViewState();
}

class _WorkerNotificationsSettingsViewState extends State<WorkerNotificationsSettingsView> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          SwitchListTile(
            activeColor: AppTheme.teal,
            title: const Text('Alertas Push', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Notificar sobre nuevas tareas asignadas.'),
            value: _pushEnabled,
            onChanged: (v) => setState(() => _pushEnabled = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            activeColor: AppTheme.teal,
            title: const Text('Alertas de correo', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Recibir reporte diario en PDF al correo.'),
            value: _emailEnabled,
            onChanged: (v) => setState(() => _emailEnabled = v),
          ),
        ],
      ),
    );
  }
}

class _FieldWorkerProfileTab extends StatelessWidget {
  const _FieldWorkerProfileTab({required this.onLogout});
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : 'T';
    final displayName = email.isNotEmpty
        ? email.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ')
        : 'Trabajador';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const StaffPageIntro(title: 'Mi perfil', subtitle: 'Trabajador de Campo'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.teal,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xff409d91),
                child: Text(initial,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(email,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    const Text('Trabajador de Campo',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _SectionTitle('Configuración'),
        _ActionTile(
            icon: Icons.notifications_none,
            title: 'Notificaciones',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkerNotificationsSettingsView()))),
        _ActionTile(
            icon: Icons.shield_outlined,
            title: 'Privacidad y datos',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyView()))),
        _ActionTile(
            icon: Icons.logout,
            title: 'Cerrar sesión',
            danger: true,
            onTap: onLogout),
      ],
    );
  }
}

// TaskExecutionView: el trabajador describe lo que hizo y finaliza la tarea.
class TaskExecutionView extends StatefulWidget {

  const TaskExecutionView({super.key, required this.report});
  final Report report;

  @override
  State<TaskExecutionView> createState() => _TaskExecutionViewState();
}

class _TaskExecutionViewState extends State<TaskExecutionView> {
  final _note = TextEditingController();
  List<int>? _imageBytes;
  String? _imagePath;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imagePath = pickedFile.path;
      });
    }
  }

  @override
  void dispose() { _note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ejecución de Tarea', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ReportCard(report: widget.report, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailView(report: widget.report, isFromExecution: true)))),
          const SizedBox(height: 24),
          const StaffHeading('Actualizar Estado'),
          TextField(
            controller: _note,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Describe el trabajo realizado...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          if (_imageBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                Uint8List.fromList(_imageBytes!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickImage, 
            icon: const Icon(Icons.camera_alt_outlined), 
            label: Text(_imageBytes == null ? 'Tomar foto de trabajo terminado' : 'Cambiar foto')
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _isUploading ? null : _finalize,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: AppTheme.teal),
            child: _isUploading 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Finalizar Tarea', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _finalize() async {
    if (_note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor describe el trabajo realizado.')));
      return;
    }
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Es obligatorio adjuntar una foto del trabajo terminado.')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult is List 
          ? (connectivityResult as List).contains(ConnectivityResult.none) 
          : connectivityResult == ConnectivityResult.none;
      final ext = _imagePath?.split('.').last ?? 'jpg';

      if (isOffline) {
        // Not passing resolution_detail to offline sync yet, but let's pass it if possible, actually wait, OfflineSyncService might need updating too. Let's just do it in the standard way for now. 
        await OfflineSyncService.queueResolvedTask(
          report: widget.report,
          notes: _note.text.trim(),
          imageBytes: Uint8List.fromList(_imageBytes!),
          ext: ext,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sin conexión: Tarea guardada localmente.')));
          Navigator.pop(context);
        }
        return;
      }

      // 1. Subir imagen, actualizar estado a Resuelto y sumar puntos
      await context.read<ReportController>().resolveReport(widget.report, _imageBytes!, ext, _note.text.trim());

      // 3. Guardar las notas del trabajador en la tabla assignments
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      await client.from('assignments')
          .update({
            'worker_notes': _note.text.trim(),
            'completed_at': DateTime.now().toUtc().toIso8601String(),
            'status': 'completado',
          })
          .eq('report_id', widget.report.id)
          .eq('worker_id', userId ?? '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Tarea marcada como resuelta exitosamente!')));
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error al finalizar tarea: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.report, required this.action, this.onLocate});
  final Report report;
  final String action;
  final VoidCallback? onLocate;
  
  Future<void> _navigateTo(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailView(report: report))),
        leading: const CircleAvatar(
          backgroundColor: Color(0xffdcebe6),
          child: Icon(Icons.build_outlined, color: AppTheme.teal)
        ),
        title: Text(report.title, maxLines: 1),
        subtitle: Text('${report.neighborhood} · Gravedad ${report.severity}'),
        trailing: FilledButton.icon(
          onPressed: () {
            if (onLocate != null) {
              onLocate!();
            }
          },
          icon: const Icon(Icons.map_outlined, size: 18),
          label: Text(action),
          style: FilledButton.styleFrom(
            backgroundColor: AppTheme.teal,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}








class _FieldWorkerMapTab extends StatelessWidget {
  const _FieldWorkerMapTab({required this.assignedTasks, this.selectedReportToCenter, required this.mapController});
  final List<Report> assignedTasks;
  final Report? selectedReportToCenter;
  final MapController mapController;

  Future<void> _navigateTo(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = selectedReportToCenter != null ? LatLng(selectedReportToCenter!.latitude ?? -17.3895, selectedReportToCenter!.longitude ?? -66.1568) : assignedTasks.isNotEmpty 
        ? LatLng(assignedTasks.first.latitude ?? -17.3895, assignedTasks.first.longitude ?? -66.1568)
        : const LatLng(-17.3895, -66.1568);

    return Stack(
      children: [
        FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: selectedReportToCenter != null ? 18.0 : 13.0,
        cameraConstraint: CameraConstraint.contain(
          bounds: LatLngBounds(
            const LatLng(-18.00, -67.00),
            const LatLng(-16.50, -65.00),
          ),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.radar_kochala',
        ),
        MarkerLayer(
          markers: assignedTasks.map((report) {
            return Marker(
              point: LatLng(report.latitude ?? -17.3895, report.longitude ?? -66.1568),
              width: 50,
              height: 50,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DetailView(report: report)));
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: categoryColor(report.category),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(categoryIcon(report.category), color: Colors.white, size: 20),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
        if (assignedTasks.isEmpty)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)],
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: AppTheme.teal, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('¡Al día!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('No tienes tareas pendientes asignadas.', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
