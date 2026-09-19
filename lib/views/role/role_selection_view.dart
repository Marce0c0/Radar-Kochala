import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../home/home_view.dart';
import '../staff/staff_views.dart';

class RoleSelectionView extends StatefulWidget {
  const RoleSelectionView({super.key});

  @override
  State<RoleSelectionView> createState() => _RoleSelectionViewState();
}

class _RoleSelectionViewState extends State<RoleSelectionView> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController(text: 'admin123');
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Bloque protegido para verificar sesión activa
      try {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null && session.user.email != null) {
          _routeUser(session.user.email!);
        }
      } catch (e) {
        debugPrint('Error al verificar sesión inicial: $e');
      }
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _routeUser(String email) {
    if (email.startsWith('operador@')) {
      _open(const StaffHubView(initialSection: 0));
    } else if (email.startsWith('trabajador@')) {
      _open(const FieldWorkerView());
    } else if (email.startsWith('admin@') || email.startsWith('superadmin@')) {
      _open(const StaffHubView(initialSection: 3));
    } else {
      _open(const HomeView());
    }
  }

  void _open(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _signInOrSignUp() async {
    if (_emailCtrl.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text.trim();

    try {
      // 1. Intentar iniciar sesión
      final res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);
      if (res.user != null) _routeUser(res.user!.email!);
    } on AuthException catch (_) {
      // 2. Si falla (credenciales inválidas o no existe), intentar registrar
      try {
        final res = await Supabase.instance.client.auth.signUp(email: email, password: password);
        if (res.user != null) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cuenta registrada en la nube.')));
          _routeUser(res.user!.email!);
        }
      } on AuthException catch (signUpError) {
        // Muestra el error exacto de Supabase (ej. "Password should be at least 6 characters")
        _showError(signUpError.message);
      } catch (e) {
        _showError('Error al registrar. Revisa tu conexión.');
      }
    } catch (e) {
      _showError('Error inesperado de conexión.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: const Color(0xffd9684b)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: const BoxDecoration(color: AppTheme.teal, shape: BoxShape.circle),
                    child: const Icon(Icons.location_city, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text('Cochabamba Reporta', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.ink)),
                  const SizedBox(height: 6),
                  const Text('Inicia sesión para continuar', style: TextStyle(color: Color(0xff78908d))),
                  const SizedBox(height: 35),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'ej. operador@alcaldia.cbba',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signInOrSignUp(),
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
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
                        onPressed: _signInOrSignUp,
                        style: FilledButton.styleFrom(backgroundColor: AppTheme.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => _open(const HomeView()),
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Entrar como Invitado (Solo ver)'),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ),
      );
}