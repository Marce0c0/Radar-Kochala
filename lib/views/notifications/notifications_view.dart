import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final data = await _supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _notifications = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        // Supabase query will fail if the table doesn't exist yet, we just show empty
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await _supabase.from('notifications').update({'is_read': true}).eq('id', id);
      setState(() {
        final index = _notifications.indexWhere((n) => n['id'] == id);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
        }
      });
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('No tienes notificaciones.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final n = _notifications[index];
                    final bool isRead = n['is_read'] == true;
                    
                    // Grouping logic based on date
                    final dateStr = n['created_at'] != null ? n['created_at'].toString() : '';
                    DateTime? date;
                    if (dateStr.isNotEmpty) {
                      date = DateTime.tryParse(dateStr)?.toLocal();
                    }
                    
                    String dateHeader = '';
                    if (date != null) {
                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final yesterday = today.subtract(const Duration(days: 1));
                      final notifDate = DateTime(date.year, date.month, date.day);
                      
                      if (notifDate == today) {
                        dateHeader = 'Hoy';
                      } else if (notifDate == yesterday) {
                        dateHeader = 'Ayer';
                      } else {
                        dateHeader = DateFormat('dd/MM/yyyy').format(notifDate);
                      }
                    } else {
                      dateHeader = 'Anteriores';
                    }
                    
                    // Comprobar si es el primero de este grupo
                    bool showHeader = false;
                    if (index == 0) {
                      showHeader = true;
                    } else {
                      final prevN = _notifications[index - 1];
                      final prevDateStr = prevN['created_at'] != null ? prevN['created_at'].toString() : '';
                      DateTime? prevDate;
                      if (prevDateStr.isNotEmpty) {
                        prevDate = DateTime.tryParse(prevDateStr)?.toLocal();
                      }
                      
                      String prevDateHeader = 'Anteriores';
                      if (prevDate != null) {
                        final now = DateTime.now();
                        final today = DateTime(now.year, now.month, now.day);
                        final yesterday = today.subtract(const Duration(days: 1));
                        final pDate = DateTime(prevDate.year, prevDate.month, prevDate.day);
                        if (pDate == today) {
                          prevDateHeader = 'Hoy';
                        } else if (pDate == yesterday) {
                          prevDateHeader = 'Ayer';
                        } else {
                          prevDateHeader = DateFormat('dd/MM/yyyy').format(pDate);
                        }
                      }
                      
                      if (dateHeader != prevDateHeader) {
                        showHeader = true;
                      }
                    }
                    
                    final tile = ListTile(
                      tileColor: isRead ? null : AppTheme.teal.withValues(alpha: 0.1),
                      leading: Icon(
                        isRead ? Icons.notifications_none : Icons.notifications_active,
                        color: isRead ? Colors.grey : AppTheme.teal,
                      ),
                      title: Text(n['title'] ?? 'Notificación', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n['body'] ?? ''),
                          if (date != null)
                            Text(DateFormat('HH:mm').format(date), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      onTap: () {
                        if (!isRead) _markAsRead(n['id']);
                      },
                    );
                    
                    if (showHeader) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
                            child: Text(
                              dateHeader,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink),
                            ),
                          ),
                          tile,
                        ],
                      );
                    }
                    
                    return tile;
                  },
                ),
    );
  }
}
