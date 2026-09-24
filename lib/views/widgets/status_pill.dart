import 'package:flutter/material.dart';
import '../../data/models/report.dart';

// DECORATOR: StatusPill "decora" visualmente el estado del reporte,
// añadiendo color y formato sin modificar el dato original.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final ReportStatus status;

  @override
  Widget build(BuildContext context) {
    // STRATEGY: color delegado al módulo centralizado.
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusName(status),
        style: TextStyle(
            color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

