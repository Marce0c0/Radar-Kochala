import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../reports/detail_view.dart';
import '../widgets/report_card.dart';

const _fieldPotholeTask = Report(
  id: '1',
  title: 'Bache grande en la Av. Ballivián',
  category: ReportCategory.pothole,
  status: ReportStatus.inProgress,
  neighborhood: 'El Prado',
  time: 'Hace 2 horas',
  severity: 'Alta',
  description: 'Bache peligroso cerca de la rotonda principal que afecta a los vehículos.',
  latitude: -17.3895,
  longitude: -66.1568,
);

const _fieldWasteTask = Report(
  id: '2',
  title: 'Acumulación de residuos en esquina',
  category: ReportCategory.waste,
  status: ReportStatus.reported,
  neighborhood: 'Recoleta',
  time: 'Hace 5 horas',
  severity: 'Media',
  description: 'Bolsas de basura rotas dejadas fuera del contenedor asignado.',
  latitude: -17.382,
  longitude: -66.15,
);

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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Panel municipal',
              style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) =>
                  setState(() => section = value == 'admin' ? 3 : 0),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'operator', child: Text('Vista operador')),
                PopupMenuItem(
                    value: 'admin', child: Text('Vista administrador')),
              ],
            ),
          ],
        ),
        body: IndexedStack(index: section, children: [
          _OperatorBoard(onOpen: _openReport),
          _TeamView(onMessage: _message),
          _StaffMapView(onOpen: _openReport),
          _AdminView(onMessage: _message),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: section,
          onDestinationSelected: (value) => setState(() => section = value),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Bandeja'),
            NavigationDestination(
                icon: Icon(Icons.groups_outlined),
                selectedIcon: Icon(Icons.groups),
                label: 'Equipo'),
            NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Mapa'),
            NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Admin'),
          ],
        ),
      );

  void _openReport(Report report) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => ValidateReportView(report: report)));

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));
}

class FieldWorkerView extends StatelessWidget {
  const FieldWorkerView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Mis tareas', style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none))],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          children: const [
            _PageIntro(title: 'Mis tareas', subtitle: 'Trabajador B · Zona Norte'),
            _StatsRow(items: [('2', 'Pendientes'), ('1', 'En ejecución'), ('5', 'Completadas')]),
            SizedBox(height: 18),
            _Heading('Asignadas hoy'),
            _TaskCard(report: _fieldPotholeTask, action: 'Iniciar'),
            _TaskCard(report: _fieldWasteTask, action: 'Iniciar'),
            _TaskCard(
              report: Report(
                id: '4',
                title: 'Luminaria apagada de noche',
                category: ReportCategory.lighting,
                status: ReportStatus.inProgress,
                neighborhood: 'Sacaba',
                time: 'Hace 3 h',
                severity: 'Media',
                description: 'Luminaria sin funcionamiento.',
              ),
              action: 'Verificar',
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: const [
            NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'Tareas'),
            NavigationDestination(icon: Icon(Icons.key_outlined), selectedIcon: Icon(Icons.key), label: 'En campo'),
            NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history_toggle_off), label: 'Historial'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Mi perfil'),
          ],
        ),
      );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.report, required this.action});
  final Report report;
  final String action;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xffdcebe6), child: Icon(Icons.build_outlined, color: AppTheme.teal)),
          title: Text(report.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${report.neighborhood} · Gravedad ${report.severity}'),
          trailing: FilledButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tarea marcada como: $action'))),
            child: Text(action),
          ),
        ),
      );
}

class _OperatorBoard extends StatelessWidget {
  const _OperatorBoard({required this.onOpen});
  final ValueChanged<Report> onOpen;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
        children: [
          const _PageIntro(
              title: 'Panel operador',
              subtitle: 'Distrito Centro · Turno mañana'),
          const _StatsRow(items: [
            ('3', 'Pendientes'),
            ('2', 'En proceso'),
            ('3', 'Resueltas')
          ]),
          const _Heading('Requieren validación'),
          _StaffReport(
              report: reportsSeed[1],
              action: 'Validar',
              onTap: () => onOpen(reportsSeed[1])),
          _StaffReport(
              report: const Report(
                  id: '3',
                  title: 'Hundimiento sobre la vía',
                  category: ReportCategory.pothole,
                  status: ReportStatus.reported,
                  neighborhood: 'Recoleta',
                  time: 'Hace 1 h',
                  severity: 'Alta',
                  description: 'Hundimiento visible en la calzada.'),
              action: 'Validar',
              onTap: () {}),
          const _Heading('En proceso'),
          _StaffReport(
              report: reportsSeed[0],
              action: 'Asignar',
              onTap: () => onOpen(reportsSeed[0])),
          _StaffReport(
              report: const Report(
                  id: '4',
                  title: 'Luminaria apagada de noche',
                  category: ReportCategory.lighting,
                  status: ReportStatus.inProgress,
                  neighborhood: 'Sacaba',
                  time: 'Hace 3 h',
                  severity: 'Media',
                  description: 'Luminaria sin funcionamiento.'),
              action: 'Asignar',
              onTap: () {}),
        ],
      );
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
  void dispose() {
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Validar reporte',
                style: TextStyle(fontWeight: FontWeight.w900))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          ReportCard(
              report: widget.report,
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DetailView(report: widget.report)))),
          const _Heading('Clasificar gravedad'),
          _Segmented(
              options: const ['Alta', 'Media', 'Baja'],
              selected: widget.report.severity,
              onChanged: (_) {}),
          const _Heading('Actualizar estado'),
          _Segmented(
              options: const [
                'Reportado',
                'En revisión',
                'En proceso',
                'Resuelto'
              ],
              selected: status,
              onChanged: (value) => setState(() => status = value)),
          const _Heading('Asignar encargado de campo'),
          ...['Trabajador A', 'Trabajador B', 'Trabajador C', 'Trabajador D']
              .map((name) => _WorkerTile(
                  name: name,
                  selected: worker == name,
                  onTap: () => setState(() => worker = name))),
          const _Heading('Nota de atención'),
          TextField(
              controller: note,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Priorizar trabajo antes del mediodía...')),
          const SizedBox(height: 18),
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Guardar y asignar')),
        ]),
      );
}

class _TeamView extends StatelessWidget {
  const _TeamView({required this.onMessage});
  final ValueChanged<String> onMessage;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        const _PageIntro(
            title: 'Gestión de equipo', subtitle: '7 miembros · 4 en línea'),
        ...[
          'Trabajador A',
          'Trabajador B',
          'Trabajador C',
          'Trabajador D',
          'Trabajador E',
          'Supervisor F',
          'Supervisor G'
        ].map((name) => Card(
            child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: AppTheme.teal,
                    child: Text(name.substring(name.length - 1))),
                title: Text(name),
                subtitle: const Text('Zona Centro · En línea'),
                trailing: name.contains('Trabajador') && !name.contains('D')
                    ? const FilledButton(
                        onPressed: null, child: Text('Asignar'))
                    : null))),
      ]);
}

class _StaffMapView extends StatelessWidget {
  const _StaffMapView({required this.onOpen});
  final ValueChanged<Report> onOpen;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        const _PageIntro(
            title: 'Mapa de reportes',
            subtitle: 'Vista operador · Todos los activos'),
        Container(
            height: 220,
            decoration: BoxDecoration(
                color: const Color(0xffdcebe6),
                borderRadius: BorderRadius.circular(20)),
            child: const Center(
                child: Icon(Icons.map, size: 80, color: AppTheme.teal))),
        const SizedBox(height: 16),
        _StaffReport(
            report: reportsSeed[0],
            action: 'Abrir',
            onTap: () => onOpen(reportsSeed[0])),
        _StaffReport(
            report: reportsSeed[1],
            action: 'Abrir',
            onTap: () => onOpen(reportsSeed[1])),
      ]);
}

class _AdminView extends StatelessWidget {
  const _AdminView({required this.onMessage});
  final ValueChanged<String> onMessage;
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        const _PageIntro(
            title: 'Panel admin', subtitle: 'Configuración del sistema'),
        const _StatsRow(items: [
          ('5', 'Usuarios'),
          ('1', 'Operadores'),
          ('1', 'Suspendidos')
        ]),
        const _Heading('Gestión'),
        ...[
          'Zonas y distritos',
          'Categorías de reportes',
          'Notificaciones',
          'Roles y permisos',
          'Seguridad y acceso',
          'Backup y exportación'
        ].map((title) => ListTile(
            leading: const Icon(Icons.tune, color: AppTheme.teal),
            title: Text(title),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onMessage('$title abierto'))),
        const _Heading('Estadísticas del sistema'),
        const ListTile(
            title: Text('Total reportes registrados'),
            trailing:
                Text('1,250', style: TextStyle(fontWeight: FontWeight.w800))),
        const ListTile(
            title: Text('Reportes resueltos'),
            trailing: Text('890 (71%)',
                style: TextStyle(fontWeight: FontWeight.w800))),
      ]);
}

class _PageIntro extends StatelessWidget {
  const _PageIntro({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xff78908d)))
      ]));
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 9),
      child: Text(text,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, color: AppTheme.ink)));
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.items});
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => Row(
        children: items
            .map((item) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: const Color(0xffe1e9e6)),
                    ),
                    child: Column(children: [
                      Text(item.$1,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.teal)),
                      Text(item.$2,
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xff78908d))),
                    ]),
                  ),
                ))
            .toList(),
      );
}

class _StaffReport extends StatelessWidget {
  const _StaffReport(
      {required this.report, required this.action, required this.onTap});
  final Report report;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const CircleAvatar(
              backgroundColor: Color(0xffdcebe6),
              child: Icon(Icons.report, color: AppTheme.teal)),
          title:
              Text(report.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${report.neighborhood} · ${report.time}'),
          trailing: FilledButton(onPressed: onTap, child: Text(action)),
        ),
      );
}

class _Segmented extends StatelessWidget {
  const _Segmented(
      {required this.options, required this.selected, required this.onChanged});
  final List<String> options;
  final String selected;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(
      spacing: 8,
      children: options
          .map((option) => ChoiceChip(
              label: Text(option),
              selected: option == selected,
              onSelected: (_) => onChanged(option)))
          .toList());
}

class _WorkerTile extends StatelessWidget {
  const _WorkerTile(
      {required this.name, required this.selected, required this.onTap});
  final String name;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: selected ? const Color(0xffe5f1ed) : Colors.white,
        child: ListTile(
          leading: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: AppTheme.teal),
          title: Text(name),
          subtitle: const Text('En línea'),
          onTap: onTap,
        ),
      );
}
