import 'package:flutter/material.dart';

enum ReportCategory {
  pothole,
  waste,
  lighting,
  publicSpace,
  waterLeak,
  trafficLight,
  vandalism
}

enum ReportStatus { reported, reviewing, inProgress, resolved }

String categoryName(ReportCategory c) => switch (c) {
      ReportCategory.pothole => 'Bache',
      ReportCategory.waste => 'Basura acumulada',
      ReportCategory.lighting => 'Alumbrado público',
      ReportCategory.publicSpace => 'Espacio público',
      ReportCategory.waterLeak => 'Fuga de agua',
      ReportCategory.trafficLight => 'Semáforo dañado',
      ReportCategory.vandalism => 'Vandalismo',
    };

String statusName(ReportStatus s) => switch (s) {
      ReportStatus.reported => 'Reportado',
      ReportStatus.reviewing => 'En revisión',
      ReportStatus.inProgress => 'En proceso',
      ReportStatus.resolved => 'Resuelto',
    };

IconData categoryIcon(ReportCategory c) => switch (c) {
      ReportCategory.pothole => Icons.warning_amber_rounded,
      ReportCategory.waste => Icons.delete_outline,
      ReportCategory.lighting => Icons.lightbulb_outline,
      ReportCategory.publicSpace => Icons.park_outlined,
      ReportCategory.waterLeak => Icons.water_drop_outlined,
      ReportCategory.trafficLight => Icons.traffic_outlined,
      ReportCategory.vandalism => Icons.format_paint_outlined,
    };

Color categoryColor(ReportCategory c) => switch (c) {
      ReportCategory.pothole => const Color(0xffd9684b),
      ReportCategory.waste => const Color(0xff718d43),
      ReportCategory.lighting => const Color(0xffd99a3d),
      ReportCategory.publicSpace => const Color(0xff0eb6c2),
      ReportCategory.waterLeak => Colors.blue,
      ReportCategory.trafficLight => Colors.redAccent,
      ReportCategory.vandalism => Colors.purple,
    };

Color statusColor(ReportStatus s) => switch (s) {
      ReportStatus.reported => const Color(0xff6c7c88),
      ReportStatus.reviewing => const Color(0xffd99a3d),
      ReportStatus.inProgress => const Color(0xff0eb6c2),
      ReportStatus.resolved => const Color(0xff5b954b),
    };

class Report {
  const Report({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.neighborhood,
    required this.time,
    required this.severity,
    required this.description,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.authorId,
    this.isMine = false,
    this.isAiVerified = false,
  });

  final String id;
  final String title;
  final ReportCategory category;
  final ReportStatus status;
  final String neighborhood;
  final String time;
  final String severity;
  final String description;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? authorId;
  final bool isMine;
  final bool isAiVerified;

  factory Report.fromMap(Map<String, dynamic> data, {String? currentUserId}) {
    // Calcula el tiempo relativo desde created_at real de la BD.
    final createdAt = data['created_at'] != null
        ? DateTime.tryParse(data['created_at'].toString())?.toLocal()
        : null;
    final timeLabel = _relativeTime(createdAt);

    return Report(
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? 'Sin título',
      category: ReportCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => ReportCategory.pothole,
      ),
      status: ReportStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ReportStatus.reported,
      ),
      neighborhood: _neighborhoodFromData(data),
      time: timeLabel,
      severity: data['severity']?.toString() ?? 'Media',
      description: data['description'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      imageUrl: data['image_url'] as String?,
      authorId: data['author_id'] as String?,
      isMine: currentUserId != null && currentUserId == data['author_id'],
      isAiVerified: data['is_ai_verified'] == true,
    );
  }

  // Calcula la etiqueta de tiempo relativo.
  static String _relativeTime(DateTime? dt) {
    if (dt == null) return 'Reciente';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    if (diff.inDays < 30) return 'Hace ${diff.inDays ~/ 7} semanas';
    return 'Hace ${diff.inDays ~/ 30} meses';
  }

  /// Deriva una etiqueta de zona desde coordenadas reales.
  /// Sin geocoding: muestra las coordenadas formateadas.
  static String _neighborhoodFromData(Map<String, dynamic> data) {
    final lat = data['latitude'] as num?;
    final lng = data['longitude'] as num?;
    if (lat != null && lng != null) {
      return 'Cbba (${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)})';
    }
    return 'Zona urbana, Cochabamba';
  }

}



class ReportDraft {
  const ReportDraft({
    required this.category,
    required this.description,
    this.severity = 'Media',
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.imageBytes,
    this.isAiVerified = false,
  });

  final ReportCategory category;
  final String description;
  final String severity;
  final double? latitude;
  final double? longitude;
  /// Ruta de archivo (móvil/desktop). Null en web.
  final String? imageUrl;
  /// Bytes de la imagen (web). Null en móvil/desktop.
  final List<int>? imageBytes;
  final bool isAiVerified;

  Map<String, dynamic> toJson() {
    return {
      'category': category.name,
      'description': description,
      'severity': severity,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'isAiVerified': isAiVerified,
      // No guardamos imageBytes en JSON porque es muy pesado y la cola offline 
      // está pensada principalmente para móvil (donde usamos imageUrl/filePath).
    };
  }

  factory ReportDraft.fromJson(Map<String, dynamic> map) {
    return ReportDraft(
      category: ReportCategory.values.firstWhere(
        (e) => e.name == map['category'],
        orElse: () => ReportCategory.pothole,
      ),
      description: map['description'] ?? '',
      severity: map['severity'] ?? 'Media',
      latitude: map['latitude'] as double?,
      longitude: map['longitude'] as double?,
      imageUrl: map['imageUrl'] as String?,
      isAiVerified: map['isAiVerified'] == true,
    );
  }

  ReportDraft copyWith({
    ReportCategory? category,
    String? description,
    String? severity,
    double? latitude,
    double? longitude,
    String? imageUrl,
    List<int>? imageBytes,
    bool? isAiVerified,
  }) {
    return ReportDraft(
      category: category ?? this.category,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      imageBytes: imageBytes ?? this.imageBytes,
      isAiVerified: isAiVerified ?? this.isAiVerified,
    );
  }
}

class ReportUpdate {
  const ReportUpdate({
    required this.title,
    required this.note,
    required this.completed,
  });
  final String title;
  final String note;
  final bool completed;
}

class ReportStatistics {
  const ReportStatistics(this.total, this.resolved);
  final int total;
  final int resolved;

  String get resolutionRate =>
      total == 0 ? '0%' : '${((resolved / total) * 100).toStringAsFixed(0)}%';
}

int resolvedCount(List<Report> list) =>
    list.where((r) => r.status == ReportStatus.resolved).length;

List<ReportUpdate> updatesFor(Report report) => [
      const ReportUpdate(
        title: 'Reporte recibido',
        note: 'Registrado en el sistema municipal.',
        completed: true,
      ),
      ReportUpdate(
        title: 'En revisión',
        note: 'Asignado al área de mantenimiento.',
        completed: report.status != ReportStatus.reported,
      ),
      ReportUpdate(
        title: 'Solución en curso',
        note: 'Cuadrilla trabajando en el lugar.',
        completed: report.status == ReportStatus.inProgress ||
            report.status == ReportStatus.resolved,
      ),
    ];