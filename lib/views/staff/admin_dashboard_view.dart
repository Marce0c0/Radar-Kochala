import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/report_controller.dart';
import '../../services/pdf_report_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../role/role_selection_view.dart';
import '../reports/detail_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  int _selectedIndex = 0;

  void _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RoleSelectionView()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f7f6),
      appBar: AppBar(
        title: const FittedBox(fit: BoxFit.scaleDown, child: Text('Panel de Administración', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        backgroundColor: AppTheme.ink,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Row(
        children: [
          // Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: AppTheme.teal),
            selectedLabelTextStyle: const TextStyle(color: AppTheme.teal, fontWeight: FontWeight.bold),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: Text('Métricas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: Text('Mapa'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Personal'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_alt),
                selectedIcon: Icon(Icons.list),
                label: Text('Reportes'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const _MetricsTab();
      case 1:
        return const _MapTab();
      case 2:
        return const _StaffTab();
      case 3:
        return const _ReportsTab();
      default:
        return const _MetricsTab();
    }
  }
}

// ==========================================
// 1. TAB MÉTRICAS
// ==========================================
class _MetricsTab extends StatefulWidget {
  const _MetricsTab();

  @override
  State<_MetricsTab> createState() => _MetricsTabState();
}

class _MetricsTabState extends State<_MetricsTab> {
  int _totalUsers = 0;
  bool _loadingUsers = true;
  String _selectedRange = 'Todos';
  
  final List<String> _ranges = ['1 Semana', '1 Mes', '6 Meses', '1 Año', '3 Años', 'Todos'];

  List<Report> _filterReports(List<Report> all) {
    if (_selectedRange == 'Todos') return all;
    final now = DateTime.now();
    DateTime cutoff;
    switch (_selectedRange) {
      case '1 Semana': cutoff = now.subtract(const Duration(days: 7)); break;
      case '1 Mes': cutoff = now.subtract(const Duration(days: 30)); break;
      case '6 Meses': cutoff = now.subtract(const Duration(days: 180)); break;
      case '1 Año': cutoff = now.subtract(const Duration(days: 365)); break;
      case '3 Años': cutoff = now.subtract(const Duration(days: 1095)); break;
      default: return all;
    }
    return all.where((r) => r.createdAt != null && r.createdAt!.isAfter(cutoff)).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final res = await Supabase.instance.client.from('profiles').select('id');
      if (mounted) {
        setState(() {
          _totalUsers = res.length;
          _loadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  void _exportCSV(BuildContext context, List<dynamic> reports) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Titulo,Categoria,Estado,Severidad,Fecha,Ubicacion');
    for (var r in reports) {
      final title = r.title.replaceAll(',', ' ');
      buffer.writeln('${r.id},$title,${r.category.name},${r.status.name},${r.severity},${r.time},${r.latitude}|${r.longitude}');
    }
    
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Datos copiados al portapapeles en formato CSV! Pégalo en Excel o Google Sheets.'))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportController>(
      builder: (context, controller, child) {
        if (controller.loading && controller.reports.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final filteredReports = _filterReports(controller.reports);
        final total = filteredReports.length;
        final resueltos = filteredReports.where((r) => r.status.name == 'resolved').length;
        final pendientes = total - resueltos;
        final resolutionRate = total == 0 ? '0%' : '${((resueltos / total) * 100).toStringAsFixed(0)}%';
        
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Resumen General', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.ink)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRange,
                      icon: const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: Icon(Icons.calendar_today, size: 18, color: AppTheme.teal),
                      ),
                      items: _ranges.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _selectedRange = v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _StatCard('Total Reportes', '$total', Icons.campaign),
                const SizedBox(width: 16),
                _StatCard('Resueltos', resolutionRate, Icons.check_circle),
                const SizedBox(width: 16),
                _StatCard('Pendientes', '$pendientes', Icons.pending_actions),
                const SizedBox(width: 16),
                _StatCard('Usuarios Activos', _loadingUsers ? '...' : '$_totalUsers', Icons.people),
              ],
            ),
            const SizedBox(height: 40),
            const Text('Acciones Rápidas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Actualizar Datos', style: TextStyle(color: Colors.white)),
                  backgroundColor: AppTheme.teal,
                  onPressed: () {
                    controller.load();
                    _loadUsers();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.file_download, color: Colors.white),
                  label: const Text('Exportar a CSV', style: TextStyle(color: Colors.white)),
                  backgroundColor: const Color(0xff5b954b),
                  onPressed: () => _exportCSV(context, controller.reports),
                ),
                ActionChip(
                  avatar: const Icon(Icons.picture_as_pdf, color: Colors.white),
                  label: const Text('Exportar PDF', style: TextStyle(color: Colors.white)),
                  backgroundColor: const Color(0xffb71c1c),
                  onPressed: () => PdfReportService.generateAndPrintReport(controller.reports),
                ),
              ],
            ),
            const SizedBox(height: 40),
            _AdminCalendar(reports: filteredReports),
          ],
        );
      }
    );
  }
}

class _AdminCalendar extends StatelessWidget {
  final List<Report> reports;
  const _AdminCalendar({required this.reports});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);
    
    final Map<int, int> counts = {};
    for (var r in reports) {
      if (r.createdAt != null && r.createdAt!.year == now.year && r.createdAt!.month == now.month) {
        counts[r.createdAt!.day] = (counts[r.createdAt!.day] ?? 0) + 1;
      }
    }

    final offset = firstDayOfMonth.weekday - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Builder(builder: (ctx2) {
          const mn = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
          final n2 = DateTime.now();
          return Text('Calendario de Reportes - ' + mn[n2.month-1] + ' ' + n2.year.toString(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
        }),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffe1e9e6)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
                    .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))))
                    .toList(),
              ),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1.0,
                ),
                itemCount: lastDayOfMonth.day + offset,
                itemBuilder: (context, index) {
                  if (index < offset) return const SizedBox();
                  final day = index - offset + 1;
                  final count = counts[day] ?? 0;
                  final isToday = day == now.day;
                  
                  return GestureDetector(
                    onTap: () {
                      if (count == 0) return;
                      final dayReports = reports.where((r) => r.createdAt != null && r.createdAt!.year == now.year && r.createdAt!.month == now.month && r.createdAt!.day == day).toList();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => _buildDayReportsSheet(ctx, day, dayReports),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: count > 0 ? AppTheme.teal.withValues(alpha: (0.1 + count * 0.1).clamp(0.0, 0.8)) : Colors.transparent,
                        border: isToday ? Border.all(color: AppTheme.teal, width: 2) : Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          Center(child: Text('$day', style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal))),
                          if (count > 0)
                            Positioned(
                              right: 2,
                              top: 2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayReportsSheet(BuildContext context, int day, List<Report> dayReports) {
    const mNames = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
    final monthName = mNames[DateTime.now().month - 1];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('Reportes del $day de $monthName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              if (dayReports.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  tooltip: 'Exportar PDF',
                  onPressed: () {
                    PdfReportService.generateAndPrintReport(dayReports);
                  },
                ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          Expanded(
            child: dayReports.isEmpty
                ? const Center(child: Text('Sin reportes este dia'))
                : ListView.builder(
                    itemCount: dayReports.length,
                    itemBuilder: (context, index) {
                      final r = dayReports[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          child: Icon(Icons.warning_amber, color: Colors.grey.shade700, size: 20),
                        ),
                        title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(r.time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: r.severity == 'Alta' ? Colors.red.shade100 : r.severity == 'Media' ? Colors.orange.shade100 : Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(r.severity, style: TextStyle(
                            color: r.severity == 'Alta' ? Colors.red.shade700 : r.severity == 'Media' ? Colors.orange.shade800 : Colors.green.shade700,
                            fontSize: 12, fontWeight: FontWeight.bold,
                          )),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, this.icon);
  final String label, value;
  final IconData icon;
  
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe1e9e6)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.teal, size: 32),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.ink)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}

// ==========================================
// 2. TAB MAPA
// ==========================================
class _MapTab extends StatefulWidget {
  const _MapTab();

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  int _mapMode = 0; // 0 = Puntos de Calor, 1 = Vista Ciudadana

    Color _getStatusRingColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.reported:   return const Color(0xffd9684b);
      case ReportStatus.reviewing:  return Colors.orange;
      case ReportStatus.inProgress: return Colors.blue;
      case ReportStatus.resolved:   return const Color(0xff4caf50);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Puntos de Calor'),
                icon: Icon(Icons.blur_on),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Vista Ciudadana'),
                icon: Icon(Icons.pin_drop),
              ),
            ],
            selected: {_mapMode},
            onSelectionChanged: (Set<int> newSelection) {
              setState(() {
                _mapMode = newSelection.first;
              });
            },
          ),
        ),
        Expanded(
          child: Consumer<ReportController>(
            builder: (context, controller, child) {
              final reports = controller.reports.where((r) => r.latitude != null && r.longitude != null).toList();
              
              return FlutterMap(
                options: const MapOptions(
                  initialCenter: LatLng(-17.3935, -66.1570), // Cochabamba
                  initialZoom: 13,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.radar.kochala',
                  ),
                  if (_mapMode == 0)
                    CircleLayer(
                      circles: reports.map((r) => CircleMarker(
                        point: LatLng(r.latitude!, r.longitude!),
                        color: Colors.red.withValues(alpha: 0.3),
                        borderStrokeWidth: 1,
                        borderColor: Colors.red,
                        radius: 60,
                        useRadiusInMeter: true,
                      )).toList(),
                    ),
                  if (_mapMode == 1)
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 45,
                        size: const Size(40, 40),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(50),
                        markers: reports.map((r) => Marker(
                          point: LatLng(r.latitude!, r.longitude!),
                          width: 54,
                          height: 54,
                          child: GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => DetailView(report: r)),
                            ),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _getStatusRingColor(r.status), width: 3.5),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: categoryColor(r.category),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    categoryIcon(r.category),
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )).toList(),
                        builder: (context, markers) {
                          return Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: AppTheme.teal,
                                border: Border.all(color: Colors.white, width: 2)),
                            child: Center(
                              child: Text(
                                markers.length.toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

}

// ==========================================
// 3. TAB PERSONAL
// ==========================================
class _StaffTab extends StatefulWidget {
  const _StaffTab();

  @override
  State<_StaffTab> createState() => _StaffTabState();
}

class _StaffTabState extends State<_StaffTab> {

  Future<void> _crearNuevoTrabajador() async {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'trabajador';
    bool isLoading = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Crear Personal'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Correo Institucional'),
                  keyboardType: TextInputType.emailAddress,
                ),
                TextField(
                  controller: passCtrl,
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'trabajador', child: Text('Trabajador')),
                    DropdownMenuItem(value: 'admin', child: Text('Administrador')),
                  ],
                  onChanged: (v) => setStateDialog(() => selectedRole = v!),
                  decoration: const InputDecoration(labelText: 'Rol'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: isLoading ? null : () async {
                  if (emailCtrl.text.isEmpty || passCtrl.text.length < 6) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datos inválidos')));
                    return;
                  }
                  setStateDialog(() => isLoading = true);
                  try {
                    final res = await http.post(
                      Uri.parse('${dotenv.env['SUPABASE_URL']}/auth/v1/signup'),
                      headers: {
                        'apikey': dotenv.env['SUPABASE_ANON_KEY']!,
                        'Content-Type': 'application/json',
                      },
                      body: jsonEncode({
                        'email': emailCtrl.text.trim(),
                        'password': passCtrl.text,
                      }),
                    );
                    
                    if (res.statusCode == 200 || res.statusCode == 201) {
                      final body = jsonDecode(res.body);
                      final userId = body['user']['id'];
                      
                      await Future.delayed(const Duration(seconds: 1));
                      
                      await Supabase.instance.client
                          .from('profiles')
                          .update({'role': selectedRole})
                          .eq('id', userId);
                      
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadStaff();
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Personal creado con éxito')));
                    } else {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res.body}')));
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  } finally {
                    setStateDialog(() => isLoading = false);
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: AppTheme.teal),
                child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Crear Cuenta'),
              ),
            ],
          );
        }
      ),
    );
  }
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _activeStaff = [];
  Map<String, dynamic>? _searchedUser;
  bool _loading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _loading = true);
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .neq('role', 'ciudadano')
          .order('role', ascending: true);
      setState(() => _activeStaff = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('Error loading staff: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _searchUser() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    setState(() {
      _searching = true;
      _searchedUser = null;
    });
    
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('role', 'ciudadano')
          .ilike('email', '%$query%')
          .limit(1)
          .maybeSingle();
          
      setState(() => _searchedUser = data);
    } catch (e) {
      debugPrint('Error searching user: $e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _updateRole(String id, String newRole) async {
    try {
      await _supabase.from('profiles').update({'role': newRole}).eq('id', id);
      _searchController.clear();
      setState(() => _searchedUser = null);
      _loadStaff();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rol actualizado a $newRole exitosamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al actualizar rol'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Gestión de Personal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.ink)),
        const SizedBox(height: 24),
        
        // Buscador
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffe1e9e6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Promover a un Ciudadano', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Buscar por correo electrónico (ej. juan@gmail.com)',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _searchUser(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: _searching ? null : _searchUser,
                    child: _searching ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Buscar'),
                  ),
                ],
              ),
              if (_searchedUser != null) ...[
                const SizedBox(height: 16),
                ListTile(
                  tileColor: const Color(0xfff5f7f6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(_searchedUser!['email'] ?? 'Sin correo'),
                  subtitle: const Text('Rol actual: Ciudadano'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: () => _updateRole(_searchedUser!['id'], 'operador'), child: const Text('Hacer Operador')),
                      TextButton(onPressed: () => _updateRole(_searchedUser!['id'], 'trabajador'), child: const Text('Hacer Trabajador')),
                    ],
                  ),
                ),
              ],
              if (_searchedUser == null && _searchController.text.isNotEmpty && !_searching) ...[
                const SizedBox(height: 16),
                const Text('No se encontró ningún ciudadano con ese correo.', style: TextStyle(color: Colors.red)),
              ]
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        const Text('Personal Activo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        if (_loading) 
          const Center(child: CircularProgressIndicator())
        else if (_activeStaff.isEmpty)
          const Text('No hay personal activo.', style: TextStyle(color: Colors.grey))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _activeStaff.length,
            itemBuilder: (context, index) {
              final user = _activeStaff[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xffe1e9e6)),
                ),
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: user['role'] == 'admin' ? Colors.red.shade100 : AppTheme.teal.withValues(alpha: 0.2),
                    child: Icon(
                      user['role'] == 'admin' ? Icons.admin_panel_settings : Icons.badge,
                      color: user['role'] == 'admin' ? Colors.red : AppTheme.teal,
                    ),
                  ),
                  title: Text(user['email'] ?? 'Sin correo', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Rol: ${user['role'].toString().toUpperCase()}'),
                  trailing: user['role'] == 'admin' ? null : TextButton(
                    onPressed: () => _updateRole(user['id'], 'ciudadano'),
                    child: const Text('Revocar Acceso', style: TextStyle(color: Colors.red)),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ==========================================
// 4. TAB REPORTES
// ==========================================
class _ReportsTab extends StatefulWidget {
  const _ReportsTab();
  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  String _searchQuery = '';
  String _filterStatus = 'Todos';
  String _filterCategory = 'Todas';
  String _filterSeverity = 'Todas';

  Widget _buildDropdown(String label, String value, List<String> opts, ValueChanged<String?> cb) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              style: const TextStyle(fontSize: 13, color: Color(0xff121212), fontWeight: FontWeight.bold),
              items: opts.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: cb,
            ),
          ),
        ],
      ),
    );
  }

  void _deleteReport(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar reporte?'),
        content: const Text('Esta accion es irreversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      if (!mounted) return;
      try {
        await Supabase.instance.client.from('reports').delete().eq('id', id);
        if (!mounted) return;
        context.read<ReportController>().load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al borrar')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
          context.read<ReportController>().loadMore();
        }
        return false;
      },
      child: Consumer<ReportController>(
        builder: (context, controller, child) {
          var reports = controller.reports;
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            reports = reports.where((r) => r.title.toLowerCase().contains(q) || r.description.toLowerCase().contains(q)).toList();
          }
          if (_filterStatus != 'Todos') {
            reports = reports.where((r) => r.status.name == _filterStatus).toList();
          }
          if (_filterCategory != 'Todas') {
            reports = reports.where((r) => r.category.name == _filterCategory).toList();
          }
          if (_filterSeverity != 'Todas') {
            reports = reports.where((r) => r.severity == _filterSeverity).toList();
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Gestion de Reportes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.ink)),
              const SizedBox(height: 24),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar reportes...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildDropdown('Estado:', _filterStatus, ['Todos', 'reported', 'reviewing', 'inProgress', 'resolved'], (v) => setState(() => _filterStatus = v!)),
                    const SizedBox(width: 10),
                    _buildDropdown('Categoria:', _filterCategory, ['Todas', 'pothole', 'waste', 'lighting', 'publicSpace', 'waterLeak', 'trafficLight', 'vandalism'], (v) => setState(() => _filterCategory = v!)),
                    const SizedBox(width: 10),
                    _buildDropdown('Gravedad:', _filterSeverity, ['Todas', 'Alta', 'Media', 'Baja'], (v) => setState(() => _filterSeverity = v!)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (controller.loading && reports.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (reports.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No hay reportes registrados.', style: TextStyle(color: Colors.grey))))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final r = reports[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xffe1e9e6)),
                      ),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailView(report: r))),
                        leading: CircleAvatar(
                          backgroundColor: categoryColor(r.category).withValues(alpha: 0.12),
                          child: Icon(categoryIcon(r.category), color: categoryColor(r.category)),
                        ),
                        title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 6),
                            Row(children: [
                              const Icon(Icons.access_time, size: 13, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(r.time, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
                            ]),
                            const SizedBox(height: 6),
                            Wrap(spacing: 6, runSpacing: 4, children: [
                              _chip(r.status.name, Colors.blueGrey.shade50, Colors.blueGrey),
                              _chip(r.category.name, Colors.blueGrey.shade50, Colors.blueGrey),
                              _chip(
                                r.severity,
                                r.severity == 'Alta' ? Colors.red.shade100 : r.severity == 'Media' ? Colors.orange.shade100 : Colors.green.shade100,
                                r.severity == 'Alta' ? Colors.red.shade700 : r.severity == 'Media' ? Colors.orange.shade800 : Colors.green.shade700,
                                bold: true,
                              ),
                            ]),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteReport(context, r.id),
                          tooltip: 'Eliminar reporte',
                        ),
                      ),
                    );
                  },
                ),
              if (controller.loadingMore)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            ],
          );
        },
      ),
    );
  }

  Widget _chip(String label, Color bg, Color fg, {bool bold = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
  );
}
