import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/report.dart';

abstract class ReportRepository {
  Future<List<Report>> fetchReports();
  Future<Report> createReport(ReportDraft draft);
  Future<void> updateReportStatus(String id, ReportStatus status);
}

class SupabaseReportRepository implements ReportRepository {
  final _client = Supabase.instance.client;

  @override
  Future<List<Report>> fetchReports() async {
    try {
      final response = await _client.from('reports').select().order('created_at', ascending: false);

      return response.map((data) => Report(
            id: data['id']?.toString() ?? '',
            title: data['title'] ?? 'Sin título',
            category: ReportCategory.values.firstWhere((e) => e.name == data['category'], orElse: () => ReportCategory.pothole),
            status: ReportStatus.values.firstWhere((e) => e.name == data['status'], orElse: () => ReportStatus.reported),
            neighborhood: 'Cochabamba',
            time: 'Reciente', 
            severity: data['severity']?.toString() ?? 'Media',
            description: data['description'] ?? '',
            latitude: data['latitude']?.toDouble(),
            longitude: data['longitude']?.toDouble(),
            imageUrl: data['image_url'],
            isMine: _client.auth.currentUser?.id != null && _client.auth.currentUser?.id == data['author_id'],
          )).toList();
    } catch (e) {
      print('Error al cargar reportes: $e');
      return [];
    }
  }

  @override
  Future<Report> createReport(ReportDraft draft) async {
    final lat = draft.latitude ?? -17.3895;
    final lng = draft.longitude ?? -66.1568;
    String? finalImageUrl;

    if (draft.imageUrl != null && draft.imageUrl!.isNotEmpty) {
      try {
        final file = File(draft.imageUrl!);
        final fileExt = file.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_client.auth.currentUser?.id}.$fileExt';
        
        await _client.storage.from('report_images').upload(fileName, file);
        finalImageUrl = _client.storage.from('report_images').getPublicUrl(fileName);
      } catch (e) {
        print('Error al subir imagen: $e');
      }
    }

    final response = await _client.from('reports').insert({
      'title': '${categoryName(draft.category)} reportado',
      'description': draft.description,
      'category': draft.category.name,
      'latitude': lat,
      'longitude': lng,
      'image_url': finalImageUrl,
      'author_id': _client.auth.currentUser?.id, 
    }).select().single();

    return Report(
      id: response['id']?.toString() ?? '',
      title: response['title'] ?? '',
      category: draft.category,
      status: ReportStatus.reported,
      neighborhood: 'Cochabamba',
      time: 'Justo ahora',
      severity: response['severity']?.toString() ?? 'Media',
      description: response['description'] ?? '',
      latitude: response['latitude']?.toDouble(),
      longitude: response['longitude']?.toDouble(),
      imageUrl: finalImageUrl,
      isMine: true,
    );
  }

  @override
  Future<void> updateReportStatus(String id, ReportStatus status) async {
    await _client.from('reports').update({'status': status.name}).eq('id', id);
  }
}