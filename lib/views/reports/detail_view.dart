import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../widgets/status_pill.dart';

class DetailView extends StatelessWidget {
  const DetailView({super.key, required this.report});
  final Report report;

  @override
Widget build(BuildContext context) {
  final String? imageUrl = report.imageUrl;

  return Scaffold(
    backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
    appBar: AppBar(
      title: const Text('Detalle del reporte',
          style: TextStyle(fontWeight: FontWeight.w800)),
      backgroundColor: Colors.white,
      elevation: 0,
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Solo renderiza el contenedor si hay una imagen presente
        if (imageUrl != null && imageUrl.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xffdcebe6),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.ink.withValues(alpha: 0.08),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 50, color: Color(0xff78908d)),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6)
                          ],
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Evidencia fotográfica del reporte',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
          // --- TÍTULO Y ESTADO ---
          Text(
            report.title,
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppTheme.ink,
                height: 1.2),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              StatusPill(status: report.status),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 16, color: Color(0xff668080)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        report.neighborhood,
                        style: const TextStyle(
                            color: Color(0xff668080),
                            fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // --- DESCRIPCIÓN ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xffe1e9e6)),
            ),
            child: Text(
              report.description,
              style: const TextStyle(
                  fontSize: 15, height: 1.6, color: Color(0xff344f4c)),
            ),
          ),
          const SizedBox(height: 30),

          // --- SEGUIMIENTO ---
          const Text(
            'Seguimiento de la alcaldía',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xffe1e9e6)),
            ),
            child: Column(
              children: updatesFor(report).asMap().entries.map((e) {
                e.key == updatesFor(report).length - 1;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: e.value.completed
                        ? AppTheme.teal
                        : const Color(0xffdcebe6),
                    child: e.value.completed
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : Text('${e.key + 1}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.ink)),
                  ),
                  title: Text(
                    e.value.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: e.value.completed
                          ? AppTheme.ink
                          : const Color(0xff78908d),
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(e.value.note,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xff668080))),
                  ),
                  isThreeLine: true,
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
