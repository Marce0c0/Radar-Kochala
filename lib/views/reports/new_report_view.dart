import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/report.dart';

class NewReportView extends StatefulWidget {
  const NewReportView({super.key});
  @override
  State<NewReportView> createState() => _NewReportViewState();
}

class _NewReportViewState extends State<NewReportView> {
  ReportCategory category = ReportCategory.pothole;
  final description = TextEditingController();
  
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile != null) {
        setState(() => _imagePath = pickedFile.path);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al obtener la imagen')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Nuevo reporte', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Ayúdanos a cuidar Cochabamba', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            const SizedBox(height: 8),
            const Text('Comparte un problema urbano dentro de la ciudad.', style: TextStyle(color: Color(0xff668080))),
            const SizedBox(height: 24),
            
            const Row(
              children: [
                Text('Evidencia fotográfica ', style: TextStyle(fontWeight: FontWeight.w800)),
                Text('*', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            if (_imagePath != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(_imagePath!), height: 200, width: double.infinity, fit: BoxFit.cover)),
                  IconButton(icon: const Icon(Icons.cancel, color: Colors.white, size: 30), onPressed: () => setState(() => _imagePath = null)),
                ],
              )
            else
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text('Cámara'))),
                  const SizedBox(width: 10),
                  Expanded(child: OutlinedButton.icon(onPressed: () => _pickImage(ImageSource.gallery), icon: const Icon(Icons.photo_library), label: const Text('Galería'))),
                ],
              ),
            const SizedBox(height: 18),

            const Text('¿Qué sucede?', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            DropdownButtonFormField<ReportCategory>(
              initialValue: category,
              decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)), filled: true, fillColor: Colors.white),
              items: ReportCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(categoryName(c)))).toList(),
              onChanged: (v) => setState(() => category = v ?? category),
            ),
            const SizedBox(height: 18),
            
            const Text('Descripción', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              maxLines: 5,
              decoration: InputDecoration(hintText: 'Cuéntanos qué ocurre y dónde...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () async {
                if (_imagePath == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xffd9684b), content: Text('¡Ey! Es obligatorio adjuntar una fotografía del problema.')));
                  return;
                }
                
                if (description.text.trim().length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Describe el problema con al menos 10 caracteres.')));
                  return;
                }

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 20), Expanded(child: Text("La IA está verificando la imagen..."))])),
                );

                try {
                  // =========================================================
                  const String googleApiKey = 'AIzaSyB7jQ_4LKrK4cijmOPkxh4RqYEULNMpix0';
                  // =========================================================

                  final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: googleApiKey);
                  final imageBytes = await File(_imagePath!).readAsBytes();
                  final prompt = TextPart('Eres un inspector municipal. El usuario quiere reportar la categoría: "${categoryName(category)}". Analiza la imagen. Si la imagen realmente muestra ese problema urbano en la calle, responde EXACTAMENTE con la palabra "VALIDO". Si es una foto falsa, un meme, una persona, una habitación interior, o no tiene nada que ver con el problema, responde EXACTAMENTE con la palabra "INVALIDO".');
                  final imagePart = DataPart('image/jpeg', imageBytes);

                  final response = await model.generateContent([Content.multi([prompt, imagePart])]);

                  if (context.mounted) Navigator.pop(context);

                  final veredicto = response.text?.trim().toUpperCase() ?? '';

                  if (veredicto.contains('INVALIDO')) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(backgroundColor: Color(0xffd9684b), content: Text('❌ Sistema Anti-Fraude: La imagen no parece corresponder a un reporte real de esta categoría.'), duration: Duration(seconds: 4)));
                    }
                    return; 
                  }

                  if (context.mounted) {
                    Navigator.pop(context, ReportDraft(category: category, description: description.text.trim(), imageUrl: _imagePath));
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al conectar con la IA de verificación.')));
                  }
                }
              },
              child: const Text('Enviar reporte'),
            ),
          ],
        ),
      );
}