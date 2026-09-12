import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import 'status_pill.dart';

class ReportCard extends StatelessWidget {
  const ReportCard({super.key, required this.report, required this.onTap});
  final Report report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(report.category);
    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xffe1e9e6)),
      ),
      child: InkWell(
        onTap: onTap,
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
                  // Corregido: se usa withValues en lugar de withOpacity para evitar pérdida de precisión
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_categoryIcon(report.category), color: color),
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
                            report.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: Color(0xff8aa09d)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${report.neighborhood} · ${report.time}',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xff78908d)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        StatusPill(status: report.status),
                        const SizedBox(width: 8),
                        Text(
                          'Gravedad ${report.severity}',
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xff607875)),
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

  IconData _categoryIcon(ReportCategory c) => switch (c) {
        ReportCategory.pothole => Icons.warning_amber_rounded,
        ReportCategory.waste => Icons.delete_outline,
        ReportCategory.lighting => Icons.lightbulb_outline,
        ReportCategory.publicSpace => Icons.park_outlined,
      };

  Color _categoryColor(ReportCategory c) => switch (c) {
        ReportCategory.pothole => const Color(0xffd9684b),
        ReportCategory.waste => const Color(0xff718d43),
        ReportCategory.lighting => const Color(0xffd99a3d),
        ReportCategory.publicSpace => AppTheme.teal,
      };
}
