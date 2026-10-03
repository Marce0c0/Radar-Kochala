import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// AppTheme — Design System v2.0
/// Inspired by the Best-Flutter-UI-Templates design language:
/// clean cards, rounded corners (20-24px), subtle shadows, Inter typography.
class AppTheme {
  AppTheme._();

  // Brand Colors
  static const Color ink = Color(0xff122b27);
  static const Color teal = Color(0xff0eb6c2);
  static const Color tealDeep = Color(0xff0a9aa5);
  static const Color tealSoft = Color(0xffe0f7f9);

  // Neutral Palette
  static const Color nearlyWhite = Color(0xfffefefe);
  static const Color surface = Color(0xfff4f8f6);
  static const Color cardBg = Color(0xffffffff);
  static const Color borderLight = Color(0xffe1e9e6);
  static const Color dividerColor = Color(0xffedf2f0);

  // Text Colors
  static const Color textPrimary = Color(0xff122b27);
  static const Color textSecondary = Color(0xff4a6572);
  static const Color textMuted = Color(0xff78908d);
  static const Color textHint = Color(0xffa3b8b5);

  // Semantic Colors
  static const Color danger = Color(0xffd9684b);
  static const Color success = Color(0xff28a87a);
  static const Color warning = Color(0xfff5a623);
  static const Color info = Color(0xff3e9dff);

  // Shadows
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xff122b27).withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xff122b27).withValues(alpha: 0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xff122b27).withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get floatShadow => [
    BoxShadow(
      color: teal.withValues(alpha: 0.28),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  // Border Radius
  static const double radiusXS = 8.0;
  static const double radiusSM = 12.0;
  static const double radiusMD = 16.0;
  static const double radiusLG = 20.0;
  static const double radiusXL = 24.0;

  // Typography helpers
  static TextStyle headline1() => GoogleFonts.inter(
    fontSize: 28, fontWeight: FontWeight.w800, color: textPrimary, height: 1.2,
  );
  static TextStyle headline2() => GoogleFonts.inter(
    fontSize: 22, fontWeight: FontWeight.w700, color: textPrimary, height: 1.3,
  );
  static TextStyle headline3() => GoogleFonts.inter(
    fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary, height: 1.4,
  );
  static TextStyle body1() => GoogleFonts.inter(
    fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary, height: 1.5,
  );
  static TextStyle body2() => GoogleFonts.inter(
    fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary, height: 1.5,
  );
  static TextStyle caption() => GoogleFonts.inter(
    fontSize: 11, fontWeight: FontWeight.w500, color: textMuted, height: 1.4,
    letterSpacing: 0.3,
  );
  static TextStyle label() => GoogleFonts.inter(
    fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary, height: 1.4,
    letterSpacing: 0.2,
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: teal,
      primary: teal,
      onPrimary: Colors.white,
      secondary: tealDeep,
      surface: surface,
      onSurface: textPrimary,
      error: danger,
    ),
    scaffoldBackgroundColor: surface,
    fontFamily: GoogleFonts.inter().fontFamily,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
      fontFamily: GoogleFonts.inter().fontFamily,
    ),

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: textPrimary,
        letterSpacing: -0.3,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    ),

    // Card
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardBg,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLG),
        side: const BorderSide(color: borderLight, width: 1),
      ),
    ),

    // ElevatedButton
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        minimumSize: const Size(double.infinity, 52),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // FilledButton
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: teal,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        minimumSize: const Size(double.infinity, 52),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    // OutlinedButton
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: teal,
        side: const BorderSide(color: teal, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        minimumSize: const Size(double.infinity, 52),
        textStyle: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // TextButton
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: teal,
        textStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    // Input
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: teal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMD),
        borderSide: const BorderSide(color: danger, width: 2),
      ),
      hintStyle: GoogleFonts.inter(
        fontSize: 14,
        color: textHint,
        fontWeight: FontWeight.w400,
      ),
      labelStyle: GoogleFonts.inter(
        fontSize: 14,
        color: textSecondary,
        fontWeight: FontWeight.w500,
      ),
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: cardBg,
      selectedColor: tealSoft,
      checkmarkColor: teal,
      labelStyle: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSM),
        side: const BorderSide(color: borderLight),
      ),
      elevation: 0,
      pressElevation: 0,
    ),

    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: teal,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),

    // NavigationBar
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardBg,
      indicatorColor: tealSoft,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: teal, size: 22);
        }
        return const IconThemeData(color: textMuted, size: 22);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w700, color: teal,
          );
        }
        return GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w500, color: textMuted,
        );
      }),
      elevation: 8,
      shadowColor: const Color(0xff122b27),
      surfaceTintColor: Colors.transparent,
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: dividerColor,
      thickness: 1,
      space: 1,
    ),

    // SnackBar
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: textPrimary,
      contentTextStyle: GoogleFonts.inter(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSM),
      ),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: cardBg,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusXL),
      ),
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      contentTextStyle: GoogleFonts.inter(
        fontSize: 14,
        color: textSecondary,
        height: 1.6,
      ),
    ),

    // ListTile
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSM),
      ),
      tileColor: Colors.transparent,
    ),
  );
}
