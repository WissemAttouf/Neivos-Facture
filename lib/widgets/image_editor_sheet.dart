// lib/widgets/image_editor_sheet.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/image_editor_service.dart';

class ImageEditorSheet extends StatefulWidget {
  final File imageFile;
  final Function(File) onImageEdited;

  const ImageEditorSheet({
    super.key,
    required this.imageFile,
    required this.onImageEdited,
  });

  @override
  State<ImageEditorSheet> createState() => _ImageEditorSheetState();
}

class _ImageEditorSheetState extends State<ImageEditorSheet> {
  bool _isProcessing = false;

  // Paramètres d'édition
  double _brightness = 0.0; // -1.0 à 1.0
  double _contrast = 1.0;   // 0.0 à 2.0
  int _rotation = 0;        // 0, 90, 180, 270
  bool _sharpen = false;    // Filtre de netteté

  // Applique les paramètres optimaux pour l'OCR
  void _applyAIEnhancement() {
    setState(() {
      _brightness = 0.1;  // Légèrement plus clair
      _contrast = 1.5;    // Contraste élevé pour noircir le texte
      _sharpen = true;    // Activer la netteté
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ Amélioration IA appliquée pour l\'OCR'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // Calcul de la matrice de couleur pour l'aperçu en temps réel
  List<double> _calculateColorMatrix() {
    double t = (1.0 - _contrast) / 2.0 * 255.0;
    double b = _brightness * 255.0;

    return [
      _contrast, 0, 0, 0, t + b,
      0, _contrast, 0, 0, t + b,
      0, 0, _contrast, 0, t + b,
      0, 0, 0, 1, 0,
    ];
  }

  Future<void> _saveAndReturn() async {
    setState(() => _isProcessing = true);

    try {
      // Si aucune modification n'a été faite, on retourne l'original
      if (_brightness == 0.0 && _contrast == 1.0 && _rotation == 0 && !_sharpen) {
        widget.onImageEdited(widget.imageFile);
        Navigator.pop(context);
        return;
      }

      // Lancer le traitement lourd en arrière-plan
      final command = EditCommand(
        imagePath: widget.imageFile.path,
        brightness: _brightness,
        contrast: _contrast,
        rotation: _rotation,
        sharpen: _sharpen,
      );

      final editedFile = await ImageEditorService.processImage(command);

      widget.onImageEdited(editedFile);
      if (mounted) Navigator.pop(context);

    } catch (e) {
      print('Erreur lors de la sauvegarde: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Poignée (Handle)
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // En-tête
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Améliorer la facture',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _applyAIEnhancement,
                  icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                  label: const Text('Auto IA', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ],
            ),
          ),

          // Aperçu de l'image (Temps réel)
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(_calculateColorMatrix()),
                    child: Transform.rotate(
                      angle: _rotation * math.pi / 180,
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Contrôles
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                // Outils rapides (Rotation & Flou)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildToolButton(
                      icon: Icons.rotate_left,
                      label: 'Pivoter',
                      onTap: () => setState(() => _rotation = (_rotation - 90) % 360),
                    ),
                    _buildToolButton(
                      icon: _sharpen ? Icons.blur_on : Icons.blur_off,
                      label: 'Netteté',
                      isActive: _sharpen,
                      onTap: () => setState(() => _sharpen = !_sharpen),
                    ),
                    _buildToolButton(
                      icon: Icons.restore,
                      label: 'Réinitialiser',
                      onTap: () => setState(() {
                        _brightness = 0.0;
                        _contrast = 1.0;
                        _rotation = 0;
                        _sharpen = false;
                      }),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Slider Contraste
                _buildSliderRow(
                  icon: Icons.contrast,
                  label: 'Contraste',
                  value: _contrast,
                  min: 0.5,
                  max: 2.0,
                  onChanged: (val) => setState(() => _contrast = val),
                ),

                // Slider Luminosité
                _buildSliderRow(
                  icon: Icons.light_mode,
                  label: 'Luminosité',
                  value: _brightness,
                  min: -0.5,
                  max: 0.5,
                  onChanged: (val) => setState(() => _brightness = val),
                ),

                const SizedBox(height: 16),

                // Boutons d'action finaux
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _saveAndReturn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Text(
                          'VALIDER L\'IMAGE',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final color = isActive ? Theme.of(context).primaryColor : Colors.grey[600];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: isActive ? FontWeight.bold : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow({
    required IconData icon,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: Theme.of(context).primaryColor,
            inactiveColor: Colors.grey[300],
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
