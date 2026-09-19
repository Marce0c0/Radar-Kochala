enum ReportCategory { pothole, waste, lighting, publicSpace, waterLeak, trafficLight, vandalism }

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
}

class ReportDraft {
  const ReportDraft({
    required this.category,
    required this.description,
    this.latitude,
    this.longitude,
    this.imageUrl,
  });

  final ReportCategory category;
  final String description;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
}

class ReportUpdate {
  const ReportUpdate({required this.title, required this.note, required this.completed});
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
      const ReportUpdate(title: 'Reporte recibido', note: 'Registrado en el sistema municipal.', completed: true),
      ReportUpdate(title: 'En revisión', note: 'Asignado al área de mantenimiento.', completed: report.status != ReportStatus.reported),
      ReportUpdate(title: 'Solución en curso', note: 'Cuadrilla trabajando en el lugar.', completed: report.status == ReportStatus.inProgress || report.status == ReportStatus.resolved),
    ];