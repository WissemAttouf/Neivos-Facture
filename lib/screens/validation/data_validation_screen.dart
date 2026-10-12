// data_validation_screen.dart - Version simplifiée (SANS EXPORT EXCEL)
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/tunisian_invoice_parser.dart';

class DataValidationScreen extends StatefulWidget {
  final Map<String, dynamic> extractedData;
  final double confidence;
  final String rawText;
  final String imagePath;
  final String imageBase64;

  const DataValidationScreen({
    super.key,
    required this.extractedData,
    required this.confidence,
    required this.rawText,
    required this.imagePath,
    required this.imageBase64,
  });

  factory DataValidationScreen.fromParams({
    required Map<String, dynamic> extractedData,
    required double confidence,
    required String rawText,
    required String imagePath,
    required String imageBase64,
    Key? key,
  }) {
    return DataValidationScreen(
      key: key,
      extractedData: extractedData,
      confidence: confidence,
      rawText: rawText,
      imagePath: imagePath,
      imageBase64: imageBase64,
    );
  }

  @override
  State<DataValidationScreen> createState() => _DataValidationScreenState();
}

class _DataValidationScreenState extends State<DataValidationScreen> {
  late Map<String, dynamic> _editableData;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  bool _isSaving = false;
  bool _showRawText = false;
  bool _isAutoSaving = false;
  bool _hasBeenSaved = false;
  bool _isDuplicate = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _printExtractedData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSaveDocument();
    });
  }

  void _initializeData() {
    // Copier les données extraites (qui sont maintenant parfaitement traduites par OCRService)
    _editableData = Map<String, dynamic>.from(widget.extractedData);

    // ✅ CORRECTION : On ne lance le TunisianInvoiceParser QUE si l'API n'a RIEN trouvé du tout.
    // Cela empêche le parser d'écraser les bonnes données de l'API avec des hallucinations.
    if (_editableData['supplier_name'] == null &&
        _editableData['total_ttc'] == null &&
        widget.rawText.isNotEmpty) {
      try {
        final tunisianData = TunisianInvoiceParser.extractTunisianFields(widget.rawText);
        tunisianData.forEach((key, value) {
          if (!_editableData.containsKey(key) || _editableData[key] == null || _editableData[key].toString().isEmpty) {
            _editableData[key] = value;
          }
        });
      } catch (e) {
        print('Erreur parser de secours: $e');
      }
    }

    // Initialiser tous les contrôleurs avec les données OCR
    _initializeControllers();

    // Normaliser les données financières
    _normalizeFinancialData();

    // Calculer les champs manquants
    _calculateMissingFields();
  }

  void _printExtractedData() {
    print('📋 DONNÉES EXTRACTES PAR OCR:');
    print('🎯 Confiance: ${(widget.confidence * 100).toStringAsFixed(1)}%');
    print('📄 Nombre de champs: ${_editableData.length}');

    final importantFields = [
      'invoice_number', 'invoice_date', 'supplier_name', 'client_name',
      'total_ht', 'total_ttc', 'tva_amount', 'tva_rate',
      'net_a_payer', 'retenue_source', 'timbre_fiscal', 'matricule_fiscal'
    ];

    for (final field in importantFields) {
      if (_editableData.containsKey(field)) {
        print('✅ $field: ${_editableData[field]}');
      } else {
        print('❌ $field: NON TROUVÉ');
      }
    }
  }

  void _initializeControllers() {
    final fieldsToDisplay = [
      'invoice_number', 'invoice_date', 'supplier_name', 'supplier_address',
      'supplier_tax_id', 'client_name', 'client_address', 'client_tax_id',
      'matricule_fiscal', 'total_ht', 'total_ttc', 'tva_rate', 'tva_amount',
      'net_a_payer', 'retenue_source', 'timbre_fiscal', 'currency',
      'payment_terms', 'due_date', 'iban', 'phone', 'email', 'description'
    ];

    for (final field in fieldsToDisplay) {
      final value = _editableData[field]?.toString() ?? '';
      _controllers[field] = TextEditingController(text: value);
      _focusNodes[field] = FocusNode();

      _controllers[field]?.addListener(() {
        if (!_isAutoSaving && !_hasBeenSaved) {
          _debouncedAutoSave();
        }
      });
    }
  }

  void _debouncedAutoSave() {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      _autoSaveDocument();
    });
  }

  Future<void> _autoSaveDocument() async {
    if (_isAutoSaving || _hasBeenSaved) return;

    _isAutoSaving = true;

    try {
      for (final entry in _controllers.entries) {
        if (entry.value.text.isNotEmpty) {
          _editableData[entry.key] = entry.value.text.trim();
        }
      }

      _editableData['validation_timestamp'] = DateTime.now().toIso8601String();
      _editableData['ocr_confidence'] = widget.confidence;
      _editableData['validated_by_user'] = true;
      _editableData['image_base64'] = widget.imageBase64;
      _editableData['image_path'] = widget.imagePath;
      _editableData['auto_saved'] = true;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final documentProvider = Provider.of<DocumentProvider>(context, listen: false);

      _removeTemporaryDocument(documentProvider);

      final document = ScannedDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: authProvider.user?.id,
        documentType: DocumentType.invoice,
        filePath: widget.imagePath,
        extractedData: _editableData,
        createdAt: DateTime.now(),
        confidence: widget.confidence,
        language: 'fr',
        processedWith: authProvider.user != null ? 'ocr_api_auto' : 'ocr_guest_auto',
      );

      final success = await documentProvider.saveDocument(document, context);

      if (success) {
        if (mounted) {
          setState(() {
            _hasBeenSaved = true;
            _editableData['saved_to_database'] = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Facture enregistrée automatiquement'), backgroundColor: Colors.green, duration: Duration(seconds: 2)),
          );
        }
      } else if (documentProvider.errorMessage == 'duplicate') {
        if (mounted) {
          setState(() {
            _hasBeenSaved = true;
            _isDuplicate = true;
          });
        }
      }
    } catch (e) {
      print('❌ Erreur auto-save: $e');
    } finally {
      _isAutoSaving = false;
    }
  }

  void _removeTemporaryDocument(DocumentProvider provider) {
    try {
      final tempDocs = provider.documents.where((doc) =>
      doc.extractedData['is_temporary'] == true
      ).toList();

      for (final tempDoc in tempDocs) {
        provider.documents.remove(tempDoc);
      }

      print('🗑️ ${tempDocs.length} document(s) temporaire(s) supprimé(s)');
    } catch (e) {
      print('⚠️ Erreur suppression document temporaire: $e');
    }
  }

  void _normalizeFinancialData() {
    final amountFields = ['total_ht', 'total_ttc', 'tva_amount', 'net_a_payer', 'retenue_source', 'timbre_fiscal'];

    for (final field in amountFields) {
      final controller = _controllers[field];
      if (controller != null) {
        final text = controller.text;
        final cleanedValue = text.replaceAll(' ', '').replaceAll(',', '.');
        controller.text = cleanedValue;
      }
    }

    final dateController = _controllers['invoice_date'];
    if (dateController != null && dateController.text.isNotEmpty) {
      try {
        final dateText = dateController.text;
        DateTime? parsedDate;

        if (dateText.contains(RegExp(r'^\d{4}-\d{2}-\d{2}'))) {
          parsedDate = DateTime.tryParse(dateText);
        } else if (dateText.contains('/')) {
          final parts = dateText.split('/');
          if (parts.length == 3) {
            final day = parts[0].padLeft(2, '0');
            final month = parts[1].padLeft(2, '0');
            final year = parts[2].length == 2 ? '20${parts[2]}' : parts[2];
            final normalized = '$year-$month-$day';
            parsedDate = DateTime.tryParse(normalized);
          }
        }

        if (parsedDate != null) {
          dateController.text = DateFormat('yyyy-MM-dd').format(parsedDate);
        }
      } catch (e) {
        print('⚠️ Erreur normalisation date: $e');
      }
    }
  }

  void _calculateMissingFields() {
    final totalHT = double.tryParse(_controllers['total_ht']?.text ?? '0') ?? 0;
    final totalTTC = double.tryParse(_controllers['total_ttc']?.text ?? '0') ?? 0;
    final tvaRate = double.tryParse(_controllers['tva_rate']?.text ?? '0') ?? 0;
    final tvaAmount = double.tryParse(_controllers['tva_amount']?.text ?? '0') ?? 0;

    if (totalHT > 0 && totalTTC > totalHT && tvaAmount == 0) {
      final calculatedTVA = totalTTC - totalHT;
      _controllers['tva_amount']?.text = calculatedTVA.toStringAsFixed(3);
      _editableData['tva_amount'] = calculatedTVA;
    }

    if (totalHT > 0 && tvaRate == 0 && tvaAmount > 0) {
      final calculatedRate = (tvaAmount / totalHT) * 100;
      _controllers['tva_rate']?.text = calculatedRate.toStringAsFixed(1);
      _editableData['tva_rate'] = calculatedRate;
    }

    if ((_controllers['net_a_payer']?.text.isEmpty ?? true) && totalTTC > 0) {
      final retenue = double.tryParse(_controllers['retenue_source']?.text ?? '0') ?? 0;
      final timbre = double.tryParse(_controllers['timbre_fiscal']?.text ?? '0') ?? 0;
      final netAPayer = totalTTC - retenue - timbre;

      if (netAPayer > 0) {
        _controllers['net_a_payer']?.text = netAPayer.toStringAsFixed(3);
        _editableData['net_a_payer'] = netAPayer;
        _editableData['net_a_payer_calculated'] = true;
      }
    }
  }

  void _calculateDependentFields() {
    final totalHT = double.tryParse(_controllers['total_ht']?.text ?? '0') ?? 0;
    final tvaRate = double.tryParse(_controllers['tva_rate']?.text ?? '0') ?? 0;

    if (totalHT > 0 && tvaRate > 0) {
      final tvaAmount = totalHT * (tvaRate / 100);
      final totalTTC = totalHT + tvaAmount;

      _controllers['tva_amount']?.text = tvaAmount.toStringAsFixed(3);
      _controllers['total_ttc']?.text = totalTTC.toStringAsFixed(3);

      _editableData['tva_amount'] = tvaAmount;
      _editableData['total_ttc'] = totalTTC;

      final retenue = double.tryParse(_controllers['retenue_source']?.text ?? '0') ?? 0;
      final timbre = double.tryParse(_controllers['timbre_fiscal']?.text ?? '0') ?? 0;
      final netAPayer = totalTTC - retenue - timbre;

      if (netAPayer > 0) {
        _controllers['net_a_payer']?.text = netAPayer.toStringAsFixed(3);
        _editableData['net_a_payer'] = netAPayer;
      }
    }
  }

  Future<void> _saveDocument() async {
    if (_isSaving) return;

    if (_hasBeenSaved || _isDuplicate) {
      Navigator.pop(context, !_isDuplicate);
      return;
    }

    setState(() => _isSaving = true);

    try {
      for (final entry in _controllers.entries) {
        _editableData[entry.key] = entry.value.text.trim();
      }

      _editableData['validation_timestamp'] = DateTime.now().toIso8601String();
      _editableData['ocr_confidence'] = widget.confidence;
      _editableData['validated_by_user'] = true;
      _editableData['image_base64'] = widget.imageBase64;
      _editableData['image_path'] = widget.imagePath;
      _editableData['manually_saved'] = true;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final documentProvider = Provider.of<DocumentProvider>(context, listen: false);

      _removeTemporaryDocument(documentProvider);

      final document = ScannedDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: authProvider.user?.id,
        documentType: DocumentType.invoice,
        filePath: widget.imagePath,
        extractedData: _editableData,
        createdAt: DateTime.now(),
        confidence: widget.confidence,
        language: 'fr',
        processedWith: authProvider.user != null ? 'ocr_api_manual' : 'ocr_guest_manual',
      );

      final success = await documentProvider.saveDocument(document, context);

      if (success && mounted) {
        _hasBeenSaved = true;
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.pop(context, true);
      } else if (documentProvider.errorMessage == 'duplicate') {
        if (mounted) {
          setState(() {
            _hasBeenSaved = true;
            _isDuplicate = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('Validation des données OCR'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showRawText ? Icons.text_fields : Icons.code, color: Colors.white),
            onPressed: () => setState(() => _showRawText = !_showRawText),
            tooltip: 'Afficher texte brut',
          ),
        ],
      ),
      body: _showRawText ? _buildRawTextView(isDarkMode) : _buildValidationView(isDarkMode),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildFloatingActionButton() {
    return FloatingActionButton.extended(
      onPressed: (_isSaving) ? null : _saveDocument,
      icon: _isSaving
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
          : Icon(_isDuplicate ? Icons.skip_next : (_hasBeenSaved ? Icons.arrow_forward : Icons.save)),
      label: Text(
        _isSaving ? 'Enregistrement...' :
        _isDuplicate ? 'Passer (Cette Facture existe déja)' :
        _hasBeenSaved ? 'Continuer' : 'Confirmer l\'enregistrement',
      ),
      backgroundColor: _isDuplicate ? Colors.orange : (_hasBeenSaved ? Colors.green : (_isSaving ? Colors.grey : Colors.green)),
    );
  }

  Widget _buildValidationView(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConfidenceHeader(),
          const SizedBox(height: 20),
          _buildSection('Informations générales', Icons.info, Colors.blue, isDarkMode,
              ['invoice_number', 'invoice_date', 'matricule_fiscal']),
          const SizedBox(height: 20),
          _buildSection('Fournisseur', Icons.business, Colors.purple, isDarkMode,
              ['supplier_name', 'supplier_address', 'supplier_tax_id', 'phone', 'email']),
          const SizedBox(height: 20),
          _buildSection('Client', Icons.person, Colors.orange, isDarkMode,
              ['client_name', 'client_address', 'client_tax_id']),
          const SizedBox(height: 20),
          _buildSection('Montants financiers', Icons.attach_money, Colors.green, isDarkMode,
              ['total_ht', 'tva_rate', 'tva_amount', 'total_ttc', 'retenue_source', 'timbre_fiscal', 'net_a_payer', 'currency']),
          const SizedBox(height: 20),
          _buildSection('Informations supplémentaires', Icons.note_add, Colors.teal, isDarkMode,
              ['payment_terms', 'due_date', 'iban', 'description']),
          const SizedBox(height: 20),

          if (_hasBeenSaved)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.green.withOpacity(0.2) : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Cette facture a été automatiquement enregistrée dans vos documents.',
                      style: TextStyle(
                        color: isDarkMode ? Colors.green[200] : Colors.green[800],
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildConfidenceHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final confidencePercent = (widget.confidence * 100).toStringAsFixed(1);
    Color confidenceColor;

    if (widget.confidence >= 0.8) {
      confidenceColor = Colors.green;
    } else if (widget.confidence >= 0.6) {
      confidenceColor = Colors.orange;
    } else {
      confidenceColor = Colors.red;
    }

    return Card(
      elevation: 3,
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: confidenceColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Analyse OCR complétée',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: confidenceColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: widget.confidence,
              backgroundColor: confidenceColor.withOpacity(0.2),
              color: confidenceColor,
              minHeight: 8,
            ),
            const SizedBox(height: 10),
            Text(
              'Confiance: $confidencePercent%',
              style: TextStyle(
                fontSize: 14,
                color: confidenceColor,
                fontWeight: FontWeight.bold,
              ),
            ),

            if (_isAutoSaving)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Enregistrement automatique en cours...',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Color color, bool isDarkMode, List<String> fields) {
    final visibleFields = fields.where((field) =>
    _controllers.containsKey(field) && (_controllers[field]?.text.isNotEmpty ?? false)
    ).toList();

    if (visibleFields.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...visibleFields.map((field) => _buildFieldRow(field, isDarkMode)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(String fieldKey, bool isDarkMode) {
    final controller = _controllers[fieldKey];
    final focusNode = _focusNodes[fieldKey];

    if (controller == null || focusNode == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          labelText: _getFieldLabel(fieldKey),
          labelStyle: TextStyle(
            color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            fontSize: 14,
          ),
          hintStyle: TextStyle(
            color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        ),
        onChanged: (value) {
          _editableData[fieldKey] = value.trim();
          if (fieldKey == 'total_ht' || fieldKey == 'tva_rate') {
            _calculateDependentFields();
          }
        },
      ),
    );
  }

  Widget _buildRawTextView(bool isDarkMode) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Texte brut extrait par OCR:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
            ),
            child: SelectableText(
              widget.rawText.isNotEmpty ? widget.rawText : 'Aucun texte extrait',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Données structurées:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          ..._editableData.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 120,
                  child: Text(
                    '${entry.key}:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.grey[300] : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value.toString(),
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  String _getFieldLabel(String fieldName) {
    final labels = {
      'invoice_number': 'Numéro de facture',
      'invoice_date': 'Date de facture',
      'supplier_name': 'Nom du fournisseur',
      'supplier_address': 'Adresse fournisseur',
      'supplier_tax_id': 'Matricule fiscal fournisseur',
      'client_name': 'Nom du client',
      'client_address': 'Adresse client',
      'client_tax_id': 'Matricule fiscal client',
      'matricule_fiscal': 'Matricule fiscal',
      'total_ht': 'Total HT',
      'total_ttc': 'Total TTC',
      'tva_rate': 'Taux TVA (%)',
      'tva_amount': 'Montant TVA',
      'net_a_payer': 'Net à payer',
      'retenue_source': 'Retenue à la source',
      'timbre_fiscal': 'Timbre fiscal',
      'currency': 'Devise',
      'payment_terms': 'Conditions de paiement',
      'due_date': 'Date d\'échéance',
      'iban': 'IBAN',
      'phone': 'Téléphone',
      'email': 'Email',
      'description': 'Description',
    };
    return labels[fieldName] ?? fieldName;
  }

  @override
  void dispose() {
    if (_debounceTimer != null) {
      _debounceTimer!.cancel();
    }

    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }
}

