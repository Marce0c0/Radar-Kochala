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
    this.isMine = false,
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
  final bool isMine;

  // FACTORY METHOD: centraliza la deserialización desde Supabase,
  // evitando que el Repository construya el objeto manualmente.
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
      isMine: currentUserId != null && currentUserId == data['author_id'],
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

// BUILDER: permite construir un ReportDraft paso a paso,
// útil cuando los campos se recopilan en distintas pantallas/pasos.
class ReportDraftBuilder {
  ReportCategory _category = ReportCategory.pothole;
  String _description = '';
  String _severity = 'Media';
  double? _latitude;
  double? _longitude;
  String? _imageUrl;
  List<int>? _imageBytes;

  ReportDraftBuilder category(ReportCategory c) {
    _category = c;
    return this;
  }

  ReportDraftBuilder description(String d) {
    _description = d;
    return this;
  }

  ReportDraftBuilder severity(String s) {
    _severity = s;
    return this;
  }

  ReportDraftBuilder location(double lat, double lng) {
    _latitude = lat;
    _longitude = lng;
    return this;
  }

  ReportDraftBuilder image(String? url) {
    _imageUrl = url;
    return this;
  }

  // Builder para bytes (soporte Flutter Web, donde dart:io no existe).
  ReportDraftBuilder imageBytes(List<int>? bytes) {
    _imageBytes = bytes;
    return this;
  }

  ReportDraft build() {
    assert(_description.isNotEmpty, 'La descripción no puede estar vacía');
    return ReportDraft(
      category: _category,
      description: _description,
      severity: _severity,
      latitude: _latitude,
      longitude: _longitude,
      imageUrl: _imageUrl,
      imageBytes: _imageBytes,
    );
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