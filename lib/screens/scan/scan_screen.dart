// scan_screen.dart - VERSION AVEC PRISE DE PHOTOS MULTIPLES
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/ocr_service.dart';
import '../../services/api_service.dart';
import '../../widgets/particle_background.dart';
import '../../widgets/image_editor_sheet.dart';
import '../validation/data_validation_screen.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _permissionRequestInProgress = false;
  bool _isProcessing = false;
  bool _isTestingApi = false;
  double _processingProgress = 0.0;
  String? _errorMessage;
  OCRService? _ocrService;
  String _apiStatus = 'Prêt';
  String _ocrInfo = 'API NEIVOS OCR: http://37.60.239.139:8775';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _requestPermissions();
    }
    _initializeServices();
    _testApiConnection();
  }

  void _initializeServices() {
    try {
      final apiService = ApiService(baseUrl: '10.123.109.205:8086');
      _ocrService = OCRService(apiService: apiService);
      print('✅ Services OCR initialisés');
    } catch (e) {
      print('❌ Erreur initialisation services: $e');
    }
  }

  Future<void> _testApiConnection() async {
    if (_isTestingApi) return;

    setState(() {
      _isTestingApi = true;
      _apiStatus = 'Test en cours...';
    });

    print('🧪 Test connexion API OCR...');

    try {
      final apiService = ApiService(baseUrl: '10.123.109.205:8086');
      final isConnected = await apiService.testOcrConnection();

      setState(() {
        _apiStatus = isConnected ? '✅ API CONNECTÉE' : '❌ API HORS LIGNE';
      });

      if (isConnected) {
        print('🎉 API OCR NEIVOS est opérationnelle!');
      } else {
        print('⚠️ API OCR NEIVOS ne répond pas');
      }
    } catch (e) {
      print('❌ Erreur test API: $e');
      setState(() {
        _apiStatus = '❌ ERREUR DE CONNEXION';
      });
    } finally {
      setState(() {
        _isTestingApi = false;
      });
    }
  }

  Future<bool> _requestPermissions() async {
    if (_permissionRequestInProgress) return false;

    _permissionRequestInProgress = true;
    try {
      final cameraStatus = await Permission.camera.request();
      final photosStatus = await Permission.photos.request();

      if (cameraStatus.isGranted && photosStatus.isGranted) {
        return true;
      } else {
        _showSnackBar(
          'Veuillez autoriser l\'accès à la caméra et aux photos',
          Colors.orange,
        );
        await Future.delayed(const Duration(seconds: 2));
        await openAppSettings();
        return false;
      }
    } catch (e) {
      _showSnackBar('Erreur permissions: ${e.toString()}', Colors.red);
      return false;
    } finally {
      _permissionRequestInProgress = false;
    }
  }

  // ============ MÉTHODE POUR AFFICHER L'ÉDITEUR D'IMAGE ============

  Future<File?> _showImageEditor(File imageFile) async {
    File? result;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ImageEditorSheet(
        imageFile: imageFile,
        onImageEdited: (editedFile) {
          result = editedFile;
        },
      ),
    );

    return result;
  }

  // ============ DIALOGUE POUR LES PHOTOS MULTIPLES ============

  Future<bool?> _showMultiPhotoDialog(File imageFile, int count) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.photo_library, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            Text('Facture $count ajoutée'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                image: DecorationImage(
                  image: FileImage(imageFile),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Voulez-vous prendre une autre photo ou lancer l\'analyse de toutes les factures capturées ?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, true), // true = continuer
            icon: const Icon(Icons.camera_alt, size: 18),
            label: const Text('Ajouter'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, false), // false = analyser
            icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            label: const Text('Analyser tout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ============ MÉTHODES DE SCAN ============

  Future<void> _pickFromGallery() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      _showSnackBar('Veuillez vous connecter pour scanner une facture', Colors.orange);
      Navigator.pushNamed(context, '/login');
      return;
    }

    if (!kIsWeb && !(await _requestPermissions())) return;

    try {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );

      if (images.isNotEmpty && mounted) {
        List<File> filesToProcess = images.map((xfile) => File(xfile.path)).toList();

        setState(() {
          _selectedImage = filesToProcess.first;
          _errorMessage = null;
        });

        await _processMultipleImagesWithYourAPI(filesToProcess);
      }
    } catch (e) {
      _showSnackBar('Erreur: ${e.toString()}', Colors.red);
    }
  }

  // ✅ NOUVELLE VERSION : PRISE DE PHOTOS MULTIPLES
  Future<void> _takePhoto() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      _showSnackBar('Veuillez vous connecter pour scanner une facture', Colors.orange);
      Navigator.pushNamed(context, '/login');
      return;
    }

    if (!kIsWeb && !(await _requestPermissions())) return;

    List<File> capturedImages = [];
    bool takeAnother = true;

    // Boucle pour prendre plusieurs photos
    while (takeAnother) {
      try {
        final image = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          maxWidth: 1920,
          maxHeight: 1080,
        );

        if (image != null && mounted) {
          final originalFile = File(image.path);

          // Afficher l'éditeur d'image (IA)
          final editedFile = await _showImageEditor(originalFile);

          if (editedFile != null) {
            capturedImages.add(editedFile);

            // Demander si l'utilisateur veut continuer ou analyser
            final result = await _showMultiPhotoDialog(editedFile, capturedImages.length);

            if (result == null) {
              takeAnother = false; // Dialog fermé sans choix
            } else {
              takeAnother = result; // true = reprendre photo, false = analyser
            }
          } else {
            takeAnother = false; // Édition annulée
          }
        } else {
          takeAnother = false; // Caméra annulée
        }
      } catch (e) {
        _showSnackBar('Erreur caméra: ${e.toString()}', Colors.red);
        takeAnother = false;
      }
    }

    // Si on a capturé au moins une image, on lance l'analyse multiple
    if (capturedImages.isNotEmpty && mounted) {
      setState(() {
        _selectedImage = capturedImages.first;
        _errorMessage = null;
      });
      await _processMultipleImagesWithYourAPI(capturedImages);
    }
  }

  Future<void> _processMultipleImagesWithYourAPI(List<File> imageFiles) async {
    if (imageFiles.isEmpty || _ocrService == null) return;

    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _errorMessage = null;
    });

    try {
      _updateProgress(0.1, 'Chargement des ${imageFiles.length} images...');
      await Future.delayed(const Duration(milliseconds: 300));

      _updateProgress(0.3, 'Envoi à l\'API OCR NEIVOS...');

      final documents = await _ocrService!.processMultipleDocuments(imageFiles);

      if (documents.isNotEmpty) {
        _updateProgress(0.9, 'Préparation de la validation...');
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }

        int successCount = 0;

        for (int i = 0; i < documents.length; i++) {
          if (!mounted) break;

          final doc = documents[i];
          final file = imageFiles[i];

          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);

          await _saveDocumentTemporarily(doc, base64Image);

          if (mounted) {
            if (documents.length > 1) {
              _showSnackBar('Validation facture ${i + 1} sur ${documents.length}', Colors.blue);
            }

            final savedDocument = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DataValidationScreen.fromParams(
                  extractedData: doc.extractedData,
                  confidence: doc.confidence,
                  rawText: doc.extractedData['raw_text'] ?? '',
                  imagePath: file.path,
                  imageBase64: base64Image,
                ),
              ),
            );

            if (savedDocument == true) {
              successCount++;
            }
          }
        }

        if (mounted) {
          _showSnackBar('Terminé ! $successCount/${documents.length} factures sauvegardées.', Colors.green);
          _resetScan();
        }
      } else {
        throw Exception('L\'OCR n\'a retourné aucun résultat');
      }
    } catch (e) {
      print('❌ Erreur traitement: $e');
      setState(() {
        _errorMessage = 'Erreur: ${e.toString().replaceAll("Exception: ", "")}';
      });
      _showSnackBar(_errorMessage!, Colors.red);
    } finally {
      if (mounted && _isProcessing) {
        setState(() {
          _isProcessing = false;
          _processingProgress = 0.0;
        });
      }
    }
  }

  Future<void> _processImageWithYourAPI() async {
    if (_selectedImage == null || _ocrService == null) return;
    // Si l'utilisateur clique sur "Extraire" manuellement, on traite l'image sélectionnée
    await _processMultipleImagesWithYourAPI([_selectedImage!]);
  }

  Future<void> _saveDocumentTemporarily(ScannedDocument document, String base64Image) async {
    try {
      final documentProvider = Provider.of<DocumentProvider>(context, listen: false);

      final tempData = Map<String, dynamic>.from(document.extractedData);
      tempData['image_base64'] = base64Image;
      tempData['image_path'] = _selectedImage?.path ?? '';
      tempData['is_temporary'] = true;

      final tempDocument = ScannedDocument(
        id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: document.userId,
        documentType: DocumentType.invoice,
        filePath: _selectedImage?.path ?? '',
        extractedData: tempData,
        createdAt: DateTime.now(),
        confidence: document.confidence,
        language: 'fr',
        processedWith: 'ocr_temp',
      );

      documentProvider.addDocument(tempDocument);
      print('📝 Document temporaire créé pour validation');

    } catch (e) {
      print('⚠️ Erreur sauvegarde temporaire: $e');
    }
  }

  void _updateProgress(double progress, String message) {
    if (mounted) {
      setState(() {
        _processingProgress = progress;
      });
      print('📈 $message (${(progress * 100).toInt()}%)');
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _resetScan() {
    setState(() {
      _selectedImage = null;
      _isProcessing = false;
      _processingProgress = 0.0;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isLoggedIn = authProvider.isLoggedIn;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/ssvg.PNG',
              height: 40,
              width: 40,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.receipt, size: 30),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'SCAN DE FACTURE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          if (!isLoggedIn)
            TextButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.login, color: Colors.white),
              label: const Text('Connexion', style: TextStyle(color: Colors.white)),
            ),
          if (_selectedImage != null && !_isProcessing)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetScan,
              tooltip: 'Nouveau scan',
            ),
        ],
      ),
      body: Stack(
        children: [
          ParticleBackground(isDarkMode: isDarkMode),
          if (_isTestingApi) _buildTestingOverlay(),
          _isProcessing
              ? _buildProcessingView()
              : _selectedImage != null
              ? _buildImagePreview()
              : _buildScanOptions(isLoggedIn),
        ],
      ),
    );
  }

  Widget _buildTestingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              'Test de connexion API...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _apiStatus,
              style: TextStyle(
                color: _apiStatus.contains('✅') ? Colors.green : Colors.orange,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanOptions(bool isLoggedIn) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Icon(
            Icons.receipt_long,
            size: 100,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(height: 20),
          Text(
            'Scanner une facture',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Importez une facture ou prenez une photo\nL\'analyse sera effectuée automatiquement',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ),
          const SizedBox(height: 30),
          _buildApiStatusCard(),
          const SizedBox(height: 40),

          if (!isLoggedIn)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 40),
                  const SizedBox(height: 10),
                  Text(
                    'Vous devez être connecté pour scanner des factures',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    ),
                    child: const Text('SE CONNECTER'),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              width: 280,
              child: ElevatedButton.icon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.photo_library),
                label: const Text('Choisir depuis la galerie'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: 280,
              child: ElevatedButton.icon(
                onPressed: _takePhoto,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Prendre une photo'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],

          const SizedBox(height: 40),
          _buildInfoCards(),
        ],
      ),
    );
  }

  Widget _buildApiStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (_isTestingApi) {
      statusColor = Colors.blue;
      statusIcon = Icons.refresh;
      statusText = 'Test en cours...';
    } else if (_apiStatus.contains('✅')) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = 'OCR CONNECTÉE';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
      statusText = 'OCR HORS LIGNE';
    }

    return GestureDetector(
      onTap: _testApiConnection,
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor, width: 2),
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VOTRE OCR NEIVOS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Ici vous trouvez La bonne resultat de votre OCR',
                    style: TextStyle(
                      color: statusColor.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blue, size: 30),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Extraction automatique',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Tous Les informations necessaires sont automatiquement extraites',
                      style: TextStyle(
                        color: Colors.blue.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green, width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.tips_and_updates, color: Colors.green, size: 30),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pour une meilleure extraction',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '• Image nette et bien éclairée\n• Facture entièrement visible\n• Texte clair et lisible\n• Formats JPG ou PNG',
                      style: TextStyle(
                        color: Colors.green.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImagePreview() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _selectedImage != null
                    ? Image.file(
                  _selectedImage!,
                  fit: BoxFit.contain,
                  width: double.infinity,
                )
                    : Center(
                  child: Text(
                    'Image non disponible',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _processImageWithYourAPI,
                  icon: _isProcessing
                      ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _isProcessing
                        ? 'Analyse en cours...'
                        : 'EXTRAIRE AVEC VOTRE OCR',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: _isProcessing
                        ? Colors.grey
                        : Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _pickFromGallery,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Changer'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blueGrey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isProcessing ? null : _resetScan,
                      icon: const Icon(Icons.close),
                      label: const Text('Annuler'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _processingProgress,
                    strokeWidth: 10,
                    color: Theme.of(context).primaryColor,
                    backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.2),
                  ),
                  Text(
                    '${(_processingProgress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Analyse OCR en cours',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Extraction via VOTRE API OCR NEIVOS',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 20),
            _buildProcessingSteps(),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingSteps() {
    final steps = [
      'Envoi image à API',
      'Reconnaissance texte',
      'Extraction données',
      'Structuration',
      'Validation',
    ];

    final currentStep = (_processingProgress * steps.length).floor();

    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isCurrent
                ? Theme.of(context).primaryColor.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isCompleted ? Colors.green : Colors.grey,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  step,
                  style: TextStyle(
                    fontSize: 14,
                    color: isCurrent
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              if (isCurrent)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
