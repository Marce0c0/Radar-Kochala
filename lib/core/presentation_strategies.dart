import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';

// STRATEGY: centraliza la lógica de presentación por categoría en un único lugar.
// Cualquier widget que necesite icono o color de categoría usa estas funciones
// en lugar de duplicar el switch en cada archivo.
IconData categoryIcon(ReportCategory c) => switch (c) {
      ReportCategory.pothole => Icons.warning_amber_rounded,
      ReportCategory.waste => Icons.delete_outline,
      ReportCategory.lighting => Icons.lightbulb_outline,
      ReportCategory.publicSpace => Icons.park_outlined,
      ReportCategory.waterLeak => Icons.water_drop_outlined,
      ReportCategory.trafficLight => Icons.traffic_outlined,
      ReportCategory.vandalism => Icons.format_paint_outlined,
    };

// STRATEGY: estrategia de color por categoría, reutilizable en toda la app.
Color categoryColor(ReportCategory c) => switch (c) {
      ReportCategory.pothole => const Color(0xffd9684b),
      ReportCategory.waste => const Color(0xff718d43),
      ReportCategory.lighting => const Color(0xffd99a3d),
      ReportCategory.publicSpace => AppTheme.teal,
      ReportCategory.waterLeak => Colors.blue,
      ReportCategory.trafficLight => Colors.redAccent,
      ReportCategory.vandalism => Colors.purple,
    };

// STRATEGY: color por estado del reporte.
Color statusColor(ReportStatus s) => switch (s) {
      ReportStatus.reported => const Color(0xff6c7c88),
      ReportStatus.reviewing => const Color(0xffd99a3d),
      ReportStatus.inProgress => const Color(0xff0eb6c2),
      ReportStatus.resolved => const Color(0xff5b954b),
    };
