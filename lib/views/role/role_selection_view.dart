import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../auth/register_view.dart';
import '../home/home_view.dart';
import '../staff/admin_dashboard_view.dart';
import '../staff/staff_hub_view.dart';
import '../staff/field_worker_view.dart';

class RoleSelectionView extends StatefulWidget {
  const RoleSelectionView({super.key});

  @override
  State<RoleSelectionView> createState() => _RoleSelectionViewState();
}

class _RoleSelectionViewState extends State<RoleSelectionView> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  Session? _activeSession;

  @override
  void initState() {
    super.initState();
    // Verificamos si hay una sesión guardada de forma sincrónica.
    _activeSession = Supabase.instance.client.auth.currentSession;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _routeUserById(String userId) async {
    setState(() => _isLoading = true);
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      final role = profile?['role'] as String?;

      switch (role) {
        case 'operador':
          _open(const StaffHubView(initialSection: 0));
        case 'trabajador':
          _open(const FieldWorkerView());
        case 'admin':
        case 'superadmin':
          _open(const AdminDashboardView());
        case 'desactivado':
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            setState(() {
              _activeSession = null;
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tu cuenta ha sido desactivada y archivada.'),
                backgroundColor: Colors.red,
              )
            );
          }
          return;
        default:
          // ciudadano o rol no reconocido → HomeView
          _open(const HomeView());
      }
    } catch (e) {
      debugPrint('Error al obtener perfil: $e');
      if (mounted) _open(const HomeView());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _open(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _signIn() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text.trim();

    // CORRECCIÓN #3: Validación básica antes de llamar a Supabase.
    if (email.isEmpty || !email.contains('@')) {
      _showError('Ingresa un correo electrónico válido.');
      return;
    }
    if (password.length < 6) {
      _showError('La contraseña debe tener al menos 6 caracteres.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      // CORRECCIÓN #4: Solo intentamos login. Ya NO auto-registramos al usuario
      // si las credenciales fallan — evita que cualquiera cree cuentas de staff.
      final res = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      if (res.user != null) await _routeUserById(res.user!.id);
    } on AuthException catch (e) {
      _showError(_authErrorMessage(e.message));
    } catch (e) {
      _showError('Error inesperado de conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  // Traduce mensajes de error de Supabase (en inglés) al español.
  String _authErrorMessage(String msg) {
    if (msg.contains('Invalid login credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (msg.contains('Email not confirmed')) {
      return 'Revisa tu correo para confirmar la cuenta.';
    }
    if (msg.contains('already registered')) {
      return 'Este correo ya está registrado. Intenta iniciar sesión.';
    }
    if (msg.contains('Password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return msg;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xffd9684b),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si hay una sesión activa, mostramos una pantalla de bienvenida para continuar
    if (_activeSession != null) {
      final email = _activeSession!.user.email ?? 'Usuario';
      final displayName = email.isNotEmpty ? email.split('@').first.replaceAll('.', ' ').replaceAll('_', ' ').split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ') : 'Usuario';
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 100, child: Center(child: Image.asset('assets/logo_cochabamba.png', height: 100, fit: BoxFit.contain))),
                  const SizedBox(height: 24),
                  const Text('¡Hola de nuevo!', style: TextStyle(fontSize: 22, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(displayName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTheme.teal), textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(email, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  if (_isLoading)
                    const CircularProgressIndicator(color: AppTheme.teal)
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () => _routeUserById(_activeSession!.user.id),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.teal,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.login),
                        label: const Text('Continuar sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () async {
                        setState(() => _isLoading = true);
                        await Supabase.instance.client.auth.signOut();
                        if (mounted) {
                          setState(() {
                            _activeSession = null;
                            _isLoading = false;
                          });
                        }
                      },
                      child: const Text('Ingresar con otra cuenta', style: TextStyle(color: Colors.grey)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Flujo normal de login
    return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 120, child: Center(child: Image.asset('assets/logo_cochabamba.png', height: 120, fit: BoxFit.contain))),
                  const SizedBox(height: 16),
                  Text(
                    'Radar Kochala',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Inicia sesión para continuar',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 35),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'tu@correo.com',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_isLoading)
                    const CircularProgressIndicator(color: AppTheme.teal)
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _signIn,
                        child: Text(
                          'Iniciar sesión',
                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterView()),
                        ),
                        child: Text(
                          'Crear cuenta',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.teal,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => _open(const HomeView()),
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Explorar como invitado (solo ver)'),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      );
  }
}
