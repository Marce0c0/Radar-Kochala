import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../reports/detail_view.dart';
import '../reports/map_new_report_view.dart';
import '../widgets/report_card.dart';

class MapExploreView extends StatelessWidget {
  MapExploreView({super.key, required this.controller});

  final ReportController controller;
  final MapController mapController = MapController();
  static const cochabamba = LatLng(-17.3895, -66.1568);

  Future<void> _addReport(BuildContext context, LatLng location) async {
    // Ahora abrimos MapNewReportView pasando la ubicación seleccionada como initialLocation
    final draft = await Navigator.push<ReportDraft>(
      context,
      MaterialPageRoute(builder: (_) => MapNewReportView(initialLocation: location)),
    );
    if (draft != null) {
      await controller.create(draft);
    }
  }

  void _safeMove(LatLng center, double zoom) {
    try {
      mapController.move(center, zoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final reports = controller.visibleReports;
    final mappedReports = reports
        .where((report) => report.latitude != null && report.longitude != null);
    
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      children: [
        const Text(
          'Mapa ciudadano',
          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800, color: AppTheme.ink),
        ),
        const SizedBox(height: 4),
        const Text(
          'Toca un punto del mapa para reportar un bache o cualquier problema.',
          style: TextStyle(color: Color(0xff668080)),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 360,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: cochabamba,
                    initialZoom: 13.2,
                    minZoom: 10,
                    maxZoom: 19,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    // Al tocar cualquier parte del mapa, enviamos ese punto como referencia inicial
                    onTap: (_, point) => _addReport(context, point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.cochabamba_reporta',
                    ),
                    MarkerLayer(
                      markers: mappedReports
                          .map((report) => Marker(
                              point: LatLng(report.latitude!, report.longitude!),
                              width: 48,
                              height: 48,
                              child: GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => DetailView(report: report)),
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: _categoryColor(report.category),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                  ),
                                  child: Icon(
                                    _categoryIcon(report.category),
                                    color: Colors.white,
                                    size: 23,
                                  ),
                                ),
                              ),
                            ))
                          .toList(),
                    ),
                  ],
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'map-zoom-in',
                        tooltip: 'Acercar mapa',
                        onPressed: () {
                          try {
                            final currentZoom = mapController.camera.zoom;
                            _safeMove(mapController.camera.center, currentZoom + 1);
                          } catch (_) {
                            _safeMove(cochabamba, 14.2);
                          }
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'map-zoom-out',
                        tooltip: 'Alejar mapa',
                        onPressed: () {
                          try {
                            final currentZoom = mapController.camera.zoom;
                            _safeMove(mapController.camera.center, currentZoom - 1);
                          } catch (_) {
                            _safeMove(cochabamba, 12.2);
                          }
                        },
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          // Si el usuario presiona el botón inferior, toma el centro actual del mapa o Cochabamba
          onPressed: () {
            LatLng center = cochabamba;
            try {
              center = mapController.camera.center;
            } catch (_) {}
            _addReport(context, center);
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Añadir reporte en el mapa'),
        ),
        const SizedBox(height: 20),
        const Text(
          'Reportes cercanos',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink),
        ),
        const SizedBox(height: 10),
        ...reports.take(4).map((report) => ReportCard(
              report: report,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DetailView(report: report)),
              ),
            )),
      ],
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