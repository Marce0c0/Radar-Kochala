import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';

class LeaderboardView extends StatefulWidget {
  const LeaderboardView({super.key});

  @override
  State<LeaderboardView> createState() => _LeaderboardViewState();
}

class _LeaderboardViewState extends State<LeaderboardView> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _topUsers = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    try {
      final res = await Supabase.instance.client.rpc('get_leaderboard');
      if (mounted) {
        setState(() {
          _topUsers = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking Ciudadano', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _topUsers.isEmpty
              ? const Center(child: Text('Aún no hay ciudadanos con puntos.'))
              : RefreshIndicator(
                  color: AppTheme.teal,
                  onRefresh: _loadLeaderboard,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20).copyWith(bottom: 100),
                    itemCount: _topUsers.length,
                    itemBuilder: (context, index) {
                      final user = _topUsers[index];
                      String name = 'Usuario';
                      if (user['full_name'] != null && user['full_name'].toString().trim().isNotEmpty) {
                        name = user['full_name'];
                      } else if (user['email'] != null) {
                        name = (user['email'] as String).split('@').first;
                      }
                      
                      // Capitalize name
                      if (name.isNotEmpty) {
                        name = name[0].toUpperCase() + name.substring(1);
                      }
                      
                      final points = user['points'] ?? 0;
                      
                      return _buildLeaderboardTile(index, name, points);
                    },
                  ),
                ),
    );
  }

  Widget _buildLeaderboardTile(int index, String name, int points) {
    final isTop3 = index < 3;
    final Color rankColor;
    if (index == 0) {
      rankColor = Colors.amber;
    } else if (index == 1) rankColor = Colors.grey.shade400;
    else if (index == 2) rankColor = Colors.orange.shade300;
    else rankColor = Colors.blueGrey.shade100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isTop3 ? rankColor.withValues(alpha: 0.1) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isTop3 ? rankColor : Colors.grey.shade200, width: isTop3 ? 2 : 1),
        boxShadow: isTop3 ? [
          BoxShadow(color: rankColor.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4))
        ] : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: rankColor,
          foregroundColor: index < 3 ? Colors.white : Colors.black87,
          child: index < 3 
              ? const Icon(Icons.emoji_events, size: 20)
              : Text('#${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        title: Text(name, style: TextStyle(
          fontWeight: isTop3 ? FontWeight.bold : FontWeight.w600,
          fontSize: isTop3 ? 18 : 16,
          color: AppTheme.ink,
        )),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$points pts', style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade800,
          )),
        ),
      ),
    );
  }
}
