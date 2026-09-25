import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../data/models/report.dart';

class PdfReportService {
  static Future<void> generateAndPrintReport(List<Report> reports) async {
    final pdf = pw.Document();

    final reported = reports.where((r) => r.status == ReportStatus.reported).length;
    final inProgress = reports.where((r) => r.status == ReportStatus.inProgress || r.status == ReportStatus.reviewing).length;
    final resolved = reports.where((r) => r.status == ReportStatus.resolved).length;
    
    // Add page
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text('Radar Kochala - Informe Oficial de Reportes', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Resumen General:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: 'Total Reportes: \${reports.length}'),
            pw.Bullet(text: 'Nuevos: \$reported'),
            pw.Bullet(text: 'En Proceso: \$inProgress'),
            pw.Bullet(text: 'Resueltos: \$resolved'),
            pw.SizedBox(height: 20),
            pw.Text('Lista de Reportes Recientes:', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.Table.fromTextArray(
              context: context,
              headers: ['ID', 'Categoría', 'Severidad', 'Estado', 'Fecha'],
              data: reports.take(50).map((r) => [
                r.id.substring(0, 8),
                r.category.name,
                r.severity,
                r.status.name,
                r.time,
              ]).toList(),
            ),
          ];
        },
      ),
    );

    // This works on web (opens print dialog or downloads) and mobile (opens share/print dialog).
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Radar_Kochala_Informe_\${DateTime.now().toIso8601String().substring(0, 10)}.pdf',
    );
  }
}
