import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../data/models/report.dart';
import '../data/repositories/report_repository.dart';
import '../services/offline_sync_service.dart';

enum ExploreFilterMode { recientes, urgentes, populares, resueltos }

class ReportController extends ChangeNotifier {
  ReportController({ReportRepository? repository})
      : _repository = repository ?? ReportRepository() {
    _initConnectivityListener();
  }

  final ReportRepository _repository;
  List<Report> reports = [];
  List<ReportDraft> pendingDrafts = [];
  ReportCategory? filter;
  ExploreFilterMode exploreMode = ExploreFilterMode.recientes;
  bool hideResolved = true;
  bool loading = true;
  String? error;
  
  bool loadingMore = false;
  bool hasMore = true;
  int _offset = 0;
  static const int _limit = 5;

  StreamSubscription? _connectivitySubscription;
  bool _wasOffline = false;

  void _initConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final isOffline = result.contains(ConnectivityResult.none);
      if (_wasOffline && !isOffline) {
        debugPrint('Conexión recuperada. Recargando y sincronizando...');
        load();
      }
      _wasOffline = isOffline;
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  List<Report> get visibleReports {
    var filtered = reports.toList();
    if (filter != null) {
      filtered = filtered.where((r) => r.category == filter).toList();
    }
    
    if (exploreMode == ExploreFilterMode.resueltos) {
      filtered = filtered.where((r) => r.status == ReportStatus.resolved).toList();
    } else {
      if (hideResolved) {
        filtered = filtered.where((r) => r.status != ReportStatus.resolved).toList();
      }
      
      switch (exploreMode) {
        case ExploreFilterMode.urgentes:
          filtered = filtered.where((r) => r.severity == 'Alta').toList();
          filtered.sort((a, b) {
            final cmp = b.upvotes.compareTo(a.upvotes);
            if (cmp == 0) {
               final aDate = a.createdAt ?? DateTime.now();
               final bDate = b.createdAt ?? DateTime.now();
               return bDate.compareTo(aDate);
            }
            return cmp;
          });
          break;
        case ExploreFilterMode.populares:
          filtered.sort((a, b) {
            final cmp = b.upvotes.compareTo(a.upvotes);
            if (cmp == 0) {
               final aDate = a.createdAt ?? DateTime.now();
               final bDate = b.createdAt ?? DateTime.now();
               return bDate.compareTo(aDate);
            }
            return cmp;
          });
          break;
        case ExploreFilterMode.recientes:
        default:
          break;
      }
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
      await OfflineSyncService.syncPendingTasks(this);
      pendingDrafts = await _repository.getPendingDrafts();
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

  void setExploreMode(ExploreFilterMode mode) {
    exploreMode = mode;
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
      pendingDrafts = await _repository.getPendingDrafts();
      notifyListeners();
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

  Future<void> resolveReport(Report report, List<int> imageBytes, String imageExtension, String resolutionDetail) async {
    try {
      await _repository.resolveReport(report, imageBytes, imageExtension, resolutionDetail);
      await load(); // Reload to get updated report details (like resolved_image_url)
    } catch (e) {
      debugPrint('Error al resolver reporte: $e');
      rethrow;
    }
  }

  Future<void> voteForReport(String reportId) async {
    try {
      // Optimistic update
      final index = reports.indexWhere((r) => r.id == reportId);
      if (index != -1) {
        reports[index] = reports[index].copyWith(upvotes: reports[index].upvotes + 1);
        notifyListeners();
      }
      
      await _repository.voteForReport(reportId);
    } catch (e) {
      debugPrint('Error al votar por reporte: $e');
      // Rollback on error
      final index = reports.indexWhere((r) => r.id == reportId);
      if (index != -1) {
        reports[index] = reports[index].copyWith(upvotes: reports[index].upvotes - 1);
        notifyListeners();
      }
    }
  }
}