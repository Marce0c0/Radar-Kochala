import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../reports/detail_view.dart';
import '../role/role_selection_view.dart';
import '../widgets/report_card.dart';

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
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => section = value == 'admin' ? 3 : 0),
            itemBuilder: (_) => const [PopupMenuItem(value: 'operator', child: Text('Vista operador')), PopupMenuItem(value: 'admin', child: Text('Vista administrador'))],
          ),
        ],
      ),
      body: IndexedStack(index: section, children: [
        _OperatorBoard(reports: allReports, onOpen: _openReport),
        _TeamView(onMessage: _message),
        _StaffMapView(reports: allReports, onOpen: _openReport),
        _AdminView(onMessage: _message),
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
  void _message(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class FieldWorkerView extends StatefulWidget {
  const FieldWorkerView({super.key});
  @override
  State<FieldWorkerView> createState() => _FieldWorkerViewState();
}

class _FieldWorkerViewState extends State<FieldWorkerView> {
  int _currentIndex = 0;

  // CORRECCIÓN APLICADA AQUÍ: Logout seguro con try-catch
  void _logOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      debugPrint('Error al cerrar sesión: $e');
    } finally {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => const RoleSelectionView()), 
          (route) => false
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportController>();
    final assignedTasks = controller.reports.where((r) => r.status == ReportStatus.inProgress).toList();
    final completedTasks = controller.reports.where((r) => r.status == ReportStatus.resolved).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis tareas', style: TextStyle(fontWeight: FontWeight.w900))),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _PageIntro(title: 'Mis tareas', subtitle: 'Trabajador de Campo'),
              _StatsRow(items: [('${assignedTasks.length}', 'Pendientes'), ('0', 'Ejecución'), ('$completedTasks', 'Completadas')]),
              const SizedBox(height: 18),
              const _Heading('Asignadas hoy'),
              if (assignedTasks.isEmpty) const Padding(padding: EdgeInsets.only(top: 20), child: Text('No tienes tareas asignadas hoy.', style: TextStyle(color: Colors.grey))),
              ...assignedTasks.map((report) => _TaskCard(report: report, action: 'Iniciar')),
            ],
          ),
          const Center(child: Text('Mapa de ruta próximo a implementarse', style: TextStyle(color: Colors.grey))),
          const Center(child: Text('Historial de tareas finalizadas', style: TextStyle(color: Colors.grey))),
          Center(child: FilledButton.icon(onPressed: _logOut, style: FilledButton.styleFrom(backgroundColor: const Color(0xffd9684b)), icon: const Icon(Icons.logout), label: const Text('Cerrar Sesión'))),
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

class TaskExecutionView extends StatelessWidget {
  const TaskExecutionView({super.key, required this.report});
  final Report report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ejecución de Tarea', style: TextStyle(fontWeight: FontWeight.w900))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ReportCard(report: report, onTap: () {}),
          const SizedBox(height: 24),
          const _Heading('Actualizar Estado'),
          TextField(maxLines: 4, decoration: InputDecoration(hintText: 'Describe el trabajo realizado...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: Colors.white)),
          const SizedBox(height: 20),
          OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Adjuntar foto')),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () async {
              await context.read<ReportController>().updateStatus(report.id, ReportStatus.resolved);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Tarea marcada como resuelta!')));
                Navigator.pop(context);
              }
            }, 
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), backgroundColor: AppTheme.teal), 
            child: const Text('Finalizar Tarea', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
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
                      child: Container(decoration: BoxDecoration(color: AppTheme.ink, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.report_problem, color: Colors.white, size: 20)),
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

class ValidateReportView extends StatefulWidget {
  const ValidateReportView({super.key, required this.report});
  final Report report;
  @override
  State<ValidateReportView> createState() => _ValidateReportViewState();
}

class _ValidateReportViewState extends State<ValidateReportView> {
  String status = 'Reportado';
  String worker = 'Trabajador B';
  final note = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    if (widget.report.status == ReportStatus.reported) status = 'Reportado';
    if (widget.report.status == ReportStatus.reviewing) status = 'En revisión';
    if (widget.report.status == ReportStatus.inProgress) status = 'En proceso';
    if (widget.report.status == ReportStatus.resolved) status = 'Resuelto';
  }

  @override
  void dispose() { note.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Validar reporte', style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ReportCard(report: widget.report, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailView(report: widget.report)))),
          const _Heading('Clasificar gravedad'),
          _Segmented(options: const ['Alta', 'Media', 'Baja'], selected: widget.report.severity, onChanged: (_) {}),
          const _Heading('Actualizar estado'),
          _Segmented(options: const ['Reportado', 'En revisión', 'En proceso', 'Resuelto'], selected: status, onChanged: (v) => setState(() => status = v)),
          const _Heading('Asignar encargado de campo'),
          ...['Trabajador A', 'Trabajador B', 'Trabajador C', 'Trabajador D'].map((name) => _WorkerTile(name: name, selected: worker == name, onTap: () => setState(() => worker = name))),
          const _Heading('Nota de atención'),
          TextField(controller: note, maxLines: 3, decoration: const InputDecoration(hintText: 'Priorizar trabajo...')),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              ReportStatus newStatus = ReportStatus.reported;
              if (status == 'En revisión') newStatus = ReportStatus.reviewing;
              if (status == 'En proceso') newStatus = ReportStatus.inProgress;
              if (status == 'Resuelto') newStatus = ReportStatus.resolved;

              await context.read<ReportController>().updateStatus(widget.report.id, newStatus);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte actualizado y asignado')));
                Navigator.pop(context);
              }
            }, 
            child: const Text('Guardar y asignar')
          ),
        ]),
      );
}

class _TeamView extends StatelessWidget {
  const _TeamView({required this.onMessage});
  final ValueChanged<String> onMessage;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
        const _PageIntro(title: 'Gestión de equipo', subtitle: '7 miembros · 4 en línea'),
        ...['Trabajador A', 'Trabajador B', 'Trabajador C', 'Trabajador D', 'Supervisor F'].map((name) => Card(child: ListTile(leading: CircleAvatar(backgroundColor: AppTheme.teal, child: Text(name[name.length - 1])), title: Text(name), subtitle: const Text('Zona Centro · En línea'), trailing: name.contains('Trabajador') ? const FilledButton(onPressed: null, child: Text('Asignar')) : null))),
      ]);
}

class _AdminView extends StatelessWidget {
  const _AdminView({required this.onMessage});
  final ValueChanged<String> onMessage;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
        const _PageIntro(title: 'Panel admin', subtitle: 'Configuración del sistema'),
        const _StatsRow(items: [('5', 'Usuarios'), ('1', 'Operadores'), ('1', 'Suspendidos')]),
        const _Heading('Gestión'),
        ...['Zonas y distritos', 'Categorías de reportes', 'Notificaciones'].map((title) => ListTile(leading: const Icon(Icons.tune, color: AppTheme.teal), title: Text(title), trailing: const Icon(Icons.chevron_right), onTap: () => onMessage('$title abierto'))),
        const SizedBox(height: 20),
        
        // CORRECCIÓN APLICADA AQUÍ: Logout seguro con try-catch
        FilledButton.icon(
          onPressed: () async {
            try {
              await Supabase.instance.client.auth.signOut();
            } catch (e) {
              debugPrint('Error al cerrar sesión: $e');
            } finally {
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (_) => const RoleSelectionView()), 
                  (route) => false
                );
              }
            }
          },
          style: FilledButton.styleFrom(backgroundColor: const Color(0xffd9684b)),
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar Sesión del Sistema'),
        ),
      ]);
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