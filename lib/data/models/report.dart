enum ReportCategory { pothole, waste, lighting, publicSpace }
enum ReportStatus { reported, reviewing, inProgress, resolved }

String categoryName(ReportCategory c) => switch (c) {
      ReportCategory.pothole => 'Bache',
      ReportCategory.waste => 'Basura acumulada',
      ReportCategory.lighting => 'Alumbrado público',
      ReportCategory.publicSpace => 'Espacio público',
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
  final bool isMine;

  String? get imageUrl => null;
}

class ReportDraft {
  const ReportDraft({
    required this.category,
    required this.description,
    this.latitude,
    this.longitude,
  });

  final ReportCategory category;
  final String description;
  final double? latitude;
  final double? longitude;
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

  String get resolutionRate => total == 0 ? '0%' : '${((resolved / total) * 100).toStringAsFixed(0)}%';
}

int resolvedCount(List<Report> list) => list.where((r) => r.status == ReportStatus.resolved).length;

final List<Report> reportsSeed = [
  const Report(
    id: '1',
    title: 'Bache grande en la Av. Ballivián',
    category: ReportCategory.pothole,
    status: ReportStatus.inProgress,
    neighborhood: 'El Prado',
    time: 'Hace 2 horas',
    severity: 'Alta',
    description: 'Bache peligroso cerca de la rotonda principal que afecta a los vehículos.',
    latitude: -17.3895,
    longitude: -66.1568,
  ),
  const Report(
    id: '2',
    title: 'Acumulación de residuos en esquina',
    category: ReportCategory.waste,
    status: ReportStatus.reported,
    neighborhood: 'Recoleta',
    time: 'Hace 5 horas',
    severity: 'Media',
    description: 'Bolsas de basura rotas dejadas fuera del contenedor asignado.',
    latitude: -17.3820,
    longitude: -66.1500,
  ),
];

List<ReportUpdate> updatesFor(Report report) => [
      const ReportUpdate(title: 'Reporte recibido', note: 'Registrado en el sistema municipal.', completed: true),
      ReportUpdate(
        title: 'En revisión',
        note: 'Asignado al área de mantenimiento.',
        completed: report.status != ReportStatus.reported,
      ),
      ReportUpdate(
        title: 'Solución en curso',
        note: 'Cuadrilla trabajando en el lugar.',
        completed: report.status == ReportStatus.inProgress || report.status == ReportStatus.resolved,
      ),
    ];