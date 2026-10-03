import 'staff_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';

class StaffMapView extends StatefulWidget {
  const StaffMapView({super.key, required this.reports, required this.onOpen});
  final List<Report> reports;
  final ValueChanged<Report> onOpen;

  @override
  State<StaffMapView> createState() => _StaffMapViewState();
}

class _StaffMapViewState extends State<StaffMapView> {
  ReportStatus? _filterStatus;
  String? _filterSeverity;

  @override
  Widget build(BuildContext context) {
    // Si no hay filtro, por defecto ocultamos los resueltos para no saturar el mapa,
    // pero si seleccionan el filtro explícitamente, los mostramos.
    final mapReports = widget.reports.where((r) {
      if (r.latitude == null || r.longitude == null) return false;
      
      bool passStatus = true;
      if (_filterStatus != null) {
        passStatus = r.status == _filterStatus;
      } else {
        passStatus = r.status != ReportStatus.resolved;
      }
      
      bool passSeverity = true;
      if (_filterSeverity != null) {
        passSeverity = r.severity == _filterSeverity;
      }
      
      return passStatus && passSeverity;
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const StaffPageIntro(title: 'Mapa de activos', subtitle: 'Vista de monitoreo municipal'),
        
        // Filtros de estado
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Todos los activos'),
                selected: _filterStatus == null,
                onSelected: (val) {
                  if (val) setState(() => _filterStatus = null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Sin Asignar'),
                selected: _filterStatus == ReportStatus.reported,
                onSelected: (val) {
                  setState(() => _filterStatus = val ? ReportStatus.reported : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('En Revisión'),
                selected: _filterStatus == ReportStatus.reviewing,
                onSelected: (val) {
                  setState(() => _filterStatus = val ? ReportStatus.reviewing : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('En Proceso'),
                selected: _filterStatus == ReportStatus.inProgress,
                onSelected: (val) {
                  setState(() => _filterStatus = val ? ReportStatus.inProgress : null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Completados'),
                selected: _filterStatus == ReportStatus.resolved,
                onSelected: (val) {
                  setState(() => _filterStatus = val ? ReportStatus.resolved : null);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Filtros de gravedad
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Cualquier gravedad'),
                selected: _filterSeverity == null,
                onSelected: (val) {
                  if (val) setState(() => _filterSeverity = null);
                },
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Alta'),
                selected: _filterSeverity == 'Alta',
                onSelected: (val) => setState(() => _filterSeverity = val ? 'Alta' : null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Media'),
                selected: _filterSeverity == 'Media',
                onSelected: (val) => setState(() => _filterSeverity = val ? 'Media' : null),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('Baja'),
                selected: _filterSeverity == 'Baja',
                onSelected: (val) => setState(() => _filterSeverity = val ? 'Baja' : null),
              ),
            ]
          ),
        ),

        const SizedBox(height: 16),

        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 400, // Hacer el mapa más alto
            child: FlutterMap(
              options: MapOptions(
              cameraConstraint: CameraConstraint.contain(bounds: LatLngBounds(const LatLng(-17.50, -66.25), const LatLng(-17.30, -66.05))),
initialCenter: LatLng(-17.3895, -66.1568), initialZoom: 13.5),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.app'),
                MarkerLayer(
                  markers: mapReports.map((report) => Marker(
                    point: LatLng(report.latitude!, report.longitude!),
                    width: 40, height: 40,
                    child: GestureDetector(
                      onTap: () => widget.onOpen(report),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: categoryColor(report.category),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(categoryIcon(report.category), color: Colors.white, size: 20),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
