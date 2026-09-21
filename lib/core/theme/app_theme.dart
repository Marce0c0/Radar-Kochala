import 'package:flutter/material.dart';

// SINGLETON: AppTheme expone una única instancia del tema a través de
// un getter estático. No se puede instanciar; todos acceden al mismo objeto.
class AppTheme {
  AppTheme._(); // Constructor privado — impide instanciación externa.

  static const Color ink = Color(0xff122b27);
  static const Color teal = Color(0xff0eb6c2);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: teal,
          primary: teal,
          surface: const Color(0xfff4f8f6),
        ),
        scaffoldBackgroundColor: const Color(0xfff8fbf9),
        fontFamily: 'Roboto',
      );
}
