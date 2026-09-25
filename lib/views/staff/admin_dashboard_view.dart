import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/report_controller.dart';
import '../../services/pdf_report_service.dart';
import '../../core/theme/app_theme.dart';
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
        title: const Text('Panel de Administración', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
        
        final total = controller.reports.length;
        final resueltos = controller.reports.where((r) => r.status.name == 'resolved').length;
        final pendientes = total - resueltos;
        final resolutionRate = total == 0 ? '0%' : '${((resueltos / total) * 100).toStringAsFixed(0)}%';
        
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('Resumen General', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.ink)),
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
            )
          ],
        );
      }
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
class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<ReportController>(
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
          ],
        );
      },
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
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();

  void _deleteReport(BuildContext context, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar reporte?'),
        content: const Text('Esta acción es irreversible.'),
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
      if (!context.mounted) return;
      try {
        await Supabase.instance.client.from('reports').delete().eq('id', id);
        if (!context.mounted) return;
        context.read<ReportController>().load();
      } catch (e) {
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
          final reports = controller.reports;
          
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text('Gestión de Reportes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.ink)),
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
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => DetailView(report: r)),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.teal.withValues(alpha: 0.1),
                          child: Icon(Icons.report, color: AppTheme.teal),
                        ),
                        title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Estado: ${r.status.name} • Autor: ${r.authorId ?? 'Anónimo'}'),
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
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}


