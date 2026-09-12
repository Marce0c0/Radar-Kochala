import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_view.dart';
import '../staff/staff_views.dart';

class RoleSelectionView extends StatelessWidget {
  const RoleSelectionView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 42),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: 58,
                          height: 58,
                          decoration: const BoxDecoration(color: AppTheme.teal, shape: BoxShape.circle),
                          child: const Icon(Icons.location_on_outlined, color: Colors.white, size: 30),
                        ),
                        const SizedBox(height: 12),
                        const Text('Cochabamba Reporta', textAlign: TextAlign.center, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppTheme.ink)),
                        const SizedBox(height: 4),
                        const Text('Selecciona tu rol para continuar', style: TextStyle(fontSize: 11, color: Color(0xff78908d))),
                        const SizedBox(height: 26),
                        _RoleOption(
                          icon: Icons.home_outlined,
                          title: 'Vecino / Ciudadano',
                          subtitle: 'Reporta incidentes en tu zona',
                          onTap: () => _open(context, const HomeView()),
                        ),
                        _RoleOption(
                          icon: Icons.assignment_outlined,
                          title: 'Operador Municipal',
                          subtitle: 'Valida y asigna reportes',
                          onTap: () => _open(context, const StaffHubView(initialSection: 0)),
                        ),
                        _RoleOption(
                          icon: Icons.build_outlined,
                          title: 'Encargado de Campo',
                          subtitle: 'Ejecuta y verifica tareas',
                          onTap: () => _open(context, const FieldWorkerView()),
                        ),
                        _RoleOption(
                          icon: Icons.auto_graph_outlined,
                          title: 'Administrador',
                          subtitle: 'Gestiona el sistema completo',
                          onTap: () => _open(context, const StaffHubView(initialSection: 3)),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 28),
                      child: Text('Alcaldía de Cochabamba · v1.0', style: TextStyle(fontSize: 9, color: Color(0xff9aaba7))),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: const Color(0xffe1e9e6))),
              child: Row(
                children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xffe5f1ed), borderRadius: BorderRadius.circular(9)), child: Icon(icon, color: AppTheme.teal, size: 19)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.ink)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xff78908d)))])),
                  const Icon(Icons.chevron_right, color: Color(0xff668080), size: 18),
                ],
              ),
            ),
          ),
        ),
      );
}
