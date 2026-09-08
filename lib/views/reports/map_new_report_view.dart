import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';

class MapNewReportView extends StatefulWidget {
  const MapNewReportView({super.key, required this.initialLocation});
  final LatLng initialLocation;

  @override
  State<MapNewReportView> createState() => _MapNewReportViewState();
}

class _MapNewReportViewState extends State<MapNewReportView> {
  ReportCategory category = ReportCategory.pothole;
  final description = TextEditingController();
  
  late LatLng selectedLocation;
  late final MapController mapController;

  @override
  void initState() {
    super.initState();
    selectedLocation = widget.initialLocation;
    mapController = MapController();
  }

  @override
  void dispose() {
    description.dispose();
    mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Nuevo reporte', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Column(
          children: [
            // --- SECCIÓN DEL MAPA INTERACTIVO ---
            SizedBox(
              height: 220,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: widget.initialLocation,
                      initialZoom: 16.0,
                      // Corregido: se quitó la comprobación innecesaria de null en position.center
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          setState(() {
                            selectedLocation = position.center;
                          });
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                    ],
                  ),
                  // Marcador fijo al centro del mapa
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 35),
                      child: Icon(
                        Icons.location_pin,
                        size: 45,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  // Etiqueta flotante indicando al usuario que mueva el mapa
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Mueve el mapa para ajustar la ubicación',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- FORMULARIO DE DETALLES ---
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const Text('¿Qué encontraste?',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${selectedLocation.latitude.toStringAsFixed(5)}, Lon: ${selectedLocation.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Color(0xff668080)),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<ReportCategory>(
                    // Corregido: se usa initialValue en lugar de value por deprecación en versiones recientes de Flutter
                    initialValue: category,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    items: ReportCategory.values
                        .map((value) => DropdownMenuItem(value: value, child: Text(categoryName(value))))
                        .toList(),
                    onChanged: (value) => setState(() => category = value ?? category),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: description,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Describe el bache o problema...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () {
                      if (description.text.trim().length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Describe el problema con al menos 10 caracteres.')));
                        return;
                      }
                      Navigator.pop(
                        context,
                        ReportDraft(
                          category: category,
                          description: description.text.trim(),
                          latitude: selectedLocation.latitude,
                          longitude: selectedLocation.longitude,
                        ),
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Publicar reporte'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}