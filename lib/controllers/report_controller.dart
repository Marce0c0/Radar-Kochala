import 'package:flutter/foundation.dart';
import '../data/models/report.dart';
import '../data/repositories/report_repository.dart';

// OBSERVER: ReportController extiende ChangeNotifier, implementando el patrón
// Observer. Las vistas se suscriben con context.watch() y se redibujan
// automáticamente cuando se llama notifyListeners().
//
// FACADE: actúa como fachada que simplifica el acceso al subsistema de datos
// (Repository), exponiendo solo las operaciones que las vistas necesitan.
class ReportController extends ChangeNotifier {
  ReportController({ReportRepository? repository})
      : _repository = repository ?? SupabaseReportRepository();

  final ReportRepository _repository;
  List<Report> reports = [];
  ReportCategory? filter;
  bool loading = true;
  String? error;

  List<Report> get visibleReports => filter == null
      ? reports
      : reports.where((r) => r.category == filter).toList();

  // CORRECCIÓN #14: estadísticas reales, sin números inventados.
  ReportStatistics get statistics =>
      ReportStatistics(reports.length, resolvedCount(reports));


  // OBSERVER: notifica a todos los widgets suscritos tras cada operación.
  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      reports = await _repository.fetchReports();
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

  Future<void> updateStatus(String reportId, ReportStatus newStatus) async {
    try {
      await _repository.updateReportStatus(reportId, newStatus);
      await load();
    } catch (e) {
      debugPrint('Error al actualizar: $e');
    }
  }
}