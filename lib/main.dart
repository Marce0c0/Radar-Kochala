import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/theme/app_theme.dart';
import 'controllers/report_controller.dart'; 
import 'views/role/role_selection_view.dart';
import 'views/home/home_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SplashApp());
}

class SplashApp extends StatefulWidget {
  const SplashApp({super.key});

  @override
  State<SplashApp> createState() => _SplashAppState();
}

class _SplashAppState extends State<SplashApp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _initializeApp();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Pre-cache the image so it loads instantly in subsequent screens
    precacheImage(const AssetImage('assets/logo_cochabamba.png'), context);
  }

  Future<void> _initializeApp() async {
    try {
      await dotenv.load(fileName: "env.txt");
      await Supabase.initialize(
        url: dotenv.env['SUPABASE_URL'] ?? '',
        publishableKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
      );
      // Esperar a que la fuente global de Google Fonts cargue antes de quitar el splash
      await GoogleFonts.pendingFonts([
        GoogleFonts.inter(),
      ]);
      // Min delay so the user can enjoy the splash animation
      await Future.delayed(const Duration(milliseconds: 2000));
    } catch (e) {
      debugPrint("Initialization error: $e");
    }
    
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialized) {
      return ChangeNotifierProvider(
        create: (_) => ReportController()..load(),
        child: const BachesCochaApp(),
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xfff4f8f6), // AppTheme.surface
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _animation,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    'assets/logo_cochabamba.png',
                    height: 140,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'RADAR KOCHALA',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xff122b27), // AppTheme.ink
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 25),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff0eb6c2)),
              ),
              const SizedBox(height: 15),
              const Text(
                'Iniciando sistema...',
                style: TextStyle(
                  color: Color(0xff668080),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
      builder: (context, child) {
        return StreamBuilder<List<ConnectivityResult>>(
          stream: Connectivity().onConnectivityChanged,
          builder: (context, snapshot) {
            // Evaluamos si el último dato del stream indica falta de red
            final isOffline = snapshot.hasData && 
                snapshot.data!.contains(ConnectivityResult.none);
                
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  if (isOffline)
                    Material(
                      color: const Color(0xffd9684b), // Rojo suave para offline
                      child: const SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.wifi_off, color: Colors.white, size: 14),
                                SizedBox(width: 8),
                                Text(
                                  'Modo Offline - Funciones limitadas',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white, 
                                    fontSize: 12, 
                                    fontWeight: FontWeight.bold
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Expanded(child: child ?? const SizedBox.shrink()),
                ],
              ),
            );
          },
        );
      },
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
