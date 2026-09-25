import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../services/ai_validation_service.dart';
import '../../data/models/report.dart';

class MapNewReportView extends StatefulWidget {
  const MapNewReportView({super.key, required this.initialLocation});
  final LatLng initialLocation;

  @override
  State<MapNewReportView> createState() => _MapNewReportViewState();
}

class _MapNewReportViewState extends State<MapNewReportView> {

  ReportCategory _category = ReportCategory.pothole;
  String _severity = 'Media';
  final _description = TextEditingController();
  late LatLng _selectedLocation;
  late final MapController _mapController;
  final _picker = ImagePicker();

  // En web guardamos bytes, en móvil guardamos path.
  String? _imagePath;
  Uint8List? _imageBytes;

  bool get _hasImage => kIsWeb ? _imageBytes != null : _imagePath != null;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _mapController = MapController();
  }

  @override
  void dispose() {
    _description.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 50,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() { _imageBytes = bytes; _imagePath = null; });
      } else {
        setState(() { _imagePath = picked.path; _imageBytes = null; });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al obtener la imagen')),
        );
      }
    }
  }

  void _clearImage() => setState(() { _imagePath = null; _imageBytes = null; });

  Widget _buildImageSection() {
    if (!_hasImage) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.camera),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Cámara'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _pickImage(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Galería'),
            ),
          ),
        ],
      );
    }
    return Stack(
      alignment: Alignment.topRight,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: kIsWeb
              ? Image.memory(_imageBytes!,
                  height: 160, width: double.infinity, fit: BoxFit.cover)
              : Image.file(File(_imagePath!),
                  height: 160, width: double.infinity, fit: BoxFit.cover),
        ),
        IconButton(
          icon: const Icon(Icons.cancel, color: Colors.white, size: 28),
          onPressed: _clearImage,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Nuevo reporte',
              style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Column(
          children: [
            // --- SECCIÓN DEL MAPA INTERACTIVO ---
            SizedBox(
              height: 200,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: widget.initialLocation,
                      initialZoom: 16.0,
                      cameraConstraint: CameraConstraint.contain(
                        bounds: LatLngBounds(
                          const LatLng(-17.25, -66.30),
                          const LatLng(-17.50, -65.90),
                        ),
                      ),
                      onPositionChanged: (position, hasGesture) {
                        if (hasGesture) {
                          setState(() => _selectedLocation = position.center);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.radar.kochala',
                      ),
                    ],
                  ),
                  // Marcador fijo al centro del mapa.
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 35),
                      child: Icon(Icons.location_pin,
                          size: 45, color: Colors.red),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 12),
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
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink)),
                  const SizedBox(height: 4),
                  Text(
                    'Lat: ${_selectedLocation.latitude.toStringAsFixed(5)}, '
                    'Lon: ${_selectedLocation.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(color: Color(0xff668080)),
                  ),
                  const SizedBox(height: 16),

                  // Evidencia fotográfica (obligatoria + verificación IA).
                  const Row(
                    children: [
                      Text('Evidencia fotográfica ',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      Text('*',
                          style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildImageSection(),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<ReportCategory>(
                    initialValue: _category,
                    decoration: InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    items: ReportCategory.values
                        .map((value) => DropdownMenuItem(
                            value: value, child: Text(categoryName(value))))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _category = value ?? _category),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _severity,
                    decoration: InputDecoration(
                      labelText: 'Gravedad',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Alta', child: Text('Alta (Peligroso)')),
                      DropdownMenuItem(value: 'Media', child: Text('Media (Molesto)')),
                      DropdownMenuItem(value: 'Baja', child: Text('Baja (Estético)')),
                    ],
                    onChanged: (value) =>
                        setState(() => _severity = value ?? _severity),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Descripción',
                      hintText: 'Describe el bache o problema...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.send),
                    label: const Text('Publicar reporte'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Future<void> _submit() async {
    if (!_hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xffd9684b),
          content: Text('¡Es obligatorio adjuntar una fotografía!'),
        ),
      );
      return;
    }
    if (_description.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Describe el problema con al menos 10 caracteres.')),
      );
      return;
    }

    if (!mounted) return;

    // --- CHECK ANTI-DUPLICADOS ---
    try {
      final nearby = await Supabase.instance.client.rpc('check_nearby_reports', params: {
        'p_lat': _selectedLocation.latitude,
        'p_lng': _selectedLocation.longitude,
        'p_category': _category.name,
        'p_radius_meters': 150.0,
      });

      if (nearby != null && (nearby as List).isNotEmpty && mounted) {
        final dup = nearby.first as Map<String, dynamic>;
        final distMeters = (dup['distance_meters'] as num).round();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Posible duplicado'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ya existe un reporte similar a $distMeters metros de este punto:'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(dup['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Estado: ${dup['status']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('¿Tu reporte es diferente a este? Confirma para continuar.'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sí, es diferente')),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    } catch (e) {
      debugPrint('Error al verificar duplicados: $e');
      // No bloqueamos si falla — seguimos con el flujo normal
    }
    // --- FIN CHECK ANTI-DUPLICADOS ---

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Expanded(child: Text('La IA está verificando la imagen...')),
        ]),
      ),
    );

    try {
      final Uint8List imageBytes = kIsWeb
          ? _imageBytes!
          : await File(_imagePath!).readAsBytes();

      final validationText = await AiValidationService.validateLocalImage(
          imageBytes, categoryName(_category));

      if (mounted) Navigator.pop(context);

      final veredicto = validationText.trim().toUpperCase();

      if (veredicto.contains('INVALIDO')) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('❌ Sistema Anti-Fraude'),
              content: const Text('La imagen proporcionada no parece corresponder a un reporte real de esta categoría. Por favor intenta con otra foto.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendido'),
                ),
              ],
            ),
          );
        }
        return;
      }

      if (mounted) {
        final draft = ReportDraft(
          category: _category,
          description: _description.text.trim(),
          severity: _severity,
          latitude: _selectedLocation.latitude,
          longitude: _selectedLocation.longitude,
          imageUrl: kIsWeb ? null : _imagePath,
          imageBytes: kIsWeb ? _imageBytes?.toList() : null,
          isAiVerified: true,
        );

        Navigator.pop(context, draft);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar diálogo
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Sin conexión a la IA'),
            content: const Text('No se pudo verificar la imagen automáticamente en este momento. Guardando reporte sin validación por IA.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );

        if (!mounted) return;
        final draft = ReportDraft(
          category: _category,
          description: _description.text.trim(),
          severity: _severity,
          latitude: _selectedLocation.latitude,
          longitude: _selectedLocation.longitude,
          imageUrl: kIsWeb ? null : _imagePath,
          imageBytes: kIsWeb ? _imageBytes?.toList() : null,
          isAiVerified: false,
        );

        Navigator.pop(context, draft);
      }
    }
  }
}
