import 'staff_shared_widgets.dart';
import 'staff_map_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../reports/detail_view.dart';
import '../role/role_selection_view.dart';
import '../widgets/report_card.dart';
import '../../services/ai_validation_service.dart';

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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Cerrar sesión',
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
                  StaffMapView(reports: allReports, onOpen: _openReport),
                ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: section,
        onDestinationSelected: (value) => setState(() => section = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Bandeja'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Equipo'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
        ],
      ),
    );
  }

  void _openReport(Report report) => Navigator.push(context, MaterialPageRoute(builder: (_) => ValidateReportView(report: report)));
}

class _OperatorBoard extends StatefulWidget {
  const _OperatorBoard({required this.reports, required this.onOpen});
  final List<Report> reports;
  final ValueChanged<Report> onOpen;

  @override
  State<_OperatorBoard> createState() => _OperatorBoardState();
}

class _OperatorBoardState extends State<_OperatorBoard> {
  ReportCategory? _filterCategory;
  bool _onlyHighSeverity = false;

  @override
  Widget build(BuildContext context) {
    var filtered = widget.reports;
    if (_filterCategory != null) {
      filtered = filtered.where((r) => r.category == _filterCategory).toList();
    }
    if (_onlyHighSeverity) {
      filtered = filtered.where((r) => r.severity == 'Alta').toList();
    }

    final reported = filtered.where((r) => r.status == ReportStatus.reported).toList();
    final inProgress = filtered.where((r) => r.status == ReportStatus.inProgress || r.status == ReportStatus.reviewing).toList();
    final resolved = filtered.where((r) => r.status == ReportStatus.resolved).length;

    return NotificationListener<ScrollEndNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          context.read<ReportController>().loadMore();
        }
        return false;
      },
      child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const StaffPageIntro(title: 'Panel operador', subtitle: 'Distrito Centro · Turno mañana'),
        StaffStatsRow(items: [('${reported.length}', 'Nuevos'), ('${inProgress.length}', 'En proceso'), ('$resolved', 'Resueltos')]),
        
        const SizedBox(height: 24),
        const Text('Filtros Avanzados', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Solo Alta Severidad'),
                selected: _onlyHighSeverity,
                onSelected: (val) => setState(() => _onlyHighSeverity = val),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Baches'),
                selected: _filterCategory == ReportCategory.pothole,
                onSelected: (val) => setState(() => _filterCategory = val ? ReportCategory.pothole : null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Basura'),
                selected: _filterCategory == ReportCategory.waste,
                onSelected: (val) => setState(() => _filterCategory = val ? ReportCategory.waste : null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Luminaria'),
                selected: _filterCategory == ReportCategory.lighting,
                onSelected: (val) => setState(() => _filterCategory = val ? ReportCategory.lighting : null),
              ),
            ],
          ),
        ),
        
        const StaffHeading('Requieren validación (Nuevos)'),
        if (reported.isEmpty) const Text('No hay reportes nuevos', style: TextStyle(color: Colors.grey)),
        ...reported.map((r) => StaffReportTile(report: r, action: 'Validar', onTap: () => widget.onOpen(r))),
        
        const StaffHeading('En proceso'),
        if (inProgress.isEmpty) const Text('No hay tareas en ejecución', style: TextStyle(color: Colors.grey)),
        ...inProgress.map((r) => StaffReportTile(report: r, action: 'Ver estado', onTap: () => widget.onOpen(r))),
          if (context.watch<ReportController>().loadingMore)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
      ],
      ),
    );
  }
}

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
  bool _validatingWithAi = false;

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
          .select('id, role, email')
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

  Future<void> _runAiValidation() async {
    if (widget.report.imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El reporte no tiene imagen para analizar.')));
      return;
    }
    setState(() => _validatingWithAi = true);
    try {
      final result = await AiValidationService.analyzeReportForOperator(
        widget.report.imageUrl!,
        categoryName(widget.report.category),
        widget.report.description,
      );
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Análisis de IA (Gemini)'),
          content: SingleChildScrollView(child: Text(result)),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error de IA: $e')));
    } finally {
      if (mounted) setState(() => _validatingWithAi = false);
    }
  }

  @override
  void dispose() { _note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Validar reporte', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ReportCard(report: widget.report, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailView(report: widget.report)))),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _validatingWithAi ? null : _runAiValidation,
            icon: _validatingWithAi ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: Text(_validatingWithAi ? 'Analizando...' : 'Validar con IA (Gemini)'),
          ),
          const StaffHeading('Actualizar estado'),
          StaffSegmented(
            options: _statusLabels.values.toList(),
            selected: _statusLabels[_selectedStatus]!,
            onChanged: (label) {
              final entry = _statusLabels.entries.firstWhere((e) => e.value == label);
              setState(() => _selectedStatus = entry.key);
            },
          ),
          const StaffHeading('Asignar trabajador de campo'),
          if (_loadingWorkers)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (_workers.isEmpty)
            const Text('No hay trabajadores registrados.', style: TextStyle(color: Colors.grey))
          else
            ..._workers.map((w) {
              final id = w['id'].toString();
              // Usa el email si está disponible (después de la migración),
              // sino muestra los primeros 8 caracteres del UUID.
              final rawEmail = w['email']?.toString() ?? '';
              final label = rawEmail.isNotEmpty
                  ? rawEmail.split('@').first
                  : 'Trabajador (${id.substring(0, 8)}...)';
              return StaffWorkerTile(
                name: label,
                selected: _selectedWorkerId == id,
                onTap: () => setState(() => _selectedWorkerId = id),
              );
            }),
          const StaffHeading('Nota de atención'),
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
          .select('id, role, email')
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
    return NotificationListener<ScrollEndNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          context.read<ReportController>().loadMore();
        }
        return false;
      },
      child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        StaffPageIntro(title: 'Gestión de equipo', subtitle: '${_workers.length} miembros registrados'),
        ..._workers.map((w) => Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.teal,
              child: Text(w['role'].toString()[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text(_roleLabel(w['role'].toString())),
            subtitle: Text(
              w['email']?.toString().isNotEmpty == true
                  ? w['email'].toString()
                  : 'ID: ${w['id'].toString().substring(0, 8)}...',
            ),
          ),
        )),
      ],
      ),
    );
  }
}







