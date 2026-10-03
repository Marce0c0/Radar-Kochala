import os

path = r'C:\Users\sammy\Desktop\Radar_Kochala\Radar_Kochala\lib\views\staff\staff_hub_view.dart'

content = """import 'dart:math';
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

class StaffHubView extends StatefulWidget {
  const StaffHubView({super.key, this.initialSection = 0});
  final int initialSection;
  @override
  State<StaffHubView> createState() => _StaffHubViewState();
}

class _StaffHubViewState extends State<StaffHubView> {
  late int section;
  ReportCategory? _filterCategory;

  @override
  void initState() {
    super.initState();
    section = widget.initialSection;
  }

  void _openReport(Report r) {
    if (r.status == ReportStatus.reported || r.status == ReportStatus.reviewing || r.status == ReportStatus.inProgress) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ValidateReportView(report: r))).then((_) {
        if (mounted) context.read<ReportController>().load();
      });
    }
  }

  Future<void> _logOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RoleSelectionView()));
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportController>();
    final allReports = controller.reports;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          section == 0 ? 'Bandeja de Operador' : section == 1 ? 'Mapa Operativo' : 'Equipo',
          style: const TextStyle(fontWeight: FontWeight.w900)
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.load(),
            tooltip: 'Actualizar',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: _logOut,
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: controller.loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: section, children: [
              _OperatorBoard(
                reports: allReports, 
                onOpen: _openReport,
                filterCategory: _filterCategory,
                onFilterChanged: (val) => setState(() => _filterCategory = val),
              ),
              StaffMapView(
                reports: _filterCategory == null ? allReports : allReports.where((r) => r.category == _filterCategory!.name).toList(),
                onOpen: _openReport
              ),
              const _TeamView(),
            ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: section,
        onDestinationSelected: (value) => setState(() => section = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Bandeja'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Equipo'),
        ],
      ),
    );
  }
}

class _OperatorBoard extends StatefulWidget {
  const _OperatorBoard({required this.reports, required this.onOpen, this.filterCategory, this.onFilterChanged});
  final List<Report> reports;
  final ValueChanged<Report> onOpen;
  final ReportCategory? filterCategory;
  final ValueChanged<ReportCategory?>? onFilterChanged;

  @override
  State<_OperatorBoard> createState() => _OperatorBoardState();
}

class _OperatorBoardState extends State<_OperatorBoard> {
  bool _onlyHighSeverity = false;

  @override
  Widget build(BuildContext context) {
    var filtered = widget.reports;
    if (widget.filterCategory != null) {
      filtered = filtered.where((r) => r.category == widget.filterCategory!.name).toList();
    }
    if (_onlyHighSeverity) {
      filtered = filtered.where((r) => r.severity == 'Alta').toList();
    }

    final reported = filtered.where((r) => r.status == ReportStatus.reported).toList();
    final inProgress = filtered.where((r) => r.status == ReportStatus.reviewing || r.status == ReportStatus.inProgress).toList();

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
          const StaffPageIntro(title: 'Resumen Operativo', subtitle: 'Vista de control central'),
          StaffStatsRow(items: [
            ('${widget.reports.where((r) => r.status == ReportStatus.reported).length}', 'Nuevos'),
            ('${widget.reports.where((r) => r.status == ReportStatus.inProgress || r.status == ReportStatus.reviewing).length}', 'En proceso'),
            ('${widget.reports.where((r) => r.status == ReportStatus.resolved).length}', 'Resueltos'),
          ]),
          
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Solo Alta Gravedad'),
                  selected: _onlyHighSeverity,
                  onSelected: (val) => setState(() => _onlyHighSeverity = val),
                  selectedColor: Colors.red.withValues(alpha: 0.2),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Baches'),
                  selected: widget.filterCategory == ReportCategory.pothole,
                  onSelected: (val) => widget.onFilterChanged?.call(val ? ReportCategory.pothole : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Basura'),
                  selected: widget.filterCategory == ReportCategory.waste,
                  onSelected: (val) => widget.onFilterChanged?.call(val ? ReportCategory.waste : null),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Luminaria'),
                  selected: widget.filterCategory == ReportCategory.lighting,
                  onSelected: (val) => widget.onFilterChanged?.call(val ? ReportCategory.lighting : null),
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
            )
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
  List<Map<String, dynamic>> _crews = [];
  String? _selectedCrewId;
  bool _loadingWorkers = true;
  bool _validatingWithAi = false;
  
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

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
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final result = await Supabase.instance.client
          .from('assignments')
          .select('assigned_at, completed_at, worker_notes, operator_notes, profiles!worker_id(email)')
          .eq('report_id', widget.report.id)
          .order('assigned_at', ascending: false);
      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(result);
          _loadingHistory = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _loadWorkers() async {
    try {
      final result = await Supabase.instance.client
          .from('crews')
          .select('id, name');
      if (mounted) {
        setState(() {
          _crews = List<Map<String, dynamic>>.from(result ?? []);
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
          const StaffHeading('Asignar a Cuadrilla'),
          if (_loadingWorkers)
            const CircularProgressIndicator()
          else if (_crews.isEmpty)
            const Text('No hay cuadrillas registradas. Ve a la pestaña Equipo.', style: TextStyle(color: Colors.grey))
          else
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(border: OutlineInputBorder()),
              hint: const Text('Selecciona una cuadrilla...'),
              value: _selectedCrewId,
              items: _crews.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'].toString()))).toList(),
              onChanged: (val) => setState(() => _selectedCrewId = val),
            ),
          const StaffHeading('Nota de atención'),
          TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(hintText: 'Instrucciones para la cuadrilla...')),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _save,
            child: const Text('Guardar y asignar'),
          ),

          if (_history.isNotEmpty) ...[
            const SizedBox(height: 32),
            const StaffHeading('Historial de Asignaciones (Técnicos)'),
            ..._history.map((h) {
              final email = h['profiles'] != null ? h['profiles']['email'] : 'Desconocido';
              final completed = h['completed_at'] != null;
              final dateStr = h['assigned_at'] != null 
                ? DateTime.tryParse(h['assigned_at'].toString())?.toLocal().toString().split('.')[0] 
                : '';
              
              return Card(
                elevation: 0,
                color: const Color(0xfff5f7f6),
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(completed ? Icons.check_circle : Icons.pending, 
                               color: completed ? AppTheme.teal : Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(email, style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Asignado: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      if (h['operator_notes'] != null && h['operator_notes'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('Instrucción: ${h['operator_notes']}', style: const TextStyle(fontSize: 13)),
                        ),
                      if (completed && h['worker_notes'] != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: Text('Reporte Técnico: ${h['worker_notes']}', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 20),
        ]),
      );

  Future<void> _save() async {
    if (_selectedCrewId != null && 
        (_selectedStatus == ReportStatus.reported || _selectedStatus == ReportStatus.reviewing)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xffd9684b),
          content: Text('Cambia el estado a "En proceso" para asignar la tarea a la cuadrilla.'),
        ),
      );
      return;
    }

    // Actualiza el estado del reporte.
    await context.read<ReportController>().updateStatus(widget.report.id, _selectedStatus);
    // Si hay una cuadrilla seleccionada, crea la asignación en la BD.
    if (_selectedCrewId != null) {
      try {
        final client = Supabase.instance.client;
        final membersResult = await client.from('crew_members').select('worker_id').eq('crew_id', _selectedCrewId!);
        final workerIds = List<Map<String, dynamic>>.from(membersResult).map((m) => m['worker_id'].toString()).toList();
        
        if (workerIds.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La cuadrilla está vacía')));
          return;
        }

        final List<Map<String, dynamic>> inserts = workerIds.map((id) => {
          'report_id': widget.report.id,
          'worker_id': id,
          'operator_id': client.auth.currentUser?.id,
          'operator_notes': _note.text.trim(),
          'assigned_at': DateTime.now().toIso8601String(),
        }).toList();
        await client.from('assignments').insert(inserts);
      } catch (e) {
        debugPrint('Error al guardar asignación: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error interno asignando: $e')));
        }
      }
    }
    if (mounted) Navigator.pop(context);
  }
}

class _TeamView extends StatefulWidget {
  const _TeamView();
  @override
  State<_TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends State<_TeamView> {
  List<Map<String, dynamic>> _crews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCrews();
  }

  Future<void> _loadCrews() async {
    try {
      final client = Supabase.instance.client;
      final result = await client
          .from('crews')
          .select('id, name, crew_members(worker_id, profiles(email, role))')
          .order('created_at', ascending: false);
      if (mounted) setState(() { _crews = List<Map<String, dynamic>>.from(result ?? []); _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _generateRandomCrewName() {
    final prefixes = ['Escuadrón', 'Unidad', 'Cuadrilla', 'Equipo', 'Brigada', 'Patrulla', 'Fuerza', 'Comando', 'Bloque', 'Batallón'];
    final roots = ['Alfa', 'Beta', 'Delta', 'Fénix', 'Halcón', 'Tigre', 'Rayo', 'Trueno', 'Titán', 'Jaguar', 'Cóndor', 'Puma', 'Lobo', 'Toro'];
    final modifiers = ['Rojo', 'Azul', 'Verde', 'Relámpago', 'Express', 'Táctico', 'Pesado', 'Nocturno', 'Tunari', 'Rocha', 'Alalay', 'Coronilla', 'Élite', 'Zénit'];
    
    final existingNames = _crews.map((c) => c['name']?.toString().toLowerCase() ?? '').toSet();
    
    String generated = '';
    int attempts = 0;
    final rand = Random();
    
    while (attempts < 50) {
      final pre = prefixes[rand.nextInt(prefixes.length)];
      final root = roots[rand.nextInt(roots.length)];
      final mod = modifiers[rand.nextInt(modifiers.length)];
      
      if (rand.nextBool()) {
        generated = '$pre $root';
      } else {
        generated = '$pre $root $mod';
      }
      
      if (!existingNames.contains(generated.toLowerCase())) {
        return generated;
      }
      attempts++;
    }
    return 'Cuadrilla ${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  Future<void> _createCrew() async {
    final nameCtrl = TextEditingController(text: _generateRandomCrewName());
    final name = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Nueva Cuadrilla'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl, 
                  decoration: const InputDecoration(
                    hintText: 'Ej: Cuadrilla Alfa',
                    labelText: 'Nombre de la cuadrilla',
                  )
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () {
                    setStateDialog(() {
                      nameCtrl.text = _generateRandomCrewName();
                    });
                  }, 
                  icon: const Icon(Icons.refresh, size: 16), 
                  label: const Text('Generar otro nombre')
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(c, nameCtrl.text.trim()), child: const Text('Crear')),
            ],
          );
        }
      )
    );
    if (name != null && name.isNotEmpty) {
      final exists = _crews.any((crew) {
        final existingName = crew['name']?.toString().toLowerCase() ?? '';
        return existingName == name.toLowerCase();
      });

      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xffd9684b),
              content: Text('Ya existe una cuadrilla con el nombre "$name". Intenta con otro.'),
            ),
          );
        }
        return;
      }

      setState(() => _loading = true);
      await Supabase.instance.client.from('crews').insert({'name': name});
      _loadCrews();
    }
  }

  Future<void> _addWorker(String crewId) async {
    final client = Supabase.instance.client;
    final workersResult = await client.from('profiles').select('id, email, role').eq('role', 'trabajador');
    final workers = List<Map<String, dynamic>>.from(workersResult);
    
    if (!mounted) return;
    final selectedWorkerId = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Asignar Trabajador'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: workers.length,
            itemBuilder: (context, i) => ListTile(
              title: Text(workers[i]['email']),
              onTap: () => Navigator.pop(c, workers[i]['id']),
            ),
          ),
        ),
      )
    );

    if (selectedWorkerId != null) {
      setState(() => _loading = true);
      try {
        await client.from('crew_members').insert({'crew_id': crewId, 'worker_id': selectedWorkerId});
      } catch (_) {}
      _loadCrews();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            StaffPageIntro(title: 'Gestión de Cuadrillas', subtitle: '${_crews.length} activas'),
            IconButton(onPressed: _createCrew, icon: const Icon(Icons.add_circle, color: AppTheme.teal, size: 32)),
          ],
        ),
        const SizedBox(height: 16),
        ..._crews.map((crew) {
          final rawMembers = crew['crew_members'];
          final members = rawMembers != null ? List<Map<String, dynamic>>.from(rawMembers) : [];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.fire_truck, color: AppTheme.teal),
                          const SizedBox(width: 8),
                          Text(crew['name'] ?? 'Sin nombre', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      TextButton.icon(onPressed: () => _addWorker(crew['id']), icon: const Icon(Icons.person_add, size: 16), label: const Text('Asignar')),
                    ],
                  ),
                  const Divider(),
                  if (members.isEmpty)
                    const Text('No hay trabajadores en esta cuadrilla', style: TextStyle(color: Colors.grey)),
                  ...members.map((m) {
                    final profile = m['profiles'] ?? {};
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(radius: 12, backgroundColor: Colors.grey, child: Icon(Icons.person, size: 12, color: Colors.white)),
                      title: Text(profile['email'] ?? 'Desconocido'),
                      trailing: IconButton(
                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                        onPressed: () async {
                          setState(() => _loading = true);
                          await Supabase.instance.client.from('crew_members').delete().match({'crew_id': crew['id'], 'worker_id': m['worker_id']});
                          _loadCrews();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
"""

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print('Fully rewrote staff_hub_view.dart with correct clean content.')
