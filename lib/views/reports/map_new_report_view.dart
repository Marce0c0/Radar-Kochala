import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
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
  // BUILDER: acumulamos categoría, descripción, ubicación e imagen
  // antes de construir el ReportDraft final al pulsar enviar.
  final _builder = ReportDraftBuilder();

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
      final XFile? picked =
          await _picker.pickImage(source: source, imageQuality: 70);
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
                            'com.example.cochabamba_reporta',
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
      final String googleApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
      if (googleApiKey.isEmpty) throw Exception('API Key no configurada');

      final model =
          GenerativeModel(model: 'gemini-3.6-flash', apiKey: googleApiKey);

      // Compatible web/móvil.
      final Uint8List imageBytes = kIsWeb
          ? _imageBytes!
          : await File(_imagePath!).readAsBytes();

      final prompt = TextPart(
        'Eres un inspector municipal. El usuario quiere reportar la categoría: '
        '"${categoryName(_category)}". Analiza la imagen. Si la imagen realmente '
        'muestra ese problema urbano en la calle, responde EXACTAMENTE con la '
        'palabra "VALIDO". Si es una foto falsa, un meme, una persona, o no '
        'tiene nada que ver con el problema, responde EXACTAMENTE "INVALIDO".',
      );
      final imagePart = DataPart('image/jpeg', imageBytes);
      final response =
          await model.generateContent([Content.multi([prompt, imagePart])]);

      if (mounted) Navigator.pop(context);

      final veredicto = response.text?.trim().toUpperCase() ?? '';

      if (veredicto.contains('INVALIDO')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xffd9684b),
              content: Text(
                  '❌ Anti-Fraude: La imagen no corresponde al tipo de reporte.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (mounted) {
        // BUILDER: construimos el ReportDraft con ubicación e imagen.
        final draft = _builder
            .category(_category)
            .description(_description.text.trim())
            .severity(_severity)
            .location(_selectedLocation.latitude, _selectedLocation.longitude)
            .image(kIsWeb ? null : _imagePath)
            .imageBytes(kIsWeb ? _imageBytes?.toList() : null)
            .build();

        Navigator.pop(context, draft);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Error al conectar con la IA de verificación.')),
        );
      }
    }
  }
}
