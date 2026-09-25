import 'staff_shared_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
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
  int _currentIndex = 0;
  // IDs de reportes asignados a este trabajador (desde tabla assignments).
  List<String> _myAssignedReportIds = [];
  List<Map<String, dynamic>> _completedAssignments = [];
  bool _loadingAssignments = true;

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
                        ('${_myAssignedReportIds.length}', 'Total'),
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
                          _TaskCard(report: report, action: 'Iniciar')),
                    ],
                  ),
                ),
                // Tab 2: Mapa (por implementar).
                const Center(
                  child: Text(
                    'Mapa de ruta próximo a implementarse',
                    style: TextStyle(color: Colors.grey),
                  ),
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
          NavigationDestination(icon: Icon(Icons.key_outlined), selectedIcon: Icon(Icons.key), label: 'En campo'),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history_toggle_off), label: 'Historial'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

/// Historial de tareas completadas por este trabajador.
class _FieldWorkerHistoryTab extends StatelessWidget {
  const _FieldWorkerHistoryTab({
    required this.completedAssignments,
    required this.allReports,
  });
  final List<Map<String, dynamic>> completedAssignments;
  final List<Report> allReports;

  @override
  Widget build(BuildContext context) {
    if (completedAssignments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 56, color: Color(0xff78908d)),
            SizedBox(height: 12),
            Text('Aún no has completado tareas.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: completedAssignments.length,
      itemBuilder: (context, index) {
        final assignment = completedAssignments[index];
        final reportId = assignment['report_id'].toString();
        final report = allReports.firstWhere(
          (r) => r.id == reportId,
          orElse: () => Report(
            id: reportId, title: 'Reporte #${reportId.substring(0, 6)}',
            category: ReportCategory.pothole, status: ReportStatus.resolved,
            neighborhood: '', time: '', severity: 'Media', description: '',
          ),
        );
        final completedAt = assignment['completed_at'] != null
            ? DateTime.tryParse(assignment['completed_at'].toString())?.toLocal()
            : null;
        final dateStr = completedAt != null
            ? '${completedAt.day}/${completedAt.month}/${completedAt.year}'
            : 'Fecha desconocida';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xffd8eeea),
              child: Icon(Icons.check, color: AppTheme.teal),
            ),
            title: Text(report.title, maxLines: 1),
            subtitle: Text('Completada el $dateStr'),
            trailing: const StatusPill(status: ReportStatus.resolved),
          ),
        );
      },
    );
  }
}


// CORRECCIÓN #13: Pestaña de perfil completa para el trabajador de campo.
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
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onLogout,
          style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd9684b),
              padding: const EdgeInsets.symmetric(vertical: 14)),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar Sesión',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
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
          ReportCard(report: widget.report, onTap: () {}),
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

      // 1. Validar con IA
      final validation = await AiValidationService.validateResolutionImage(
        Uint8List.fromList(_imageBytes!), 
        categoryName(widget.report.category)
      );

      if (validation.contains('INVALIDO')) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La IA determinó que la foto no muestra una reparación válida. Intenta de nuevo.')));
        setState(() => _isUploading = false);
        return;
      }

      // 2. Subir imagen, actualizar estado a Resuelto y sumar puntos
      await context.read<ReportController>().resolveReport(widget.report, _imageBytes!, ext);

      // 3. Guardar las notas del trabajador en la tabla assignments
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      await client.from('assignments')
          .update({
            'worker_notes': _note.text.trim(),
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('report_id', widget.report.id)
          .eq('worker_id', userId ?? '');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Tarea marcada como resuelta y validada por IA!')));
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
  const _TaskCard({required this.report, required this.action});
  final Report report;
  final String action;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xffdcebe6), child: Icon(Icons.build_outlined, color: AppTheme.teal)), title: Text(report.title, maxLines: 1), subtitle: Text('${report.neighborhood} · Gravedad ${report.severity}'), trailing: FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TaskExecutionView(report: report))), child: Text(action))));
}






