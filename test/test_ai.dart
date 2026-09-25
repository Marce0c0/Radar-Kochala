import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:radar_kochala/services/ai_validation_service.dart';

void main() async {
  try {
    print('Cargando .env...');
    final envVars = File('.env').readAsStringSync();
    dotenv.testLoad(fileInput: envVars);
    
    // Imagen dummy en JPEG (1x1 blanco)
    final bytes = Uint8List.fromList([255, 216, 255, 224, 0, 16, 74, 70, 73, 70, 0, 1, 1, 1, 0, 72, 0, 72, 0, 0, 255, 219, 0, 67, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 217]);
    
    print('Enviando imagen a Gemini...');
    final result = await AiValidationService.validateLocalImage(bytes, "bache");
    print('RESULTADO AI: \$result');
  } catch (e) {
    print('ERROR AI: \$e');
  }
}
