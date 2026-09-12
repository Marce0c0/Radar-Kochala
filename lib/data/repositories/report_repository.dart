import '../models/report.dart';

abstract class ReportRepository {
  Future<List<Report>> fetchReports();
  Future<Report> createReport(ReportDraft draft);
}

class MockReportRepository implements ReportRepository {
  final List<Report> _reports = [...reportsSeed];

  @override
  Future<List<Report>> fetchReports() async => List.unmodifiable(_reports);

  @override
  Future<Report> createReport(ReportDraft draft) async {
    final report = Report(
      id: 'local-${_reports.length + 1}',
      title: '${categoryName(draft.category)} reportado en Cochabamba',
      category: draft.category,
      status: ReportStatus.reported,
      neighborhood: 'Cochabamba Centro',
      time: 'Ahora',
      severity: 'Media',
      description: draft.description,
      latitude: draft.latitude,
      longitude: draft.longitude,
      isMine: true,
    );
    _reports.insert(0, report);
    return report;
  }
}

class SupabaseReportRepository implements ReportRepository {
  @override
  Future<List<Report>> fetchReports() async =>
      throw UnimplementedError('Conectar aquí el cliente Supabase.');

  @override
  Future<Report> createReport(ReportDraft draft) async =>
      throw UnimplementedError('Conectar aquí el cliente Supabase.');
}
