import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
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
  LatLng? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _iniciarRastreoGPS();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _iniciarRastreoGPS() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _mostrarErrorGPS('GPS Desactivado', 'Por favor, activa el GPS/Ubicacion en tu telefono.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) _mostrarErrorGPS('Permiso Denegado', 'Necesitamos permiso de ubicacion para encontrar los baches cerca de ti.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) _mostrarErrorGPS('Permisos Bloqueados', 'Ve a la configuracion de Android y activa los permisos de ubicacion para esta app.');
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
        _safeMove(_currentPosition!, 15.5);
      }
    } catch (_) {}

    _positionStreamSubscription ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  Future<void> _centrarEnUbicacionUsuario() async {
    if (_currentPosition != null) {
      _safeMove(_currentPosition!, 16.0);
    } else {
      await _iniciarRastreoGPS();
      if (_currentPosition != null) {
        _safeMove(_currentPosition!, 16.0);
      }
    }
  }

  void _mostrarErrorGPS(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
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
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Publicando reporte...'),
            ]),
          ),
        );

        final result = await context.read<ReportController>().create(draft);
        
        if (!context.mounted) return;
        Navigator.pop(context); // Oculta indicador
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(result != null ? '¡Reporte Publicado!' : 'Atención', style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(result != null 
                ? 'Tu reporte fue validado por la IA y ha sido publicado exitosamente para que las autoridades lo atiendan.' 
                : 'Ocurrió un problema de red o de permisos al publicar en la nube. El reporte ha sido guardado localmente (Offline) y se publicará en cuanto se pueda.'),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );

        if (context.mounted) await context.read<ReportController>().load();
      }
    }
  
    void _safeMove(LatLng center, double zoom) {
    try {
      _mapController.move(center, zoom);
    } catch (_) {}
  }

  Color _getStatusRingColor(ReportStatus status) {
    switch (status) {
      case ReportStatus.reported:
        return const Color(0xffd9684b); // Red for pending
      case ReportStatus.reviewing:
        return Colors.orange; // Orange for reviewing
      case ReportStatus.inProgress:
        return Colors.blue; // Blue for assigned
      case ReportStatus.resolved:
        return const Color(0xff52b788); // Green for resolved
    }
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
                          'com.radar.kochala',
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
                                  width: 54,
                                  height: 54,
                                  child: GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              DetailView(report: report)),
                                    ),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: _getStatusRingColor(report.status), width: 3.5),
                                        boxShadow: const [
                                          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                                        ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(2.0),
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            color: categoryColor(report.category),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            categoryIcon(report.category),
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                        ),
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
                    if (_currentPosition != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _currentPosition!,
                            width: 60,
                            height: 60,
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.blue,
                              size: 50,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FilterChip(
                        label: const Text('Ocultar resueltos'),
                        selected: controller.hideResolved,
                        onSelected: (v) => controller.setHideResolved(v),
                        backgroundColor: Colors.white,
                        selectedColor: AppTheme.teal.withOpacity(0.2),
                        checkmarkColor: AppTheme.teal,
                        elevation: 4,
                      ),
                      PopupMenuButton<ReportCategory?>(
                        initialValue: controller.filter,
                        onSelected: (value) => controller.setFilter(value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: null,
                            child: Text('Todas las categorias'),
                          ),
                          const PopupMenuDivider(),
                          ...ReportCategory.values.map(
                            (c) => PopupMenuItem(
                              value: c,
                              child: Text(categoryName(c)),
                            ),
                          ),
                        ],
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(30),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.filter_list, color: AppTheme.teal, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  controller.filter == null ? 'Filtrar' : categoryName(controller.filter!),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'map-compass',
                        backgroundColor: Colors.white,
                        onPressed: () {
                          try {
                            _mapController.rotate(0);
                          } catch (_) {}
                        },
                        child: const Icon(Icons.explore, color: AppTheme.teal),
                      ),
                      const SizedBox(height: 8),
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



