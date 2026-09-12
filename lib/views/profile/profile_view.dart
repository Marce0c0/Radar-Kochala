import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../reports/detail_view.dart';
import '../widgets/report_card.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.onNew}); // Ya no pedimos el controller

  final Future<void> Function() onNew;

  @override
  Widget build(BuildContext context) {
    // Obtenemos el controlador directamente del Provider
    final controller = context.watch<ReportController>();
    
    final mine = controller.reports.where((report) => report.isMine).toList();
    final resolved =
        mine.where((report) => report.status.name == 'resolved').length;
        
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        const Text('Perfil',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: AppTheme.teal, borderRadius: BorderRadius.circular(20)),
          child: const Row(
            children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xff409d91),
                  child: Text('S', // Actualizado con tu inicial
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800))),
              SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Vecino Activo',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Cochabamba, Bolivia',
                    style: TextStyle(color: Colors.white70)),
                SizedBox(height: 8),
                Text('Cuenta Ciudadana',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          _Stat(value: '${mine.length}', label: 'Enviados'),
          const SizedBox(width: 10),
          _Stat(value: '$resolved', label: 'Resueltos'),
          const SizedBox(width: 10),
          const _Stat(value: '2', label: 'En proceso'),
        ]),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Mis reportes recientes',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink)),
          TextButton(onPressed: onNew, child: const Text('Reportar')),
        ]),
        if (mine.isEmpty)
          const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: Text('Todavía no has enviado reportes.')))
        else
          ...mine.take(2).map((report) => ReportCard(
                report: report,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => DetailView(report: report))),
              )),
        const SizedBox(height: 12),
        const _SectionTitle('Configuración'),
        _ActionTile(
            icon: Icons.notifications_none,
            title: 'Notificaciones',
            onTap: () => _showMessage(context, 'Notificaciones activadas')),
        _ActionTile(
            icon: Icons.shield_outlined,
            title: 'Privacidad y datos',
            onTap: () =>
                _showMessage(context, 'Tus datos se mantienen protegidos')),
        _ActionTile(
            icon: Icons.help_outline,
            title: 'Ayuda y soporte',
            onTap: () =>
                _showMessage(context, 'Soporte disponible de lunes a viernes')),
        _ActionTile(
            icon: Icons.logout,
            title: 'Cerrar sesión',
            danger: true,
            onTap: () => _showMessage(context, 'Sesión cerrada en modo demo')),
      ],
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffe1e9e6))),
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.teal)),
            const SizedBox(height: 3),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xff78908d))),
          ]),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
              color: Color(0xff78908d))));
}

class _ActionTile extends StatelessWidget {
  const _ActionTile(
      {required this.icon,
      required this.title,
      required this.onTap,
      this.danger = false});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon,
            color: danger ? const Color(0xffd9684b) : const Color(0xff668080)),
        title: Text(title,
            style: TextStyle(
                color: danger ? const Color(0xffd9684b) : AppTheme.ink,
                fontWeight: FontWeight.w700)),
        trailing: const Icon(Icons.chevron_right, color: Color(0xff9aaba7)),
        onTap: onTap,
      );
}