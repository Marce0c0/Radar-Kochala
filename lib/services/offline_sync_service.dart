import 'dart:convert';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/report.dart';
import '../controllers/report_controller.dart';

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
  static Future<int> syncPendingTasks(ReportController controller) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = (connectivityResult as List).contains(ConnectivityResult.none);
    
    if (isOffline) return 0;

    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(_queueKey) ?? [];
    
    if (queue.isEmpty) return 0;
    
    List<String> remainingQueue = [];
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;

    for (String taskJson in queue) {
      try {
        final task = jsonDecode(taskJson);
        final imageBytes = base64Decode(task['imageBytesBase64']);
        final reportId = task['reportId'];
        
        // Se omite la validación de IA para los trabajadores, ya que son personal de confianza.
        
        // Obtener el reporte original desde el controller (o fetch manual)
        final originalReport = controller.reports.firstWhere((r) => r.id == reportId);
        
        // 1. Subir imagen y marcar resuelto
        await controller.resolveReport(originalReport, imageBytes, task['ext'], task['notes'] ?? '');

        // 2. Actualizar asignación
        await client.from('assignments')
          .update({
            'worker_notes': task['notes'],
            'completed_at': DateTime.now().toIso8601String(),
          })
          .eq('report_id', reportId)
          .eq('worker_id', userId ?? '');
      } catch (e) {
        debugPrint('Error sincronizando tarea $taskJson: $e');
        remainingQueue.add(taskJson); // Keep in queue if it failed (e.g. server error)
      }
    }
    
    await prefs.setStringList(_queueKey, remainingQueue);
    
    return queue.length - remainingQueue.length;
  }
}
