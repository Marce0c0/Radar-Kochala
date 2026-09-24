import 'package:flutter/foundation.dart';
import '../data/models/report.dart';
import '../data/repositories/report_repository.dart';

class ReportController extends ChangeNotifier {
  ReportController({ReportRepository? repository})
      : _repository = repository ?? ReportRepository();

  final ReportRepository _repository;
  List<Report> reports = [];
  ReportCategory? filter;
  bool hideResolved = false;
  bool loading = true;
  String? error;
  
  bool loadingMore = false;
  bool hasMore = true;
  int _offset = 0;
  static const int _limit = 20;

  List<Report> get visibleReports {
    var filtered = reports;
    if (filter != null) {
      filtered = filtered.where((r) => r.category == filter).toList();
    }
    if (hideResolved) {
      filtered = filtered.where((r) => r.status != ReportStatus.resolved).toList();
    }
    return filtered;
  }

  // CORRECCIÓN #14: estadísticas reales, sin números inventados.
  ReportStatistics get statistics =>
      ReportStatistics(reports.length, resolvedCount(reports));


  Future<void> load() async {
    loading = true;
    error = null;
    _offset = 0;
    hasMore = true;
    notifyListeners();
    try {
      await _repository.syncQueue();
      reports = await _repository.fetchReports(limit: _limit, offset: _offset);
      if (reports.length < _limit) hasMore = false;
    } catch (_) {
      error = 'No se pudieron cargar los reportes';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (loadingMore || !hasMore) return;
    loadingMore = true;
    notifyListeners();
    try {
      _offset += _limit;
      final newReports = await _repository.fetchReports(limit: _limit, offset: _offset);
      if (newReports.length < _limit) hasMore = false;
      reports.addAll(newReports);
    } catch (_) {
      debugPrint('Error loading more reports');
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  void setFilter(ReportCategory? value) {
    filter = value;
    notifyListeners();
  }

  void setHideResolved(bool value) {
    hideResolved = value;
    notifyListeners();
  }

  Future<Report?> create(ReportDraft draft) async {
    try {
      final created = await _repository.createReport(draft);
      reports = [created, ...reports];
      notifyListeners();
      return created;
    } catch (e) {
      debugPrint('Error creando reporte (posiblemente offline): $e');
      await _repository.saveDraftToQueue(draft);
      return null;
    }
  }

  Future<void> updateStatus(String reportId, ReportStatus newStatus) async {
    try {
      await _repository.updateReportStatus(reportId, newStatus);
      await load();
    } catch (e) {
      debugPrint('Error al actualizar: $e');
    }
  }

  Future<void> deleteReport(String reportId) async {
    try {
      await _repository.deleteReport(reportId);
      reports.removeWhere((r) => r.id == reportId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error al eliminar: $e');
      rethrow;
    }
  }

  Future<void> resolveReport(Report report, List<int> imageBytes, String imageExtension) async {
    try {
      await _repository.resolveReport(report, imageBytes, imageExtension);
      await load(); // Reload to get updated report details (like resolved_image_url)
    } catch (e) {
      debugPrint('Error al resolver reporte: $e');
      rethrow;
    }
  }
}