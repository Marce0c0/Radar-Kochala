import 'staff_shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/report.dart';
class StaffMapView extends StatelessWidget {
  const StaffMapView({super.key, required this.reports, required this.onOpen});
  final List<Report> reports;
  final ValueChanged<Report> onOpen;
  
  @override
  Widget build(BuildContext context) {
    final mapReports = reports.where((r) => r.latitude != null && r.longitude != null && r.status != ReportStatus.resolved).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const StaffPageIntro(title: 'Mapa de activos', subtitle: 'Vista de monitoreo municipal'),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 300,
            child: FlutterMap(
              options: const MapOptions(initialCenter: LatLng(-17.3895, -66.1568), initialZoom: 13.5),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.app'),
                MarkerLayer(
                  markers: mapReports.map((report) => Marker(
                    point: LatLng(report.latitude!, report.longitude!),
                    width: 40, height: 40,
                    child: GestureDetector(
                      onTap: () => onOpen(report),
                      
                      
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

// ValidateReportView: ahora carga trabajadores reales y guarda asignación en DB.


