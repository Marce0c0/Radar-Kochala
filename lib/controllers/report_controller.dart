import 'package:flutter/foundation.dart';
import '../data/models/report.dart';
import '../data/repositories/report_repository.dart';

class ReportController extends ChangeNotifier {
  ReportController({ReportRepository? repository})
      : _repository = repository ?? MockReportRepository();

  final ReportRepository _repository;
  List<Report> reports = [];
  ReportCategory? filter;
  bool loading = true;
  String? error;

  List<Report> get visibleReports => filter == null
      ? reports
      : reports.where((r) => r.category == filter).toList();

  ReportStatistics get statistics =>
      ReportStatistics(reports.length + 1248, resolvedCount(reports) + 849);

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      reports = await _repository.fetchReports();
      error = null;
    } catch (_) {
      error = 'No se pudieron cargar los reportes';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void setFilter(ReportCategory? value) {
    filter = value;
    notifyListeners();
  }

  Future<Report> create(ReportDraft draft) async {
    final created = await _repository.createReport(draft);
    reports = [created, ...reports];
    notifyListeners();
    return created;
  }
}