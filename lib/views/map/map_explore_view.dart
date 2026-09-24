import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../controllers/report_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';
import '../reports/detail_view.dart';
import '../reports/map_new_report_view.dart';
import '../widgets/report_card.dart';

class MapExploreView extends StatefulWidget {
  const MapExploreView({super.key});

  @override
  State<MapExploreView> createState() => _MapExploreViewState();
}

class _MapExploreViewState extends State<MapExploreView> {
  final MapController _mapController = MapController();
  static const _cochabamba = LatLng(-17.3895, -66.1568);

  @override
  void initState() {
    super.initState();
    _centrarEnUbicacionUsuario();
  }

  Future<void> _centrarEnUbicacionUsuario() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    _safeMove(LatLng(position.latitude, position.longitude), 15.5);
  }

  Future<void> _addReport(BuildContext context, LatLng location) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '🔒 Debes iniciar sesión para enviar un reporte.'),
          backgroundColor: Color(0xffd9684b),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final draft = await Navigator.push<ReportDraft>(
      context,
      MaterialPageRoute(
          builder: (_) =>
              MapNewReportView(initialLocation: location)),
    );
    if (draft != null) {
      if (!context.mounted) return;
      await context.read<ReportController>().create(draft);
      // Recargamos para que el nuevo pin aparezca en el mapa inmediatamente.
      if (context.mounted) await context.read<ReportController>().load();
    }
  }

  void _safeMove(LatLng center, double zoom) {
    try {
      _mapController.move(center, zoom);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    // OBSERVER: context.watch escucha cambios del controller (ChangeNotifier).
    final controller = context.watch<ReportController>();
    final reports = controller.visibleReports;
    final mappedReports = reports
        .where((r) => r.latitude != null && r.longitude != null);
    final isGuest = Supabase.instance.client.auth.currentUser == null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
      children: [
        const Text('Mapa ciudadano',
            style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink)),
        const SizedBox(height: 4),
        Text(
          isGuest
              ? 'Inicia sesión para reportar un problema tocando el mapa.'
              : 'Toca un punto del mapa para reportar.',
          style: TextStyle(
              color: isGuest ? const Color(0xffd9684b) : const Color(0xff668080)),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: SizedBox(
            height: 360,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _cochabamba,
                    initialZoom: 13.2,
                    minZoom: 10,
                    maxZoom: 19,
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(
                        const LatLng(-17.25, -66.30),
                        const LatLng(-17.50, -65.90),
                      ),
                    ),
                    interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all),
                    onTap: (_, point) => _addReport(context, point),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'com.example.cochabamba_reporta',
                    ),
                    MarkerClusterLayerWidget(
                      options: MarkerClusterLayerOptions(
                        maxClusterRadius: 45,
                        size: const Size(40, 40),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(50),
                        markers: mappedReports
                            .map((report) => Marker(
                                  point: LatLng(
                                      report.latitude!, report.longitude!),
                                  width: 48,
                                  height: 48,
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              DetailView(report: report)),
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: categoryColor(report.category),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 3),
                                      ),
                                      child: Icon(
                                        categoryIcon(report.category),
                                        color: Colors.white,
                                        size: 23,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                        builder: (context, markers) {
                          return Container(
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: AppTheme.teal,
                                border: Border.all(color: Colors.white, width: 2)),
                            child: Center(
                              child: Text(
                                markers.length.toString(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  left: 0,
                  right: 0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Ocultar resueltos'),
                          selected: controller.hideResolved,
                          onSelected: (v) => controller.setHideResolved(v),
                          backgroundColor: Colors.white,
                          selectedColor: AppTheme.teal.withOpacity(0.2),
                          checkmarkColor: AppTheme.teal,
                          elevation: 2,
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Todos'),
                          selected: controller.filter == null,
                          onSelected: (_) => controller.setFilter(null),
                          backgroundColor: Colors.white,
                          selectedColor: AppTheme.teal.withOpacity(0.2),
                          elevation: 2,
                        ),
                        const SizedBox(width: 8),
                        ...ReportCategory.values.map((c) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(categoryName(c)),
                            selected: controller.filter == c,
                            onSelected: (_) => controller.setFilter(c),
                            backgroundColor: Colors.white,
                            selectedColor: AppTheme.teal.withOpacity(0.2),
                            elevation: 2,
                          ),
                        )),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'map-loc',
                        backgroundColor: AppTheme.teal,
                        onPressed: _centrarEnUbicacionUsuario,
                        child: const Icon(Icons.my_location,
                            color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'map-in',
                        onPressed: () {
                          try {
                            _safeMove(_mapController.camera.center,
                                _mapController.camera.zoom + 1);
                          } catch (_) {}
                        },
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'map-out',
                        onPressed: () {
                          try {
                            _safeMove(_mapController.camera.center,
                                _mapController.camera.zoom - 1);
                          } catch (_) {}
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
          onPressed: () {
            LatLng center = _cochabamba;
            try {
              center = _mapController.camera.center;
            } catch (_) {}
            _addReport(context, center);
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Añadir reporte en el mapa'),
        ),
        const SizedBox(height: 20),
        const Text('Reportes cercanos',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink)),
        const SizedBox(height: 10),
        ...reports.take(4).map(
              (report) => ReportCard(
                report: report,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => DetailView(report: report)),
                ),
              ),
            ),
      ],
    );
  }
}
