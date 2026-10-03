import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../role/role_selection_view.dart';
import '../profile/profile_view.dart' show PrivacyPolicyView;

class StaffProfileView extends StatefulWidget {
  const StaffProfileView({super.key});

  @override
  State<StaffProfileView> createState() => _StaffProfileViewState();
}

class _StaffProfileViewState extends State<StaffProfileView> {
  bool _pushEnabled = true;
  bool _emailEnabled = true;

  Future<void> _logOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectionView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final rawName = email.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ');
    final name = rawName.isNotEmpty ? rawName[0].toUpperCase() + rawName.substring(1) : 'Operador';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'O';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: AppTheme.teal.withValues(alpha: 0.2),
              child: Text(
                initial,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.teal),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Personal Municipal', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.teal, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),
        const Text('Configuración de Notificaciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink)),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xffe1e9e6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Alertas Push'),
                subtitle: const Text('Nuevos casos urgentes en tiempo real'),
                value: _pushEnabled,
                activeColor: AppTheme.teal,
                onChanged: (val) => setState(() => _pushEnabled = val),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('Correos electrónicos'),
                subtitle: const Text('Resumen diario de tareas asignadas'),
                value: _emailEnabled,
                activeColor: AppTheme.teal,
                onChanged: (val) => setState(() => _emailEnabled = val),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text('Legal y Cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.ink)),
        const SizedBox(height: 10),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xffe1e9e6)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Políticas de Privacidad'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyView())),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                onTap: _logOut,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
