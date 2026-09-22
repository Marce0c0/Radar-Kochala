import 'dart:io';
import 'package:flutter/foundation.dart'; // kIsWeb, Uint8List
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';

class NewReportView extends StatefulWidget {
  const NewReportView({super.key});
  @override
  State<NewReportView> createState() => _NewReportViewState();
}

class _NewReportViewState extends State<NewReportView> {
  // BUILDER: acumulamos los campos del reporte paso a paso usando ReportDraftBuilder
  // en lugar de construir ReportDraft con todos los parámetros de golpe al final.
  final _builder = ReportDraftBuilder();

  ReportCategory _category = ReportCategory.pothole;
  String _severity = 'Media';
  final _description = TextEditingController();
  final _picker = ImagePicker();

  // En web almacenamos bytes; en móvil almacenamos el path.
  String? _imagePath;       // móvil/desktop
  Uint8List? _imageBytes;   // web

  bool get _hasImage => kIsWeb ? _imageBytes != null : _imagePath != null;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked =
          await _picker.pickImage(source: source, imageQuality: 70);
      if (picked == null) return;

      if (kIsWeb) {
        // En web: leer bytes directamente porque dart:io no está disponible.
        final bytes = await picked.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imagePath = null;
        });
      } else {
        setState(() {
          _imagePath = picked.path;
          _imageBytes = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al obtener la imagen')),
      );
    }
  }

  void _clearImage() => setState(() {
        _imagePath = null;
        _imageBytes = null;
      });

  // Widget de preview de imagen compatible web/móvil.
  Widget _buildImagePreview() {
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
                  height: 200, width: double.infinity, fit: BoxFit.cover)
              : Image.file(File(_imagePath!),
                  height: 200, width: double.infinity, fit: BoxFit.cover),
        ),
        IconButton(
          icon: const Icon(Icons.cancel, color: Colors.white, size: 30),
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
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Ayúdanos a cuidar Cochabamba',
                style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink)),
            const SizedBox(height: 8),
            const Text('Comparte un problema urbano dentro de la ciudad.',
                style: TextStyle(color: Color(0xff668080))),
            const SizedBox(height: 24),
            const Row(
              children: [
                Text('Evidencia fotográfica ',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text('*',
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            _buildImagePreview(),
            const SizedBox(height: 18),
            const Text('¿Qué sucede?',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            DropdownButtonFormField<ReportCategory>(
              initialValue: _category,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: ReportCategory.values
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(categoryName(c))))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _severity,
              decoration: InputDecoration(
                labelText: 'Gravedad',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'Alta', child: Text('Alta (Peligroso)')),
                DropdownMenuItem(value: 'Media', child: Text('Media (Molesto)')),
                DropdownMenuItem(value: 'Baja', child: Text('Baja (Estético)')),
              ],
              onChanged: (value) =>
                  setState(() => _severity = value ?? _severity),
            ),
            const SizedBox(height: 18),
            const Text('Descripción',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Cuéntanos qué ocurre y dónde...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _submit,
              child: const Text('Enviar reporte'),
            ),
          ],
        ),
      );

  Future<void> _submit() async {
    if (!_hasImage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xffd9684b),
          content: Text(
              '¡Ey! Es obligatorio adjuntar una fotografía del problema.'),
        ),
      );
      return;
    }

    if (_description.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Describe el problema con al menos 10 caracteres.')),
      );
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
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

      // Obtenemos los bytes de la imagen de forma compatible web/móvil.
      final Uint8List imageBytes = kIsWeb
          ? _imageBytes!
          : await File(_imagePath!).readAsBytes();

      final prompt = TextPart(
        'Eres un inspector municipal. El usuario quiere reportar la categoría: '
        '"${categoryName(_category)}". Analiza la imagen. Si la imagen realmente '
        'muestra ese problema urbano en la calle, responde EXACTAMENTE con la '
        'palabra "VALIDO". Si es una foto falsa, un meme, una persona, una '
        'habitación interior, o no tiene nada que ver con el problema, responde '
        'EXACTAMENTE con la palabra "INVALIDO".',
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
                  '❌ Sistema Anti-Fraude: La imagen no parece corresponder a un reporte real de esta categoría.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (mounted) {
        // BUILDER: construimos el ReportDraft de forma fluida con el builder,
        // pasando tanto el path (móvil) como los bytes (web).
        final draft = _builder
            .category(_category)
            .description(_description.text.trim())
            .severity(_severity)
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