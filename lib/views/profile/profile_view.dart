import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../reports/detail_view.dart';
import '../role/role_selection_view.dart';
import '../widgets/report_card.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key, required this.onNew});

  final Future<void> Function() onNew;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportController>();

    // CORRECCIÓN #3 y #4: Leemos los datos reales del usuario autenticado.
    final user = Supabase.instance.client.auth.currentUser;
    final isGuest = user == null;
    final email = user?.email ?? '';
    // Tomamos la primera letra del email (o '?' si no hay usuario).
    final initial =
        email.isNotEmpty ? email[0].toUpperCase() : '?';
    // Nombre para mostrar: usamos la parte antes del @ del email.
    final displayName = email.isNotEmpty
        ? email.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ')
        : 'Invitado';

    final mine = controller.reports.where((r) => r.isMine).toList();
    final resolved =
        mine.where((r) => r.status == ReportStatus.resolved).length;
    // CORRECCIÓN #5: "En proceso" calculado desde datos reales.
    final inProgress =
        mine.where((r) => r.status == ReportStatus.inProgress).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        const Text('Perfil',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink)),
        const SizedBox(height: 16),
        // Tarjeta de perfil con datos reales del usuario autenticado.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: AppTheme.teal, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xff409d91),
                  child: Text(initial,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGuest ? 'Invitado' : displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (!isGuest) ...[
                      const SizedBox(height: 4),
                      Text(email,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isGuest) ...[
          const SizedBox(height: 14),
          Row(children: [
            _Stat(value: '${mine.length}', label: 'Enviados'),
            const SizedBox(width: 10),
            _Stat(value: '$resolved', label: 'Resueltos'),
            const SizedBox(width: 10),
            // CORRECCIÓN #5: Dato calculado, no hardcodeado.
            _Stat(value: '$inProgress', label: 'En proceso'),
          ]),
          const SizedBox(height: 24),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
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
                child: Center(
                    child: Text('Todavía no has enviado reportes.')))
          else
            ...mine.take(2).map((report) => ReportCard(
                  report: report,
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => DetailView(report: report))),
                )),
        ] else ...[
          // Usuario invitado: invitamos a crear cuenta.
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffe1e9e6)),
            ),
            child: Column(
              children: [
                const Icon(Icons.person_outline,
                    size: 40, color: Color(0xff78908d)),
                const SizedBox(height: 10),
                const Text('Estás navegando como invitado',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: AppTheme.ink)),
                const SizedBox(height: 6),
                const Text(
                  'Crea una cuenta para enviar reportes y hacer seguimiento.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xff668080), fontSize: 13),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const RoleSelectionView())),
                  style: FilledButton.styleFrom(backgroundColor: AppTheme.teal),
                  child: const Text('Iniciar sesión / Registrarse'),
                ),
              ],
            ),
          ),
        ],
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
        if (!isGuest)
          // CORRECCIÓN #6: signOut() real + navegación a RoleSelectionView.
          _ActionTile(
              icon: Icons.logout,
              title: 'Cerrar sesión',
              danger: true,
              onTap: () => _confirmLogout(context)),
      ],
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // CORRECCIÓN #6: Confirmación antes de cerrar sesión + signOut real.
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffd9684b)),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (e) {
        debugPrint('Error al cerrar sesión: $e');
      } finally {
        if (context.mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const RoleSelectionView()),
            (route) => false,
          );
        }
      }
    }
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
                style:
                    const TextStyle(fontSize: 11, color: Color(0xff78908d))),
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