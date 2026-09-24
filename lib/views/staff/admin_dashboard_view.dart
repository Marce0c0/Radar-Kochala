import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../role/role_selection_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  Map<String, int> _counts = {};
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    Future.microtask(() => context.read<ReportController>().load());
  }

  Future<void> _loadData() async {
    try {
      final client = Supabase.instance.client;
      final profiles = await client.from('profiles').select('id, role, email');
      
      final rows = List<Map<String, dynamic>>.from(profiles);
      final Map<String, int> counts = {};
      for (final r in rows) {
        final role = r['role'].toString();
        counts[role] = (counts[role] ?? 0) + 1;
      }
      
      if (mounted) {
        setState(() {
          _counts = counts;
          _users = rows;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading admin data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'role': newRole})
          .eq('id', userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol actualizado correctamente')));
        _loadData(); // reload
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar rol: $e')));
      }
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const RoleSelectionView()), (route) => false);
    }
  }

  Future<void> _deleteReport(String reportId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar reporte'),
        content: const Text('¿Estás seguro de que deseas eliminar este reporte permanentemente?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await context.read<ReportController>().deleteReport(reportId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte eliminado')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    
    final total = _counts.values.fold(0, (a, b) => a + b);
    final ciudadanos = _counts['ciudadano'] ?? 0;
    final trabajadores = _counts['trabajador'] ?? 0;
    final operadores = _counts['operador'] ?? 0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Administración', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _loading = true);
                _loadData();
                context.read<ReportController>().load();
              },
              tooltip: 'Actualizar',
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _logout,
              tooltip: 'Cerrar sesión',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.dashboard), text: 'Resumen'),
              Tab(icon: Icon(Icons.people), text: 'Usuarios'),
              Tab(icon: Icon(Icons.report), text: 'Reportes'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: RESUMEN
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Métricas del Sistema', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard('Usuarios Totales', total.toString(), Icons.people_outline),
                    const SizedBox(width: 12),
                    _StatCard('Ciudadanos', ciudadanos.toString(), Icons.person_outline),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard('Trabajadores', trabajadores.toString(), Icons.engineering_outlined),
                    const SizedBox(width: 12),
                    _StatCard('Operadores', operadores.toString(), Icons.headset_mic_outlined),
                  ],
                ),
                const SizedBox(height: 30),
                const Text('Mapa de Incidentes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                const Text('Visualiza la ubicación de los reportes actuales.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 350,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Consumer<ReportController>(
                      builder: (context, controller, child) {
                        final reports = controller.reports.where((r) => r.latitude != null && r.longitude != null).toList();
                        return FlutterMap(
                          options: MapOptions(
                            initialCenter: const LatLng(-17.3895, -66.1568),
                            initialZoom: 13.5,
                            cameraConstraint: CameraConstraint.contain(
                              bounds: LatLngBounds(
                                const LatLng(-17.25, -66.30),
                                const LatLng(-17.50, -65.90),
                              ),
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.radar.kochala',
                            ),
                            CircleLayer(
                              circles: reports.map((r) => CircleMarker(
                                point: LatLng(r.latitude!, r.longitude!),
                                color: Colors.red.withAlpha(76), // 0.3 alpha
                                borderStrokeWidth: 1,
                                borderColor: Colors.red,
                                radius: 60,
                                useRadiusInMeter: true,
                              )).toList(),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            
            // TAB 2: USUARIOS
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Gestión de Usuarios', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                const Text('Asigna roles a los usuarios del sistema.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 16),
                if (_users.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: Text('No hay usuarios registrados.', style: TextStyle(color: Colors.grey))),
                  ),
                ..._users.map((u) {
                  final email = u['email']?.toString() ?? 'Sin correo';
                  final role = u['role']?.toString() ?? 'ciudadano';
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xffe1e9e6)),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.teal,
                        child: Text(role.isNotEmpty ? role[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(email, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Rol actual: $role', style: const TextStyle(color: AppTheme.teal)),
                      trailing: PopupMenuButton<String>(
                        icon: const Icon(Icons.manage_accounts, color: Colors.grey),
                        onSelected: (newRole) => _updateUserRole(u['id'], newRole),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'ciudadano', child: Text('Hacer Ciudadano')),
                          PopupMenuItem(value: 'trabajador', child: Text('Hacer Trabajador de Campo')),
                          PopupMenuItem(value: 'operador', child: Text('Hacer Operador')),
                          PopupMenuItem(value: 'admin', child: Text('Hacer Administrador', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
            
            // TAB 3: REPORTES
            NotificationListener<ScrollEndNotification>(
              onNotification: (scrollInfo) {
                if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                  context.read<ReportController>().loadMore();
                }
                return false;
              },
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('Control de Reportes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                  const Text('Borra reportes inválidos o revisa la carga total.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 16),
                  Consumer<ReportController>(
                    builder: (context, controller, child) {
                      if (controller.loading) return const Center(child: CircularProgressIndicator());
                      final reports = controller.reports;
                      if (reports.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No hay reportes.', style: TextStyle(color: Colors.grey))));
                      
                      return Column(
                        children: [
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: reports.length,
                            itemBuilder: (context, index) {
                              final r = reports[index];
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: const BorderSide(color: Color(0xffe1e9e6)),
                                ),
                                margin: const EdgeInsets.only(bottom: 12),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  title: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('Estado: ${r.status.name}\nReportado por: ${r.userId}', style: const TextStyle(fontSize: 12)),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deleteReport(r.id),
                                    tooltip: 'Eliminar reporte permanentemente',
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
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.teal, size: 28),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.ink)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}
