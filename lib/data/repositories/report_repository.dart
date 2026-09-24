import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb + debugPrint
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';
import '../providers/local_db_provider.dart';


// REPOSITORIO: Maneja el acceso a los datos en Supabase.
class ReportRepository {
  // SINGLETON: accedemos al cliente de Supabase a través de su instancia global.
  final _client = Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  static const String _offlineQueueKey = 'offline_reports_queue';

  Future<void> saveDraftToQueue(ReportDraft draft) async {
    final jsonStr = jsonEncode(draft.toJson());
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_offlineQueueKey) ?? [];
      queue.add(jsonStr);
      await prefs.setStringList(_offlineQueueKey, queue);
    } else {
      await LocalDbProvider().enqueue(jsonStr);
    }
  }

  Future<void> syncQueue() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final queue = prefs.getStringList(_offlineQueueKey) ?? [];
      if (queue.isEmpty) return;

      List<String> remaining = [];
      for (final item in queue) {
        try {
          final draftMap = jsonDecode(item);
          final draft = ReportDraft.fromJson(draftMap);
          await createReport(draft); 
        } catch (e) {
          debugPrint('Error syncing offline report: $e');
          remaining.add(item); 
        }
      }
      
      await prefs.setStringList(_offlineQueueKey, remaining);
    } else {
      final queue = await LocalDbProvider().getQueue();
      for (final row in queue) {
        try {
          final item = row['json_data'] as String;
          final id = row['id'] as int;
          final draftMap = jsonDecode(item);
          final draft = ReportDraft.fromJson(draftMap);
          await createReport(draft);
          await LocalDbProvider().deleteFromQueue(id);
        } catch (e) {
          debugPrint('Error syncing sqlite offline report: $e');
        }
      }
    }
  }

  Future<List<Report>> fetchReports({int limit = 50, int offset = 0}) async {
    try {
      final response = await _client
          .from('reports')
          .select()
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // FACTORY METHOD: delegamos la construcción del objeto al modelo.
      return response
          .map((data) => Report.fromMap(data, currentUserId: _currentUserId))
          .toList();
    } catch (e) {
      debugPrint('Error al cargar reportes: $e');
      return [];
    }
  }

  Future<Report> createReport(ReportDraft draft) async {
    final lat = draft.latitude ?? -17.3895;
    final lng = draft.longitude ?? -66.1568;
    String? finalImageUrl;
    if (kIsWeb && draft.imageBytes != null) {
      try {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_$_currentUserId.jpg';
        await _client.storage
            .from('report_images')
            .uploadBinary(fileName, Uint8List.fromList(draft.imageBytes!));
        finalImageUrl =
            _client.storage.from('report_images').getPublicUrl(fileName);
      } catch (e) {
        debugPrint('Error al subir imagen (web): $e');
      }
    } else if (!kIsWeb && draft.imageUrl != null && draft.imageUrl!.isNotEmpty) {
      try {
        final file = File(draft.imageUrl!);
        final fileExt = file.path.split('.').last;
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_$_currentUserId.$fileExt';
        await _client.storage.from('report_images').upload(fileName, file);
        finalImageUrl =
            _client.storage.from('report_images').getPublicUrl(fileName);
      } catch (e) {
        debugPrint('Error al subir imagen (móvil): $e');
      }
    }


    final existing = await _client
        .from('reports')
        .select()
        .eq('author_id', _currentUserId ?? '')
        .eq('description', draft.description)
        .order('created_at', ascending: false)
        .limit(1);
    
    if (existing.isNotEmpty) {
      final lastReportTime = DateTime.parse(existing[0]['created_at']);
      if (DateTime.now().toUtc().difference(lastReportTime).inMinutes < 5) {
        return Report.fromMap(existing[0], currentUserId: _currentUserId);
      }
    }

    final response = await _client.from('reports').insert({
      // Título limpio — sin la redundante palabra "reportado".
      'title': categoryName(draft.category),
      'description': draft.description,
      'category': draft.category.name,
      'severity': draft.severity,
      'latitude': lat,
      'longitude': lng,
      'image_url': finalImageUrl,
      'author_id': _currentUserId,
      'is_ai_verified': draft.isAiVerified,
    }).select().single();

    // FACTORY METHOD: el modelo construye el Report desde la respuesta.
    return Report.fromMap(
      {...response, 'image_url': finalImageUrl},
      currentUserId: _currentUserId,
    );
  }

  Future<void> updateReportStatus(String id, ReportStatus status) async {
    await _client
        .from('reports')
        .update({'status': status.name}).eq('id', id);
  }

  Future<void> deleteReport(String id) async {
    await _client.from('reports').delete().eq('id', id);
  }

  Future<void> resolveReport(Report report, List<int> imageBytes, String imageExtension) async {
    // Subir la imagen de prueba de trabajo
    final fileName = 'resolved_${DateTime.now().millisecondsSinceEpoch}_${report.id}.$imageExtension';
    await _client.storage.from('report_images').uploadBinary(fileName, Uint8List.fromList(imageBytes));
    final resolvedImageUrl = _client.storage.from('report_images').getPublicUrl(fileName);

    // Actualizar el estado del reporte y la imagen resuelta
    await _client.from('reports').update({
      'status': ReportStatus.resolved.name,
      'resolved_image_url': resolvedImageUrl,
    }).eq('id', report.id);

    // Sumar puntos al ciudadano (si hay)
    if (report.authorId != null) {
      try {
        await _client.rpc('increment_points', params: {'user_id': report.authorId, 'amount': 10});
      } catch (e) {
        debugPrint('Error incrementing points: $e');
      }
    }
  }
}