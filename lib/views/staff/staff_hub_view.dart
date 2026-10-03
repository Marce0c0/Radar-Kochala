import '../widgets/status_pill.dart';
import 'dart:math';
import 'staff_shared_widgets.dart';
import 'staff_map_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../profile/profile_view.dart';
import 'staff_profile_view.dart';
import '../notifications/notifications_view.dart';
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

  void switchSection(int s) {
    setState(() => section = s);
  }

  void _openReport(Report r) {
    if (r.status == ReportStatus.reported || r.status == ReportStatus.reviewing || r.status == ReportStatus.inProgress) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ValidateReportView(report: r))).then((value) {
        if (mounted) {
          context.read<ReportController>().load();
          if (value == true) {
            switchSection(2);
          }
        }
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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset('assets/logo_cochabamba.png'),
        ),
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
                reports: _filterCategory == null ? allReports : allReports.where((r) => r.category == _filterCategory).toList(),
                onOpen: _openReport
              ),
              const _TeamView(),
              const NotificationsView(),
              const StaffProfileView(),
            ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: section,
        onDestinationSelected: (value) => setState(() => section = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Bandeja'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Mapa'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Equipo'),
          NavigationDestination(icon: Icon(Icons.notifications_outlined), selectedIcon: Icon(Icons.notifications), label: 'Alertas'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: 'Perfil'),
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
      filtered = filtered.where((r) => r.category == widget.filterCategory).toList();
    }
    if (_onlyHighSeverity) {
      filtered = filtered.where((r) => r.severity == 'Alta').toList();
    }

    final reported = filtered.where((r) => r.status == ReportStatus.reported).toList();
    final reviewing = filtered.where((r) => r.status == ReportStatus.reviewing).toList();
    final inProgress = filtered.where((r) => r.status == ReportStatus.inProgress).toList();
    final resolved = filtered.where((r) => r.status == ReportStatus.resolved).toList();

    return DefaultTabController(
      length: 4,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20).copyWith(bottom: 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const StaffPageIntro(title: 'Resumen Operativo', subtitle: 'Vista de control central'),
                  StaffStatsRow(items: [
                    (reported.length.toString(), 'Sin asignar'),
                    ((reviewing.length + inProgress.length).toString(), 'En proceso'),
                    (resolved.length.toString(), 'Resueltos'),
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
                        ...ReportCategory.values.map((cat) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: Text(categoryName(cat)),
                            selected: widget.filterCategory == cat,
                            onSelected: (val) => widget.onFilterChanged?.call(val ? cat : null),
                          ),
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverAppBarDelegate(
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppTheme.teal,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.teal,
                tabs: [
                  Tab(text: 'Sin asignar (${reported.length})'),
                  Tab(text: 'En revisión (${reviewing.length})'),
                  Tab(text: 'En proceso (${inProgress.length})'),
                  Tab(text: 'Completados (${resolved.length})'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          children: [
            _buildList(reported, 'Validar'),
            _buildList(reviewing, 'Ver estado'),
            _buildList(inProgress, 'Ver estado'),
            _buildList(resolved, 'Ver detalles'),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Report> list, String actionLabel) {
    if (list.isEmpty) {
      return const Center(child: Text('No hay reportes en esta sección', style: TextStyle(color: Colors.grey)));
    }
    return NotificationListener<ScrollEndNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          context.read<ReportController>().loadMore();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 40, left: 20, right: 20),
        itemCount: list.length + (context.watch<ReportController>().loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == list.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return StaffReportTile(report: list[index], action: actionLabel, onTap: () => widget.onOpen(list[index]));
        },
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
  List<String> _activeCrewIds = [];
  bool _showDropdown = false;
  bool _replaceMode = false;
  String? _crewToReplaceId;
  bool _loadingWorkers = true;
  bool _mapInteractive = false;
  
  List<Map<String, dynamic>> _history = [];
  bool _loadingHistory = true;

  List<Map<String, dynamic>> _similarReports = [];
  bool _loadingSimilar = true;

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
    _loadSimilarReports();
  }

  Future<void> _loadSimilarReports() async {
    try {
      var query = Supabase.instance.client.from('reports')
          .select('id, title, category, status, address')
          .eq('category', widget.report.category)
          .neq('id', widget.report.id);
          
      if (widget.report.neighborhood.isNotEmpty) {
        query = query.eq('neighborhood', widget.report.neighborhood);
      }
      
      final result = await query.order('created_at', ascending: false).limit(3);
      if (mounted) setState(() { _similarReports = List<Map<String, dynamic>>.from(result); _loadingSimilar = false; });
    } catch(e) {
      if (mounted) setState(() => _loadingSimilar = false);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final result = await Supabase.instance.client
          .from('assignments')
          .select('worker_id, status, assigned_at, completed_at, worker_notes, operator_notes, profiles!worker_id(email)')
          .eq('report_id', widget.report.id)
          .order('assigned_at', ascending: false);
      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(result);
          _loadingHistory = false;
        });
        _determineActiveCrews();
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
          .select('id, name, crew_members(worker_id, profiles(email, full_name))');
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



  @override
  void dispose() { _note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Validar reporte', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          if (widget.report.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (c) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(16),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(widget.report.imageUrl!, fit: BoxFit.contain),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                            onPressed: () => Navigator.pop(c),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    widget.report.imageUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => Container(height: 220, color: Colors.grey.shade200, child: const Icon(Icons.broken_image, size: 40, color: Colors.grey)),
                  ),
                ),
              ),
            ),
          ReportCard(report: widget.report, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailView(report: widget.report)))),
          const SizedBox(height: 10),
          const StaffHeading('Ubicación del incidente'),
          Stack(
            children: [
              Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(key: ValueKey(_mapInteractive),
                    options: MapOptions(
                      initialCenter: LatLng((widget.report.latitude ?? 0.0), (widget.report.longitude ?? 0.0)),
                      initialZoom: 16.5,
                      interactionOptions: InteractionOptions(flags: _mapInteractive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng((widget.report.latitude ?? 0.0), (widget.report.longitude ?? 0.0)),
                            width: 40, height: 40,
                            alignment: Alignment.center,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: categoryColor(widget.report.category),
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
                              child: Icon(categoryIcon(widget.report.category), color: Colors.white, size: 20),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: Colors.white.withValues(alpha: 0.9),
                    elevation: 1,
                  ),
                  icon: Icon(_mapInteractive ? Icons.lock : Icons.touch_app, size: 14, color: AppTheme.teal),
                  label: Text(_mapInteractive ? 'Bloquear scroll' : 'Desbloquear mapa', style: const TextStyle(fontSize: 11, color: AppTheme.teal, fontWeight: FontWeight.bold)),
                  onPressed: () => setState(() => _mapInteractive = !_mapInteractive),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.blueGrey.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location, size: 16, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Text('${(widget.report.latitude ?? 0.0).toStringAsFixed(6)}, ${(widget.report.longitude ?? 0.0).toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ],
                ),
                if (widget.report.neighborhood.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.place, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(widget.report.neighborhood, style: const TextStyle(color: Colors.blueGrey))),
                    ],
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 16),
          const StaffHeading('Actualizar estado'),
          StaffSegmented(
            options: _statusLabels.values.toList(),
            selected: _statusLabels[_selectedStatus]!,
            onChanged: (label) {
              final entry = _statusLabels.entries.firstWhere((e) => e.value == label);
              setState(() => _selectedStatus = entry.key);
            },
          ),
          const StaffHeading('Cuadrillas Asignadas'),
          if (_loadingWorkers || _loadingHistory)
            const CircularProgressIndicator()
          else if (_crews.isEmpty)
            const Text('No hay cuadrillas registradas. Ve a la pestaña Equipo.', style: TextStyle(color: Colors.grey))
          else ...[
            if (_activeCrewIds.isNotEmpty) ..._activeCrewIds.map((cid) {
                final selectedCrew = _crews.firstWhere((c) => c['id'].toString() == cid, orElse: () => <String,dynamic>{});
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.teal.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.fire_truck, color: AppTheme.teal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(selectedCrew['name']?.toString() ?? 'Equipo Actual', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const Text('Equipo activo en terreno', style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.swap_horiz, color: Colors.blue, size: 22),
                        tooltip: 'Reemplazar esta cuadrilla',
                        onPressed: () => setState(() {
                           _showDropdown = true;
                           _replaceMode = true;
                           _crewToReplaceId = cid;
                           _selectedCrewId = null;
                        }),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red, size: 22),
                        tooltip: 'Retirar cuadrilla por completo',
                        onPressed: () => _removeCrew(cid),
                      ),
                    ],
                  ),
                );
            }),
            
            if (!_showDropdown && _activeCrewIds.isNotEmpty)
               Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   TextButton.icon(
                     onPressed: () => setState(() { _showDropdown = true; _replaceMode = false; _crewToReplaceId = null; _selectedCrewId = null; }),
                     icon: const Icon(Icons.add_circle_outline, size: 18),
                     label: const Text('Añadir nueva cuadrilla de apoyo'),
                     style: TextButton.styleFrom(foregroundColor: AppTheme.teal),
                   ),
                 ],
               ),
               
            if (_showDropdown || _activeCrewIds.isEmpty) ...[
               if (_activeCrewIds.isNotEmpty)
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text(_replaceMode ? 'Selecciona cuadrilla de REEMPLAZO:' : 'Selecciona cuadrilla de APOYO:', style: TextStyle(fontWeight: FontWeight.bold, color: _replaceMode ? Colors.red : AppTheme.teal)),
                     TextButton(
                       onPressed: () => setState(() { _showDropdown = false; _selectedCrewId = null; }),
                       child: const Text('Cancelar'),
                     ),
                   ],
                 ),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('Selecciona una cuadrilla...'),
                value: _selectedCrewId,
                items: _crews.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text(c['name'].toString()))).toList(),
                onChanged: (val) => setState(() => _selectedCrewId = val),
              ),
              if (_selectedCrewId != null) ...[
                const SizedBox(height: 8),
                Builder(
                  builder: (context) {
                    final selectedCrew = _crews.firstWhere((c) => c['id'].toString() == _selectedCrewId, orElse: () => <String,dynamic>{});
                    final membersRaw = selectedCrew['crew_members'] as List?;
                    final members = membersRaw != null ? List<Map<String, dynamic>>.from(membersRaw) : [];
                    
                    if (members.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('⚠️ Esta cuadrilla no tiene personal asignado.', style: TextStyle(color: Colors.deepOrange, fontSize: 12, fontWeight: FontWeight.bold)),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context, true),
                              icon: const Icon(Icons.group_add, size: 18),
                              label: const Text('Asignar personal'),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Ver miembros del equipo', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                        children: [
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: members.map((m) {
                              final name = m['profiles']?['full_name'] ?? m['profiles']?['email']?.split('@')[0] ?? 'N/A';
                              return Chip(
                                avatar: const Icon(Icons.engineering, size: 14, color: AppTheme.teal),
                                label: Text(name.toString(), style: const TextStyle(fontSize: 12)),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Colors.white,
                                side: const BorderSide(color: AppTheme.teal, width: 0.5),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  }
                ),
              ],
            ]
          ],
          const SizedBox(height: 16),
          const StaffHeading('Nota de atención'),
          TextField(controller: _note, maxLines: 3, decoration: const InputDecoration(hintText: 'Instrucciones para la cuadrilla...')),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _save,
            child: const Text('Guardar y asignar'),
          ),

          if (_history.isNotEmpty) ...[
            const SizedBox(height: 32),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.zero,
                title: const StaffHeading('Historial de Asignaciones'),
                subtitle: Text('${_history.length} registros (Entradas y Salidas)', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                children: _history.map((h) {
                  final email = h['profiles'] != null ? h['profiles']['email'] : 'Desconocido';
                  String crewName = 'Sin Cuadrilla';
                  final wid = h['worker_id']?.toString();
                  if (wid != null) {
                    for (var c in _crews) {
                      final members = c['crew_members'] as List?;
                      if (members != null && members.any((m) => m['worker_id'] == wid)) {
                        crewName = c['name']?.toString() ?? 'Sin Cuadrilla';
                        break;
                      }
                    }
                  }
                  final completed = h['completed_at'] != null;
                  final isReassigned = h['status'] == 'reasignado';
                  final dateStr = h['assigned_at'] != null 
                    ? DateTime.tryParse(h['assigned_at'].toString())?.toLocal().toString().split('.')[0] 
                    : '';
                  
                  return Card(
                    elevation: 0,
                    color: isReassigned ? Colors.red.withValues(alpha: 0.05) : (completed ? AppTheme.teal.withValues(alpha: 0.05) : Colors.green.withValues(alpha: 0.05)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                completed ? Icons.check_circle : (isReassigned ? Icons.arrow_circle_left : Icons.arrow_circle_right), 
                                color: completed ? AppTheme.teal : (isReassigned ? Colors.red : Colors.green), 
                                size: 22
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      crewName + (isReassigned ? ' (Salió)' : completed ? ' (Completó)' : ' (Activo)'), 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        color: isReassigned ? Colors.red.shade700 : (completed ? AppTheme.teal : Colors.green.shade700)
                                      )
                                    ),
                                    Text(email, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                                  ],
                                )
                              ),
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
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 32),
          const StaffHeading('Casos Similares en la Zona'),
          if (_loadingSimilar)
            const Center(child: CircularProgressIndicator())
          else if (_similarReports.isEmpty)
            const Text('No hay reportes similares en esta categoría y zona.', style: TextStyle(color: Colors.grey))
          else
            ..._similarReports.map((sim) => Card(
              elevation: 0,
              color: Colors.blueGrey.withValues(alpha: 0.05),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(categoryIcon(sim['category']), color: categoryColor(sim['category'])),
                title: Text(sim['title'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text(sim['address']?.toString() ?? 'Sin dirección', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                trailing: StatusPill(status: sim['status']),
              ),
            )).toList(),
          const SizedBox(height: 40),
        ]),
      );

  void _determineActiveCrews() {
    if (_loadingHistory || _loadingWorkers || _crews.isEmpty || _history.isEmpty) return;
    
    final activeAssignments = _history.where((h) => h['status'] == 'asignado').toList();
    _activeCrewIds.clear();
    
    for (var act in activeAssignments) {
      final wid = act['worker_id']?.toString();
      if (wid != null) {
        for (var crew in _crews) {
          final members = crew['crew_members'] as List?;
          if (members != null && members.any((m) => m['worker_id'] == wid)) {
            final cid = crew['id'].toString();
            if (!_activeCrewIds.contains(cid)) {
              _activeCrewIds.add(cid);
            }
          }
        }
      }
    }
    
    // Precargar el último mensaje enviado si existe y si no hemos escrito nada
    if (_note.text.isEmpty && activeAssignments.isNotEmpty) {
       final oldNote = activeAssignments.first['operator_notes']?.toString() ?? '';
       if (oldNote.isNotEmpty) {
          _note.text = oldNote;
       }
    }
    
    setState(() {});
  }

  Future<void> _removeCrew(String crewId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Retirar cuadrilla?'),
        content: const Text('Esta cuadrilla será retirada del incidente y notificada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Sí, retirar')),
        ],
      )
    );
    if (confirm != true) return;
    
    try {
      final crewToRemove = _crews.firstWhere((c) => c['id'].toString() == crewId);
      final oldMembers = crewToRemove['crew_members'] as List?;
      if (oldMembers != null && oldMembers.isNotEmpty) {
         final oldWorkerIds = oldMembers.map((m) => m['worker_id']).toList();
         await Supabase.instance.client.from('assignments')
            .update({'status': 'reasignado'})
            .eq('report_id', widget.report.id)
            .eq('status', 'asignado')
            .inFilter('worker_id', oldWorkerIds);
      }
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuadrilla retirada')));
         setState(() {
            _loadingHistory = true;
            _activeCrewIds.remove(crewId);
         });
         _loadHistory();
      }
    } catch(e) {
      debugPrint('Error retirando: $e');
    }
  }

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

    await context.read<ReportController>().updateStatus(widget.report.id, _selectedStatus);
    if (_selectedCrewId != null) {
      try {
        final client = Supabase.instance.client;
        final membersResult = await client.from('crew_members').select('worker_id').eq('crew_id', _selectedCrewId!);
        final workerIds = List<Map<String, dynamic>>.from(membersResult).map((m) => m['worker_id'].toString()).toList();
        
        if (workerIds.isEmpty) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La cuadrilla está vacía')));
          return;
        }

        // Si estamos reemplazando una cuadrilla específica, la marcamos como reasignada
        if (_replaceMode && _crewToReplaceId != null) {
          final crewToReplace = _crews.firstWhere((c) => c['id'].toString() == _crewToReplaceId!, orElse: () => <String,dynamic>{});
          final oldMembers = crewToReplace['crew_members'] as List?;
          if (oldMembers != null && oldMembers.isNotEmpty) {
             final oldWorkerIds = oldMembers.map((m) => m['worker_id']).toList();
             await client.from('assignments')
                .update({'status': 'reasignado'})
                .eq('report_id', widget.report.id)
                .eq('status', 'asignado')
                .inFilter('worker_id', oldWorkerIds);
          }
        }

        // Luego insertamos las nuevas asignaciones (ya sea apoyo o reemplazo)
        final List<Map<String, dynamic>> inserts = workerIds.map((id) => {
          'report_id': widget.report.id,
          'worker_id': id,
          'operator_id': client.auth.currentUser?.id,
          'operator_notes': _note.text.trim(),
          'assigned_at': DateTime.now().toIso8601String(),
          'status': 'asignado',
        }).toList();
        await client.from('assignments').insert(inserts);
      } catch (e) {
        debugPrint('Error al guardar asignación: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error interno asignando: $e')));
        }
      }
    }
    if (mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(children: [Icon(Icons.check_circle, color: AppTheme.teal), SizedBox(width: 8), Text('¡Guardado exitoso!')]),
          content: const Text('El reporte ha sido actualizado y la asignación se guardó correctamente. La cuadrilla ha sido notificada.'),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
          ],
        ),
      );
      setState(() {
         _showDropdown = false;
         _selectedCrewId = null;
         _loadingHistory = true;
      });
      _loadHistory();
    }
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
          .select('id, name, description, crew_members(worker_id, profiles(email, role, full_name))')
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

  Future<void> _deleteCrew(String crewId, String crewName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar Cuadrilla'),
        content: Text('¿Estás seguro de que deseas eliminar la cuadrilla "$crewName"? Esta acción eliminará también sus asignaciones y no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(c, true), 
            child: const Text('Eliminar')
          ),
        ],
      )
    );
    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await Supabase.instance.client.from('crews').delete().eq('id', crewId);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
      _loadCrews();
    }
  }

  Future<void> _fillRandomWorker(String crewId) async {
    final client = Supabase.instance.client;
    
    final assignedWorkerIds = _crews
        .expand((c) => (c['crew_members'] as List?)?.map((m) => m['worker_id'].toString()) ?? [])
        .toSet();

    final workersResult = await client.from('profiles').select('id, email, role, full_name').eq('role', 'trabajador');
    final availableWorkers = List<Map<String, dynamic>>.from(workersResult)
        .where((w) => !assignedWorkerIds.contains(w['id'].toString()))
        .toList();
        
    if (availableWorkers.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay trabajadores libres para asignar.')));
      return;
    }
    
    availableWorkers.shuffle(Random());
    final randomWorkerId = availableWorkers.first['id'];
    
    setState(() => _loading = true);
    try {
      await client.from('crew_members').insert({'crew_id': crewId, 'worker_id': randomWorkerId});
    } catch (_) {}
    _loadCrews();
  }

  Future<void> _createCrew() async {
    setState(() => _loading = true);
    int availableWorkersCount = 0;
    try {
      final assignedWorkerIds = _crews
          .expand((c) => (c['crew_members'] as List?)?.map((m) => m['worker_id'].toString()) ?? [])
          .toSet();
      final workersResult = await Supabase.instance.client.from('profiles').select('id, role').eq('role', 'trabajador');
      availableWorkersCount = (workersResult as List).where((w) => !assignedWorkerIds.contains(w['id'].toString())).length;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);

    final nameCtrl = TextEditingController(text: _generateRandomCrewName());
    int maxCapacity = 5;
    bool autoFill = false;
    
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
                const Divider(height: 32),
                Row(
                  children: [
                    const Expanded(child: Text('Capacidad (trabajadores):')),
                    DropdownButton<int>(
                      value: maxCapacity,
                      items: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                      onChanged: (val) => setStateDialog(() => maxCapacity = val ?? 5),
                    ),
                  ],
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Llenado automático', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  subtitle: Text('Asignar personal al azar ($availableWorkersCount disponibles)', style: const TextStyle(fontSize: 12)),
                  value: autoFill,
                  onChanged: (val) => setStateDialog(() => autoFill = val ?? false),
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
      try {
        final client = Supabase.instance.client;
        final newCrew = await client.from('crews').insert({
          'name': name,
          'description': maxCapacity.toString(),
        }).select('id').single();
        
        if (autoFill) {
          final assignedWorkerIds = _crews
              .expand((c) => (c['crew_members'] as List?)?.map((m) => m['worker_id'].toString()) ?? [])
              .toSet();
          final workersResult = await client.from('profiles').select('id, email, role, full_name').eq('role', 'trabajador');
          final availableWorkers = List<Map<String, dynamic>>.from(workersResult)
              .where((w) => !assignedWorkerIds.contains(w['id'].toString()))
              .toList();
              
          availableWorkers.shuffle(Random());
          final toAssign = availableWorkers.take(maxCapacity).toList();
          
          if (toAssign.isNotEmpty) {
            final inserts = toAssign.map((w) => {'crew_id': newCrew['id'], 'worker_id': w['id']}).toList();
            await client.from('crew_members').insert(inserts);
          }
          if (toAssign.length < maxCapacity && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Solo se asignaron ${toAssign.length} trabajadores porque no hay más libres.'))
            );
          }
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
      _loadCrews();
    }
  }

  Future<void> _addWorker(String crewId) async {
    final client = Supabase.instance.client;
    
    final assignedWorkerIds = _crews
        .expand((c) => (c['crew_members'] as List?)?.map((m) => m['worker_id'].toString()) ?? [])
        .toSet();

    final workersResult = await client.from('profiles').select('id, email, role, full_name').eq('role', 'trabajador');
    final availableWorkers = List<Map<String, dynamic>>.from(workersResult)
        .where((w) => !assignedWorkerIds.contains(w['id'].toString()))
        .toList();
    
    if (!mounted) return;
    
    if (availableWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Todos los trabajadores ya están asignados a una cuadrilla.')));
      return;
    }

    final selectedWorkerId = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setStateDialog) {
          String searchQuery = '';
          return AlertDialog(
            title: const Text('Asignar Trabajador'),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por correo...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => setStateDialog(() => searchQuery = val.toLowerCase()),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final filtered = availableWorkers.where((w) {
                          final e = (w['email'] ?? '').toString().toLowerCase();
                          final n = (w['full_name'] ?? '').toString().toLowerCase();
                          return e.contains(searchQuery) || n.contains(searchQuery);
                        }).toList();
                        if (filtered.isEmpty) return const Center(child: Text('No se encontraron resultados.'));
                        
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final w = filtered[i];
                            final name = w['full_name'] != null && w['full_name'].toString().isNotEmpty ? w['full_name'] : 'Sin nombre';
                            return ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.person, size: 18)),
                              title: Text(name),
                              subtitle: Text(w['email'] ?? ''),
                              onTap: () => Navigator.pop(c, w['id']),
                            );
                          },
                        );
                      }
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            ],
          );
        }
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
                    children: [
                      const Icon(Icons.fire_truck, color: AppTheme.teal),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(crew['name'] ?? 'Sin nombre', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), 
                        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)), 
                        child: Text('${members.length} / ${crew['description'] ?? 5} cupos', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey))
                      ),
                      IconButton(
                        tooltip: 'Eliminar cuadrilla',
                        onPressed: () => _deleteCrew(crew['id'], crew['name']), 
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20)
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () => _addWorker(crew['id']), 
                        icon: const Icon(Icons.person_add, size: 16), 
                        label: const Text('Asignar')
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                        onPressed: () => _fillRandomWorker(crew['id']), 
                        icon: const Icon(Icons.casino, size: 16), 
                        label: const Text('Asignar Aleatorio')
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (members.isEmpty)
                    const Text('No hay trabajadores en esta cuadrilla', style: TextStyle(color: Colors.grey)),
                  ...members.map((m) {
                    final profile = m['profiles'] ?? {};
                    final name = profile['full_name'] != null && profile['full_name'].toString().isNotEmpty ? profile['full_name'] : 'Sin nombre';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          const CircleAvatar(radius: 12, backgroundColor: Colors.grey, child: Icon(Icons.person, size: 12, color: Colors.white)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name),
                                Text(profile['email'] ?? '', style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                            onPressed: () async {
                          setState(() => _loading = true);
                          await Supabase.instance.client.from('crew_members').delete().match({'crew_id': crew['id'], 'worker_id': m['worker_id']});
                          _loadCrews();
                        },
                      ),
                    ],),);
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

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: Colors.white, child: _tabBar);
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
