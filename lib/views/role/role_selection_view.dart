import 'package:flutter/material.dart';
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
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.teal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_circle, color: AppTheme.teal, size: 50),
                  ),
                  const SizedBox(height: 24),
                  const Text('¡Hola de nuevo!', style: TextStyle(fontSize: 22, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(email, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.ink), textAlign: TextAlign.center),
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
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(
                        color: AppTheme.teal, shape: BoxShape.circle),
                    child: const Icon(Icons.location_city,
                        color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text('Radar Kochala',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.ink)),
                  const SizedBox(height: 6),
                  const Text('Inicia sesión para continuar',
                      style: TextStyle(color: Color(0xff78908d))),
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
                      height: 50,
                      child: FilledButton(
                        onPressed: _signIn,
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.teal,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        child: const Text('Iniciar sesión',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterView()),
                        ),
                        style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.teal),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        child: const Text('Crear cuenta',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.teal)),
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
