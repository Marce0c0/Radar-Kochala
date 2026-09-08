import 'package:flutter/material.dart';
import '../../data/models/report.dart';

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusName(status),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }

  Color _statusColor(ReportStatus s) => switch (s) {
        ReportStatus.reported => const Color(0xff6c7c88),
        ReportStatus.reviewing => const Color(0xffd99a3d),
        ReportStatus.inProgress => const Color(0xff0eb6c2),
        ReportStatus.resolved => const Color(0xff5b954b),
      };
}