// lib/services/image_editor_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class EditCommand {
  final String imagePath;
  final double brightness;
  final double contrast;
  final int rotation;
  final bool sharpen;

  EditCommand({
    required this.imagePath,
    required this.brightness,
    required this.contrast,
    required this.rotation,
    required this.sharpen,
  });
}

class ImageEditorService {

  /// Traite l'image dans un Isolate séparé pour ne pas bloquer l'interface
  static Future<File> processImage(EditCommand command) async {
    return await compute(_processImageIsolate, command);
  }

  /// Fonction exécutée en arrière-plan
  static Future<File> _processImageIsolate(EditCommand command) async {
    try {
      final file = File(command.imagePath);
      final bytes = await file.readAsBytes();

      // 1. Décoder l'image
      img.Image? image = img.decodeImage(bytes);
      if (image == null) throw Exception('Impossible de décoder l\'image');

      // 2. Rotation
      if (command.rotation != 0) {
        image = img.copyRotate(image, angle: command.rotation);
      }

      // 3. Calcul de la formule de couleur (Exactement comme l'UI ColorMatrix)
      double contrast = command.contrast;
      double brightness = command.brightness;
      double t = (1.0 - contrast) / 2.0 * 255.0;
      double b = brightness * 255.0;
      double add = t + b;

      // 4. Appliquer les couleurs manuellement pixel par pixel (Très sécurisé)
      for (var p in image) {
        num r = p.r * contrast + add;
        num g = p.g * contrast + add;
        num b_val = p.b * contrast + add;

        // Clamper les valeurs entre 0 et 255
        p.r = r.clamp(0, 255);
        p.g = g.clamp(0, 255);
        p.b = b_val.clamp(0, 255);

        // ✅ CORRECTION DU BUG NOIR : Forcer l'opacité à 100% (255)
        p.a = 255;
      }

      // 5. Réduction du flou (Sharpen)
      if (command.sharpen) {
        image = img.convolution(image, filter: [
          0, -1,  0,
          -1,  5, -1,
          0, -1,  0
        ]);

        // ✅ RE-CORRECTION : La convolution peut recasser l'Alpha, on le re-force
        for (var p in image) {
          p.a = 255;
        }
      }

      // 6. Sauvegarder dans un fichier temporaire
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/edited_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');

      // Encodage en JPG (qualité 90 est parfaite pour l'OCR)
      await tempFile.writeAsBytes(img.encodeJpg(image, quality: 90));

      return tempFile;
    } catch (e) {
      print('❌ Erreur Isolate ImageEditor: $e');
      // En cas d'erreur, on retourne l'image originale pour ne pas bloquer l'utilisateur
      return File(command.imagePath);
    }
  }
}
