import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/report.dart';
import 'status_pill.dart';

class ReportCard extends StatefulWidget {
  const ReportCard({super.key, required this.report, required this.onTap});
  final Report report;
  final VoidCallback onTap;

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  int _votes = 0;
  bool _voted = false;
  bool _votingLoading = false;

  @override
  void initState() {
    super.initState();
    _loadVotes();
  }

  // Carga la cantidad de votos del reporte y si el usuario ya votó.
  Future<void> _loadVotes() async {
    try {
      final client = Supabase.instance.client;
      final result = await client
          .from('votes')
          .select('user_id')
          .eq('report_id', widget.report.id);
      final userId = client.auth.currentUser?.id;
      if (mounted) {
        setState(() {
          _votes = result.length;
          _voted = userId != null &&
              result.any((v) => v['user_id'] == userId);
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleVote() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || _votingLoading) return;

    setState(() => _votingLoading = true);
    try {
      if (_voted) {
        await client
            .from('votes')
            .delete()
            .eq('report_id', widget.report.id)
            .eq('user_id', userId);
        if (mounted) setState(() { _votes--; _voted = false; });
      } else {
        await client.from('votes').insert({
          'report_id': widget.report.id,
          'user_id': userId,
          'vote_value': 1,
        });
        if (mounted) setState(() { _votes++; _voted = true; });
      }
    } catch (e) {
      debugPrint('Error al registrar voto: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar el voto: $e')),
        );
      }
    }
    if (mounted) setState(() => _votingLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // STRATEGY: delegamos la resolución de icono y color al módulo centralizado.
    final color = categoryColor(widget.report.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xffe1e9e6)),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(categoryIcon(widget.report.category), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.report.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xff122b27)),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xff8aa09d)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${widget.report.neighborhood} · ${widget.report.time}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff78908d)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        StatusPill(status: widget.report.status),
                        const SizedBox(width: 8),
                        Text(
                          'Gravedad ${widget.report.severity}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xff607875)),
                        ),
                        const Spacer(),
                        // Botón de voto para priorizar reportes.
                        GestureDetector(
                          onTap: _toggleVote,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _voted
                                  ? const Color(0xff2d8c7e)
                                  : const Color(0xffe8f4f2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_votingLoading)
                                  const SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                          color: Colors.white))
                                else
                                  Icon(
                                    _voted
                                        ? Icons.thumb_up
                                        : Icons.thumb_up_outlined,
                                    size: 13,
                                    color: _voted
                                        ? Colors.white
                                        : const Color(0xff2d8c7e),
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_votes',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _voted
                                        ? Colors.white
                                        : const Color(0xff2d8c7e),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
