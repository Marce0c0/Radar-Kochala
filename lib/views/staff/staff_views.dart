import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/report_controller.dart';
import '../../core/presentation_strategies.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../reports/detail_view.dart';
import '../role/role_selection_view.dart';
import '../widgets/report_card.dart';
import '../widgets/status_pill.dart';

// FACADE: función reutilizable que encapsula el proceso completo de cierre de
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

class StaffHubView extends StatefulWidget {
  const StaffHubView({super.key, this.initialSection = 0});
  final int initialSection;
  @override
  State<StaffHubView> createState() => _StaffHubViewState();
}

class _StaffHubViewState extends State<StaffHubView> {
  late int section;
  @override
  void initState() {
    super.initState();
    section = widget.initialSection;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportController>();
    final allReports = controller.reports;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel municipal', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          // Pull-to-refresh desde el app bar.
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<ReportController>().load(),
            tooltip: 'Recargar',
          ),
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => section = value == 'admin' ? 3 : 0),
            itemBuilder: (_) => const [PopupMenuItem(value: 'operator', child: Text('Vista operador')), PopupMenuItem(value: 'admin', child: Text('Vista administrador'))],
          ),
        ],
      ),
      body: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : controller.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(controller.error!, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => context.read<ReportController>().load(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : IndexedStack(index: section, children: [
                  _OperatorBoard(reports: allReports, onOpen: _openReport),
                  const _TeamView(),
                  _StaffMapView(reports: allReports, onOpen: _openReport),
                  const _AdminView(),
                ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: section,
        onDestinationSelected: (value) => setState(() => section = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Bandeja'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Equipo'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Admin'),
        ],
      ),
    );
  }

  void _openReport(Report report) => Navigator.push(context, MaterialPageRoute(builder: (_) => ValidateReportView(report: report)));
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

  // FACADE: delegamos el logout a la función centralizada _logout.
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
                      const _PageIntro(title: 'Mis tareas', subtitle: 'Trabajador de Campo'),
                      _StatsRow(items: [
                        ('${assignedTasks.length}', 'Pendientes'),
                        ('$completedCount', 'Completadas'),
                        ('${_myAssignedReportIds.length}', 'Total'),
                      ]),
                      const SizedBox(height: 18),
                      const _Heading('Asignadas a ti'),
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
        const _PageIntro(title: 'Mi perfil', subtitle: 'Trabajador de Campo'),
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
          const _Heading('Actualizar Estado'),
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
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Adjuntar foto (próximamente)')),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _finalize,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: AppTheme.teal),
            child: const Text('Finalizar Tarea', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _finalize() async {
    if (_note.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor describe el trabajo realizado.')),
      );
      return;
    }
    // Actualiza el estado del reporte a 'resuelto'.
    await context.read<ReportController>().updateStatus(widget.report.id, ReportStatus.resolved);
    // Guarda las notas del trabajador en la tabla assignments.
    try {
      final client = Supabase.instance.client;
      await client.from('assignments')
          .update({
            'worker_notes': _note.text.trim(),
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('report_id', widget.report.id);
    } catch (e) {
      debugPrint('Error al guardar notas: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Tarea marcada como resuelta!')));
      Navigator.pop(context);
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

class _OperatorBoard extends StatelessWidget {
  const _OperatorBoard({required this.reports, required this.onOpen});
  final List<Report> reports;
  final ValueChanged<Report> onOpen;
  
  @override
  Widget build(BuildContext context) {
    final reported = reports.where((r) => r.status == ReportStatus.reported).toList();
    final inProgress = reports.where((r) => r.status == ReportStatus.inProgress || r.status == ReportStatus.reviewing).toList();
    final resolved = reports.where((r) => r.status == ReportStatus.resolved).length;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _PageIntro(title: 'Panel operador', subtitle: 'Distrito Centro · Turno mañana'),
        _StatsRow(items: [('${reported.length}', 'Nuevos'), ('${inProgress.length}', 'En proceso'), ('$resolved', 'Resueltos')]),
        
        const _Heading('Requieren validación (Nuevos)'),
        if (reported.isEmpty) const Text('No hay reportes nuevos', style: TextStyle(color: Colors.grey)),
        ...reported.map((r) => _StaffReport(report: r, action: 'Validar', onTap: () => onOpen(r))),
        
        const _Heading('En proceso'),
        if (inProgress.isEmpty) const Text('No hay tareas en ejecución', style: TextStyle(color: Colors.grey)),
        ...inProgress.map((r) => _StaffReport(report: r, action: 'Ver estado', onTap: () => onOpen(r))),
      ],
    );
  }
}

class _StaffMapView extends StatelessWidget {
  const _StaffMapView({required this.reports, required this.onOpen});
  final List<Report> reports;
  final ValueChanged<Report> onOpen;
  
  @override
  Widget build(BuildContext context) {
    final mapReports = reports.where((r) => r.latitude != null && r.longitude != null && r.status != ReportStatus.resolved).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _PageIntro(title: 'Mapa de activos', subtitle: 'Vista de monitoreo municipal'),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 300,
            child: FlutterMap(
              options: const MapOptions(initialCenter: LatLng(-17.3895, -66.1568), initialZoom: 13.5),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.app'),
                MarkerLayer(
                  markers: mapReports.map((report) => Marker(
                    point: LatLng(report.latitude!, report.longitude!),
                    width: 40, height: 40,
                    child: GestureDetector(
                      onTap: () => onOpen(report),
                      // DECORATOR: DecoratedBox añade apariencia visual al marcador.
                      // STRATEGY: color de categoría delegado al módulo centralizado.
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: categoryColor(report.category),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(categoryIcon(report.category), color: Colors.white, size: 20),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ValidateReportView: ahora carga trabajadores reales y guarda asignación en DB.
class ValidateReportView extends StatefulWidget {
  const ValidateReportView({super.key, required this.report});
  final Report report;
  @override
  State<ValidateReportView> createState() => _ValidateReportViewState();
}

class _ValidateReportViewState extends State<ValidateReportView> {
  late ReportStatus _selectedStatus;
  final _note = TextEditingController();
  List<Map<String, dynamic>> _workers = [];
  String? _selectedWorkerId;
  bool _loadingWorkers = true;

  static const _statusLabels = {
    ReportStatus.reported:   'Reportado',
    ReportStatus.reviewing:  'En revisión',
    ReportStatus.inProgress: 'En proceso',
    ReportStatus.resolved:   'Resuelto',
  };

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.report.status;
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    try {
      final result = await Supabase.instance.client
          .from('profiles')
          .select('id, role')
          .eq('role', 'trabajador');
      if (mounted) {
        setState(() {
          _workers = List<Map<String, dynamic>>.from(result);
          if (_workers.isNotEmpty) _selectedWorkerId = _workers.first['id'].toString();
          _loadingWorkers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingWorkers = false);
    }
  }

  @override
  void dispose() { _note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Validar reporte', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ReportCard(report: widget.report, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailView(report: widget.report)))),
          const _Heading('Actualizar estado'),
          _Segmented(
            options: _statusLabels.values.toList(),
            selected: _statusLabels[_selectedStatus]!,
            onChanged: (label) {
              final entry = _statusLabels.entries.firstWhere((e) => e.value == label);
              setState(() => _selectedStatus = entry.key);
            },
          ),
          const _Heading('Asignar trabajador de campo'),
          if (_loadingWorkers)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (_workers.isEmpty)
            const Text('No hay trabajadores registrados.', style: TextStyle(color: Colors.grey))
          else
            ..._workers.map((w) {
              final id = w['id'].toString();
              final label = 'Trabajador (${id.substring(0, 8)}...)';
              return _WorkerTile(
                name: label,
                selected: _selectedWorkerId == id,
                onTap: () => setState(() => _selectedWorkerId = id),
              );
            }),
          const _Heading('Nota de atención'),
          TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(hintText: 'Instrucciones para el trabajador...')),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _save,
            child: const Text('Guardar y asignar'),
          ),
        ]),
      );

  Future<void> _save() async {
    // Actualiza el estado del reporte.
    await context.read<ReportController>().updateStatus(widget.report.id, _selectedStatus);
    // Si hay un trabajador seleccionado, crea o actualiza la asignación en la BD.
    if (_selectedWorkerId != null) {
      try {
        final client = Supabase.instance.client;
        await client.from('assignments').upsert({
          'report_id': widget.report.id,
          'worker_id': _selectedWorkerId,
          'operator_id': client.auth.currentUser?.id,
          'worker_notes': _note.text.trim(),
          'assigned_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error al guardar asignación: $e');
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte actualizado y asignado')));
      Navigator.pop(context);
    }
  }
}

// Vista de equipo: carga trabajadores reales desde profiles en Supabase.
class _TeamView extends StatefulWidget {
  const _TeamView();
  @override
  State<_TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends State<_TeamView> {
  List<Map<String, dynamic>> _workers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    try {
      final client = Supabase.instance.client;
      // Consulta los perfiles del equipo de campo y operadores.
      final result = await client
          .from('profiles')
          .select('id, role')
          .inFilter('role', ['trabajador', 'operador', 'admin']);
      if (mounted) setState(() { _workers = List<Map<String, dynamic>>.from(result); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _roleLabel(String role) => switch (role) {
    'trabajador' => 'Trabajador de Campo',
    'operador'   => 'Operador · En línea',
    'admin'      => 'Administrador',
    _            => role,
  };

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PageIntro(title: 'Gestión de equipo', subtitle: '${_workers.length} miembros registrados'),
        ..._workers.map((w) => Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.teal,
              child: Text(w['role'].toString()[0].toUpperCase()),
            ),
            title: Text(_roleLabel(w['role'].toString())),
            subtitle: Text('ID: ${w['id'].toString().substring(0, 8)}...'),
          ),
        )),
      ],
    );
  }
}

// Vista admin: muestra estadísticas reales desde Supabase.
class _AdminView extends StatefulWidget {
  const _AdminView();
  @override
  State<_AdminView> createState() => _AdminViewState();
}

class _AdminViewState extends State<_AdminView> {
  Map<String, int> _counts = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final client = Supabase.instance.client;
      final profiles = await client.from('profiles').select('role');
      final rows = List<Map<String, dynamic>>.from(profiles);
      final Map<String, int> counts = {};
      for (final r in rows) {
        final role = r['role'].toString();
        counts[role] = (counts[role] ?? 0) + 1;
      }
      if (mounted) setState(() { _counts = counts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final total = _counts.values.fold(0, (a, b) => a + b);
    final operadores = _counts['operador'] ?? 0;
    final trabajadores = _counts['trabajador'] ?? 0;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _PageIntro(title: 'Panel admin', subtitle: 'Configuración del sistema'),
        // Stats reales desde la BD.
        _StatsRow(items: [('$total', 'Usuarios'), ('$operadores', 'Operadores'), ('$trabajadores', 'Trabajadores')]),
        const _Heading('Gestión'),
        ...['Zonas y distritos', 'Categorías de reportes', 'Notificaciones'].map((title) =>
          ListTile(
            leading: const Icon(Icons.tune, color: AppTheme.teal),
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title abierto'))),
          ),
        ),
        const SizedBox(height: 20),
        // FACADE: logout centralizado.
        FilledButton.icon(
          onPressed: () => _logout(context),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xffd9684b)),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar Sesión del Sistema'),
        ),
      ],
    );
  }
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.title, required this.subtitle});
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.ink)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Color(0xff78908d)))]));
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 18, bottom: 9), child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.ink)));
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => Row(children: items.map((item) => Expanded(child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xffe1e9e6))), child: Column(children: [Text(item.$1, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.teal)), Text(item.$2, style: const TextStyle(fontSize: 10, color: Color(0xff78908d)))])))).toList());
}

class _StaffReport extends StatelessWidget {
  const _StaffReport({required this.report, required this.action, required this.onTap});
  final Report report;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xffdcebe6), child: Icon(Icons.report, color: AppTheme.teal)), title: Text(report.title, maxLines: 1), subtitle: Text('${report.neighborhood} · ${report.time}'), trailing: FilledButton(onPressed: onTap, child: Text(action))));
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.selected, required this.onChanged});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, children: options.map((option) => ChoiceChip(label: Text(option), selected: option == selected, onSelected: (_) => onChanged(option))).toList());
}

class _WorkerTile extends StatelessWidget {
  const _WorkerTile({required this.name, required this.selected, required this.onTap});
  final String name;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(color: selected ? const Color(0xffe5f1ed) : Colors.white, child: ListTile(leading: Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: AppTheme.teal), title: Text(name), subtitle: const Text('En línea'), onTap: onTap));
}