import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'controllers/report_controller.dart'; 
import 'views/role/role_selection_view.dart';
import 'views/home/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(
    // Envolvemos la app en el Provider
    ChangeNotifierProvider(
      create: (_) => ReportController()..load(), // Inicializamos y cargamos los reportes aquí
      child: const BachesCochaApp(),
    ),
  );
}

class BachesCochaApp extends StatelessWidget {
  const BachesCochaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Radar Kochala',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const RoleSelectionView(),
    );
  }
}

/// Pantalla de Bienvenida con Animación Profesional
class WelcomeView extends StatefulWidget {
  const WelcomeView({super.key});

  @override
  State<WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends State<WelcomeView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3), // Empieza desplazado hacia abajo
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _controller.forward(); // Dispara la animación al cargar
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  // Icono o Logotipo Animado con un contenedor bonito
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: const Color(0xffd8eeea),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.teal.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_city_rounded,
                        size: 70,
                        color: AppTheme.teal,
                      ),
                    ),
                  ),
                  const SizedBox(height: 35),
                  // Título Principal
                  const Text(
                    'RADAR KOCHALA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Subtítulo descriptivo
                  const Text(
                    'Ayúdanos a mejorar las calles de Cochabamba.\nReporta baches y daños urbanos de forma rápida y sencilla.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xff668080),
                      height: 1.5,
                    ),
                  ),
                  const Spacer(),
                  // Botón para entrar al Home
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  const HomeView(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                                opacity: animation, child: child);
                          },
                          transitionDuration: const Duration(milliseconds: 500),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.teal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 2,
                    ),
                    icon: const Text(
                      'Comenzar',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    label: const Icon(Icons.arrow_forward_rounded, size: 22),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
