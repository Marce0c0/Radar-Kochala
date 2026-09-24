import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;

class AiValidationService {
  static GenerativeModel? _getModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (apiKey.isEmpty) return null;
    return GenerativeModel(model: 'gemini-3.6-flash', apiKey: apiKey);
  }

  /// Valida la imagen localmente antes de subir el reporte.
  /// Retorna 'VALIDO' o 'INVALIDO'.
  static Future<String> validateLocalImage(Uint8List imageBytes, String categoryName) async {
    final model = _getModel();
    if (model == null) throw Exception('API Key no configurada');

    final prompt = TextPart(
      'Eres un inspector municipal. El usuario quiere reportar la categoría: '
      '"$categoryName". Analiza la imagen. Si la imagen realmente '
      'muestra ese problema urbano en la calle, responde EXACTAMENTE con la '
      'palabra "VALIDO". Si es una foto falsa, un meme, una persona, una '
      'habitación interior, o no tiene nada que ver con el problema, responde '
      'EXACTAMENTE con la palabra "INVALIDO".',
    );
    final imagePart = DataPart('image/jpeg', imageBytes);

    final response = await model.generateContent([Content.multi([prompt, imagePart])]);
    return response.text?.trim() ?? 'INVALIDO';
  }

  /// Valida un reporte existente usando su URL de imagen y devuelve un resumen sugerido
  /// para el operador.
  static Future<String> analyzeReportForOperator(String imageUrl, String category, String description) async {
    final model = _getModel();
    if (model == null) throw Exception('API Key no configurada');

    Uint8List imageBytes;
    try {
      final res = await http.get(Uri.parse(imageUrl));
      if (res.statusCode != 200) throw Exception('No se pudo descargar la imagen');
      imageBytes = res.bodyBytes;
    } catch (e) {
      throw Exception('Error al obtener la imagen: $e');
    }

    final prompt = TextPart(
      'Eres un asistente de operaciones de la ciudad. Analiza este reporte ciudadano.\n'
      'Categoría indicada: "$category"\n'
      'Descripción del usuario: "$description"\n\n'
      'Por favor, analiza la imagen adjunta y la descripción y genera un reporte breve para el operador:\n'
      '1. ¿Parece un reporte genuino o falso/inválido?\n'
      '2. Severidad estimada (Baja, Media, Alta).\n'
      '3. Resumen breve del problema real que se ve en la imagen y recomendaciones de herramientas o material para llevar.\n'
    );
    
    final imagePart = DataPart('image/jpeg', imageBytes);
    
    final response = await model.generateContent([Content.multi([prompt, imagePart])]);
    return response.text?.trim() ?? 'No se pudo generar un análisis.';
  }

  /// Valida si la imagen proporcionada por el trabajador realmente parece la
  /// solución al problema reportado. Retorna 'VALIDO' o 'INVALIDO'.
  static Future<String> validateResolutionImage(Uint8List imageBytes, String categoryName) async {
    final model = _getModel();
    if (model == null) throw Exception('API Key no configurada');

    final prompt = TextPart(
      'Eres un auditor de infraestructura municipal. Un trabajador de campo afirma haber '
      'resuelto un problema de la categoría: "$categoryName". '
      'Analiza la foto que acaba de tomar del supuesto trabajo terminado. '
      'Si en la imagen se observa un área urbana intervenida, una calle reparada, o evidencia '
      'lógica de que el problema fue solucionado (ej. parche de asfalto, basura recogida), '
      'responde EXACTAMENTE con la palabra "VALIDO". Si la foto es un meme, selfie, habitación interior, '
      'o claramente no muestra ninguna reparación, responde EXACTAMENTE "INVALIDO".'
    );
    final imagePart = DataPart('image/jpeg', imageBytes);

    final response = await model.generateContent([Content.multi([prompt, imagePart])]);
    return response.text?.trim() ?? 'INVALIDO';
  }

  /// Verifica que la imagen sea un documento de identidad real y que el número
  /// coincida. Retorna true si la IA confirma el documento, false si no.
  static Future<bool> verifyIdentityDocument(Uint8List imageBytes, String docTypeName, String docNumber) async {
    final model = _getModel();
    if (model == null) throw Exception('API Key no configurada');

    final prompt = TextPart(
      'Eres un verificador de identidad. El usuario afirma que la imagen es un "$docTypeName" '
      'con el número: "$docNumber". Analiza la imagen. '
      'Si la imagen claramente muestra un documento de identidad oficial (puede ser de cualquier país) '
      'y el número visible en el documento coincide o es similar a "$docNumber", '
      'responde EXACTAMENTE con la palabra "VALIDO". '
      'Si la imagen es una selfie, un paisaje, un documento ilegible, o el número no coincide, '
      'responde EXACTAMENTE "INVALIDO".'
    );
    final imagePart = DataPart('image/jpeg', imageBytes);

    final response = await model.generateContent([Content.multi([prompt, imagePart])]);
    final result = response.text?.trim().toUpperCase() ?? 'INVALIDO';
    return result.contains('VALIDO') && !result.contains('INVALIDO');
  }
}
