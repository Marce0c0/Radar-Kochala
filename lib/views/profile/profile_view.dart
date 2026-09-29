import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettingsView()))),
        _ActionTile(
            icon: Icons.shield_outlined,
            title: 'Privacidad y datos',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyView()))),
        _ActionTile(
            icon: Icons.help_outline,
            title: 'Ayuda y soporte',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SupportTicketView(userEmail: email)))),
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

class NotificationsSettingsView extends StatefulWidget {
  const NotificationsSettingsView({super.key});
  @override
  State<NotificationsSettingsView> createState() => _NotificationsSettingsViewState();
}

class _NotificationsSettingsViewState extends State<NotificationsSettingsView> {
  bool _newReports = true;
  bool _myUpdates = true;
  bool _announcements = false;
  bool _weeklySummary = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _newReports = prefs.getBool('notif_new_reports') ?? true;
      _myUpdates = prefs.getBool('notif_my_updates') ?? true;
      _announcements = prefs.getBool('notif_announcements') ?? false;
      _weeklySummary = prefs.getBool('notif_weekly_summary') ?? true;
      _loading = false;
    });
  }

  Future<void> _toggleSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          SwitchListTile(
            activeColor: AppTheme.teal,
            title: const Text('Actualizaciones de mis reportes', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Recibe alertas cuando un operador asigne o resuelva tu caso.'),
            value: _myUpdates,
            onChanged: (v) {
              setState(() => _myUpdates = v);
              _toggleSetting('notif_my_updates', v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            activeColor: AppTheme.teal,
            title: const Text('Nuevos reportes cerca de mi', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Te avisaremos cuando tus vecinos reporten problemas cercanos.'),
            value: _newReports,
            onChanged: (v) {
              setState(() => _newReports = v);
              _toggleSetting('notif_new_reports', v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            activeColor: AppTheme.teal,
            title: const Text('Avisos de la alcaldía', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Información oficial sobre cortes de vía y mantenimientos programados.'),
            value: _announcements,
            onChanged: (v) {
              setState(() => _announcements = v);
              _toggleSetting('notif_announcements', v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            activeColor: AppTheme.teal,
            title: const Text('Resumen semanal del ranking', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Descubre quiénes fueron los ciudadanos más activos de la semana.'),
            value: _weeklySummary,
            onChanged: (v) {
              setState(() => _weeklySummary = v);
              _toggleSetting('notif_weekly_summary', v);
            },
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacidad y Datos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Políticas de Privacidad y Términos de Uso',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.ink),
            ),
            const SizedBox(height: 16),
            const Text(
              'Al registrarte y utilizar Radar Kochala, aceptas las siguientes políticas respecto a tus datos personales y contenido generado:',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            _buildSection('1. Uso de la Ubicación', 
              'La aplicación recopila datos de ubicación (GPS) únicamente al momento de registrar un reporte para asociarlo a una ubicación en el mapa. No realizamos un seguimiento de tu ubicación en segundo plano.'),
            _buildSection('2. Fotografías y Evidencia', 
              'Las imágenes que subas a la plataforma serán públicas y accesibles por la alcaldía y otros ciudadanos con el fin de resolver problemas urbanos. Asegúrate de no incluir rostros, placas vehiculares o información personal en tus fotos.'),
            _buildSection('3. Datos de la Cuenta', 
              'Tu correo electrónico se utiliza exclusivamente para iniciar sesión y enviarte notificaciones sobre tus reportes. No compartimos tu correo con terceros ni lo utilizamos para fines publicitarios.'),
            _buildSection('4. Penalizaciones por Uso Indebido', 
              'El equipo de Radar Kochala se reserva el derecho de suspender cuentas que suban contenido inapropiado, generen reportes falsos o intenten alterar el ranking ciudadano maliciosamente.'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.teal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined, color: AppTheme.teal, size: 30),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tus datos están almacenados de forma segura mediante Supabase, cumpliendo con estándares de seguridad internacionales.',
                      style: TextStyle(fontSize: 13, color: AppTheme.ink),
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

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.ink)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5, color: Color(0xff555555))),
        ],
      ),
    );
  }
}

class SupportTicketView extends StatefulWidget {
  const SupportTicketView({super.key, required this.userEmail});
  final String userEmail;

  @override
  State<SupportTicketView> createState() => _SupportTicketViewState();
}

class _SupportTicketViewState extends State<SupportTicketView> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitTicket() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('support_tickets').insert({
        'user_id': user?.id,
        'email': widget.userEmail.isNotEmpty ? widget.userEmail : (user?.email ?? 'Invitado'),
        'message': text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mensaje enviado a soporte correctamente. ¡Gracias!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda y Soporte', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿En qué podemos ayudarte?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.ink),
            ),
            const SizedBox(height: 8),
            const Text(
              'Describe tu problema, duda o sugerencia. El equipo de Radar Kochala lo revisará lo antes posible.',
              style: TextStyle(color: Color(0xff668080), fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              maxLines: 6,
              decoration: InputDecoration(
                hintText: 'Escribe tu mensaje aquí...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xffe1e9e6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xffe1e9e6)),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isLoading ? null : _submitTicket,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.teal,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Enviar Mensaje', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}