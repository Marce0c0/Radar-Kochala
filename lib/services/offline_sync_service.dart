import 'dart:convert';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/report.dart';
import '../controllers/report_controller.dart';
import 'ai_validation_service.dart';

class OfflineSyncService {
  static const String _queueKey = 'offline_task_queue';

  /// Guarda una tarea resuelta en la cola local si no hay internet
  static Future<void> queueResolvedTask({
    required Report report,
    required String notes,
    required Uint8List imageBytes,
    required String ext,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    
    final taskMap = {
      'reportId': report.id,
      'category': categoryName(report.category),
      'notes': notes,
      'imageBytesBase64': base64Encode(imageBytes),
      'ext': ext,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    queue.add(jsonEncode(taskMap));
    await prefs.setStringList(_queueKey, queue);
  }

  /// Intenta sincronizar todas las tareas pendientes si hay conexión
  static Future<void> syncPendingTasks(BuildContext context) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    // In newer connectivity_plus, it returns a List<ConnectivityResult>.
    final isOffline = (connectivityResult as List).contains(ConnectivityResult.none);
    
    if (isOffline) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    
    if (queue.isEmpty) return;
    
    List<String> remainingQueue = [];
    final controller = context.read<ReportController>();
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    for (String taskJson in queue) {
      try {
        final task = jsonDecode(taskJson);
        final imageBytes = base64Decode(task['imageBytesBase64']);
        final reportId = task['reportId'];
        
        // 1. Validar con IA en background
        final validation = await AiValidationService.validateResolutionImage(
          imageBytes, 
          task['category']
        );
        
        if (validation.contains('VALIDO')) {
          // Obtener el reporte original desde el controller (o fetch manual)
          final originalReport = controller.reports.firstWhere((r) => r.id == reportId);
          
          // 2. Subir imagen y marcar resuelto
          await controller.resolveReport(originalReport, imageBytes, task['ext']);

          // 3. Actualizar asignación
          await client.from('assignments')
            .update({
              'worker_notes': task['notes'],
              'completed_at': DateTime.now().toIso8601String(),
            })
            .eq('report_id', reportId)
            .eq('worker_id', userId ?? '');
        } else {
          debugPrint('Reporte $reportId rechazado por IA durante sincronización offline.');
        }
      } catch (e) {
        debugPrint('Error sincronizando tarea $taskJson: $e');
        remainingQueue.add(taskJson); // Keep in queue if it failed (e.g. server error)
      }
    }
    
    await prefs.setStringList(_queueKey, remainingQueue);
    
    if (queue.length > remainingQueue.length && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\${queue.length - remainingQueue.length} tareas sincronizadas con éxito al recuperar conexión.'))
      );
    }
  }
}
