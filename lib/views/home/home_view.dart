import 'package:flutter/material.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../map/map_explore_view.dart';
import '../reports/detail_view.dart';
import '../reports/new_report_view.dart';
import '../profile/profile_view.dart';
import '../widgets/report_card.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});
  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final controller = ReportController();
  int tab = 0;

  @override
  void initState() {
    super.initState();
    controller.load();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (_, __) => Scaffold(
          body: SafeArea(
            child: IndexedStack(
              index: tab,
              children: [
                _ExploreView(controller: controller, onNew: _newReport),
                MapExploreView(controller: controller),
                _MyReportsView(controller: controller),
                ProfileView(controller: controller, onNew: _newReport),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: (v) => setState(() => tab = v),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore),
                  label: 'Explorar'),
              NavigationDestination(
                  icon: Icon(Icons.map_outlined),
                  selectedIcon: Icon(Icons.map),
                  label: 'Mapa'),
              NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment),
                  label: 'Mis reportes'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil'),
            ],
          ),
        ),
      );

  Future<void> _newReport() async {
    final draft = await Navigator.push<ReportDraft>(
      context,
      MaterialPageRoute(builder: (_) => const NewReportView()),
    );
    if (draft != null) {
      await controller.create(draft);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reporte guardado en la demo.')),
        );
      }
    }
  }
}

class _ExploreView extends StatelessWidget {
  const _ExploreView({required this.controller, required this.onNew});
  final ReportController controller;
  final Future<void> Function() onNew;

  @override
  Widget build(BuildContext context) {
    final stats = controller.statistics;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      children: [
        // Encabezado con Animación de Bienvenida
        const _WelcomeHeader(),
        const SizedBox(height: 20),
        Row(
          children: [
            _Metric('Reportes', '${stats.total}', Icons.campaign_outlined),
            const SizedBox(width: 10),
            _Metric(
                'Resueltos', stats.resolutionRate, Icons.check_circle_outline),
          ],
        ),
        const SizedBox(height: 22),
        const Text('Explora por categoría',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [null, ...ReportCategory.values]
              .map((c) => ChoiceChip(
                    label: Text(c == null ? 'Todos' : categoryName(c)),
                    selected: controller.filter == c,
                    onSelected: (_) => controller.setFilter(c),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Actividad reciente',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink)),
            TextButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add),
              label: const Text('Reportar'),
            ),
          ],
        ),
        ...controller.visibleReports.map((r) => ReportCard(
              report: r,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailView(report: r)),
              ),
            )),
        if (controller.visibleReports.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Text('No hay reportes para este filtro.')),
          ),
      ],
    );
  }
}

/// Widget independiente con Animación de Bienvenida (Fade + Deslizamiento)
class _WelcomeHeader extends StatefulWidget {
  const _WelcomeHeader();

  @override
  State<_WelcomeHeader> createState() => _WelcomeHeaderState();
}

class _WelcomeHeaderState extends State<_WelcomeHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25), // Inicia un poco más abajo
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward(); // Inicia la animación automáticamente
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¡Bienvenido! 👋',
                        style: TextStyle(
                            fontSize: 27,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink)),
                    SizedBox(height: 3),
                    Text('Cochabamba: Reporta. Sigue. Mejora.',
                        style: TextStyle(color: Color(0xff668080))),
                  ],
                ),
                CircleAvatar(
                  backgroundColor: Color(0xffd8eeea),
                  child: Icon(Icons.location_city, color: AppTheme.teal),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.teal,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_outlined,
                      color: Colors.white, size: 38),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Tu ciudad, más cuidada\nTodo lo que reportes queda dentro de Cochabamba.',
                      style: TextStyle(
                          color: Colors.white,
                          height: 1.4,
                          fontWeight: FontWeight.w600),
                    ),
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

class _MyReportsView extends StatelessWidget {
  const _MyReportsView({required this.controller});
  final ReportController controller;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
        children: [
          const Text('Mis reportes',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink)),
          const SizedBox(height: 8),
          const Text('Aquí puedes seguir los reportes que enviaste.',
              style: TextStyle(color: Color(0xff668080))),
          const SizedBox(height: 26),
          ...controller.reports.where((r) => r.isMine).map((r) => ReportCard(
                report: r,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DetailView(report: r)),
                ),
              )),
        ],
      );
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);

  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xffe1e9e6)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.teal),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xff78908d))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
