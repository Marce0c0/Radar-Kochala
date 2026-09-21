import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb + debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';


// ADAPTER: la interfaz abstracta ReportRepository desacopla la lógica de negocio
// de la fuente de datos concreta (Supabase). Cambiar el backend solo requiere
// crear un nuevo Adapter que implemente esta interfaz.
abstract class ReportRepository {
  Future<List<Report>> fetchReports();
  Future<Report> createReport(ReportDraft draft);
  Future<void> updateReportStatus(String id, ReportStatus status);
}

// ADAPTER concreto: adapta la API de Supabase a la interfaz ReportRepository.
class SupabaseReportRepository implements ReportRepository {
  // SINGLETON: accedemos al cliente de Supabase a través de su instancia global.
  final _client = Supabase.instance.client;

  String? get _currentUserId => _client.auth.currentUser?.id;

  @override
  Future<List<Report>> fetchReports() async {
    try {
      final response = await _client
          .from('reports')
          .select()
          .order('created_at', ascending: false);

      // FACTORY METHOD: delegamos la construcción del objeto al modelo.
      return response
          .map((data) => Report.fromMap(data, currentUserId: _currentUserId))
          .toList();
    } catch (e) {
      debugPrint('Error al cargar reportes: $e');
      return [];
    }
  }

  @override
  Future<Report> createReport(ReportDraft draft) async {
    final lat = draft.latitude ?? -17.3895;
    final lng = draft.longitude ?? -66.1568;
    String? finalImageUrl;

    // CORRECCIÓN #8: en Flutter Web, dart:io no existe.
    // En web usamos los bytes ya leídos por el picker (draft.imageBytes).
    // En móvil/desktop usamos dart:io File con el path.
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
    }).select().single();

    // FACTORY METHOD: el modelo construye el Report desde la respuesta.
    return Report.fromMap(
      {...response, 'image_url': finalImageUrl},
      currentUserId: _currentUserId,
    );
  }

  @override
  Future<void> updateReportStatus(String id, ReportStatus status) async {
    await _client
        .from('reports')
        .update({'status': status.name}).eq('id', id);
  }
}