import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
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
  
  // Nuevas variables para la imagen
  String? _imagePath;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  // Método para capturar la imagen
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source, 
        imageQuality: 70, // Comprime un poco para no saturar la memoria
      );
      if (pickedFile != null) {
        setState(() => _imagePath = pickedFile.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al obtener la imagen')),
      );
    }
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
            
            // --- NUEVA SECCIÓN DE FOTOGRAFÍA ---
            const Text('Evidencia fotográfica',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (_imagePath != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(_imagePath!),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white, size: 30),
                    onPressed: () => setState(() => _imagePath = null),
                  ),
                ],
              )
            else
              Row(
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
              ),
            const SizedBox(height: 18),
            // --- FIN NUEVA SECCIÓN ---

            const Text('¿Qué sucede?',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            DropdownButtonFormField<ReportCategory>(
              initialValue: category,
              decoration: InputDecoration(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: ReportCategory.values
                  .map((c) =>
                      DropdownMenuItem(value: c, child: Text(categoryName(c))))
                  .toList(),
              onChanged: (v) => setState(() => category = v ?? category),
            ),
            const SizedBox(height: 18),
            const Text('Descripción',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Cuéntanos qué ocurre y dónde...',
                filled: true,
                fillColor: Colors.white,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {
                if (description.text.trim().length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Describe el problema con al menos 10 caracteres.')));
                  return;
                }
                Navigator.pop(
                  context,
                  ReportDraft(
                    category: category, 
                    description: description.text.trim(),
                    imageUrl: _imagePath, // Se envía la ruta de la foto
                  ),
                );
              },
              child: const Text('Enviar reporte'),
            ),
          ],
        ),
      );
}