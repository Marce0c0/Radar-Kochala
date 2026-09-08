import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Nuevo reporte', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Ayúdanos a cuidar Cochabamba',
                style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            const SizedBox(height: 8),
            const Text('Comparte un problema urbano dentro de la ciudad.',
                style: TextStyle(color: Color(0xff668080))),
            const SizedBox(height: 24),
            const Text('¿Qué sucede?', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            DropdownButtonFormField<ReportCategory>(
              // Corregido: se usa initialValue en lugar de value por deprecación en versiones recientes
              initialValue: category,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: ReportCategory.values
                  .map((c) => DropdownMenuItem(value: c, child: Text(categoryName(c))))
                  .toList(),
              onChanged: (v) => setState(() => category = v ?? category),
            ),
            const SizedBox(height: 18),
            const Text('Descripción', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: description,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Cuéntanos qué ocurre y dónde...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () {
                if (description.text.trim().length < 10) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Describe el problema con al menos 10 caracteres.')));
                  return;
                }
                Navigator.pop(
                  context,
                  ReportDraft(category: category, description: description.text.trim()),
                );
              },
              child: const Text('Enviar reporte'),
            ),
          ],
        ),
      );
}