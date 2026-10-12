// data_validation_screen.dart - ÉCRAN DE VALIDATION AVEC REMPLISSAGE AUTO
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

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

  // Constructeur alternatif
  factory DataValidationScreen.fromParams({
    required Map<String, dynamic> extractedData,
    required double confidence,
    required String rawText,
    required String imagePath,
    required String imageBase64,
  }) {
    return DataValidationScreen(
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

  @override
  void initState() {
    super.initState();
    _initializeData();
    _printExtractedData();
  }

  void _initializeData() {
    // Copier les données extraites
    _editableData = Map<String, dynamic>.from(widget.extractedData);

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
    // Liste des champs à afficher dans l'interface
    final fieldsToDisplay = [
      // Informations générales
      'invoice_number', 'invoice_date', 'supplier_name', 'supplier_address',
      'supplier_tax_id', 'client_name', 'client_address', 'client_tax_id',
      'matricule_fiscal',

      // Montants financiers
      'total_ht', 'total_ttc', 'tva_rate', 'tva_amount',
      'net_a_payer', 'retenue_source', 'timbre_fiscal',

      // Autres informations
      'currency', 'payment_terms', 'due_date', 'iban',
      'phone', 'email', 'description'
    ];

    for (final field in fieldsToDisplay) {
      // Créer le contrôleur avec la valeur OCR
      final value = _editableData[field]?.toString() ?? '';
      _controllers[field] = TextEditingController(text: value);
      _focusNodes[field] = FocusNode();

      print('📝 Contrôleur $field: "$value"');
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

    // Normaliser la date
    final dateController = _controllers['invoice_date'];
    if (dateController != null && dateController.text.isNotEmpty) {
      try {
        final dateText = dateController.text;
        DateTime? parsedDate;

        // Essayer différents formats
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
        } else if (dateText.contains('-')) {
          final parts = dateText.split('-');
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
    // Calculer TVA si manquant
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

    // Calculer net à payer si manquant
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

  Future<void> _saveDocument() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      // Collecter les données mises à jour
      for (final entry in _controllers.entries) {
        _editableData[entry.key] = entry.value.text.trim();
      }

      // Ajouter des métadonnées
      _editableData['validation_timestamp'] = DateTime.now().toIso8601String();
      _editableData['ocr_confidence'] = widget.confidence;
      _editableData['validated_by_user'] = true;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final documentProvider = Provider.of<DocumentProvider>(context, listen: false);

      if (authProvider.user == null) {
        throw Exception('Utilisateur non authentifié');
      }

      final document = ScannedDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        documentType: DocumentType.invoice,
        filePath: widget.imagePath,
        extractedData: _editableData,
        createdAt: DateTime.now(),
        confidence: widget.confidence,
        language: 'fr',
      );

      final success = await documentProvider.saveDocument(document, context);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Facture enregistrée avec succès !'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        await Future.delayed(const Duration(milliseconds: 1500));

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(documentProvider.errorMessage ?? 'Erreur inconnue');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Validation des données OCR'),
        backgroundColor: AppTheme.backgroundColor,
        actions: [
          IconButton(
            icon: Icon(_showRawText ? Icons.text_fields : Icons.code),
            onPressed: () => setState(() => _showRawText = !_showRawText),
            tooltip: 'Afficher texte brut',
          ),
        ],
      ),
      body: _showRawText ? _buildRawTextView() : _buildValidationView(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveDocument,
        icon: _isSaving
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
            : const Icon(Icons.save),
        label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
        backgroundColor: _isSaving ? Colors.grey : Colors.green,
      ),
    );
  }

  Widget _buildValidationView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // EN-TÊTE AVEC CONFIANCE
          _buildConfidenceHeader(),

          const SizedBox(height: 20),

          // INFORMATIONS GÉNÉRALES
          _buildSection(
            title: 'Informations générales',
            icon: Icons.info,
            color: Colors.blue,
            fields: [
              'invoice_number',
              'invoice_date',
              'matricule_fiscal',
            ],
          ),

          const SizedBox(height: 20),

          // FOURNISSEUR
          _buildSection(
            title: 'Fournisseur',
            icon: Icons.business,
            color: Colors.purple,
            fields: [
              'supplier_name',
              'supplier_address',
              'supplier_tax_id',
              'phone',
              'email',
            ],
          ),

          const SizedBox(height: 20),

          // CLIENT
          _buildSection(
            title: 'Client',
            icon: Icons.person,
            color: Colors.orange,
            fields: [
              'client_name',
              'client_address',
              'client_tax_id',
            ],
          ),

          const SizedBox(height: 20),

          // MONTANTS FINANCIERS
          _buildSection(
            title: 'Montants financiers',
            icon: Icons.attach_money,
            color: Colors.green,
            fields: [
              'total_ht',
              'tva_rate',
              'tva_amount',
              'total_ttc',
              'retenue_source',
              'timbre_fiscal',
              'net_a_payer',
              'currency',
            ],
          ),

          const SizedBox(height: 20),

          // INFORMATIONS SUPPLÉMENTAIRES
          _buildSection(
            title: 'Informations supplémentaires',
            icon: Icons.note_add,
            color: Colors.teal,
            fields: [
              'payment_terms',
              'due_date',
              'iban',
              'description',
            ],
          ),

          const SizedBox(height: 80), // Espace pour le FAB
        ],
      ),
    );
  }

  Widget _buildConfidenceHeader() {
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
            if (_editableData.containsKey('saved_to_database') && _editableData['saved_to_database'] == true)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.cloud_done, color: Colors.green, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      'Données déjà sauvegardées',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<String> fields,
  }) {
    final visibleFields = fields.where((field) =>
    _controllers.containsKey(field) &&
        (_controllers[field]?.text.isNotEmpty ?? false)
    ).toList();

    if (visibleFields.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
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
            ...visibleFields.map((field) =>
                _buildFieldRow(_getFieldLabel(field), field)
            ).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(String label, String fieldKey) {
    final controller = _controllers[fieldKey];
    final focusNode = _focusNodes[fieldKey];

    if (controller == null || focusNode == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: _getFieldIcon(fieldKey),
        ),
        onChanged: (value) {
          // Mettre à jour les données lors de la modification
          _editableData[fieldKey] = value.trim();

          // Recalculer les champs dépendants
          if (fieldKey == 'total_ht' || fieldKey == 'tva_rate') {
            _calculateDependentFields();
          }
        },
      ),
    );
  }

  Widget? _getFieldIcon(String fieldKey) {
    final iconData = {
      'invoice_number': Icons.numbers,
      'invoice_date': Icons.calendar_today,
      'supplier_name': Icons.business,
      'client_name': Icons.person,
      'total_ht': Icons.money,
      'total_ttc': Icons.monetization_on,
      'net_a_payer': Icons.account_balance_wallet,
    };

    if (iconData.containsKey(fieldKey)) {
      return Icon(iconData[fieldKey], size: 20);
    }

    return null;
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

      // Recalculer net à payer
      final retenue = double.tryParse(_controllers['retenue_source']?.text ?? '0') ?? 0;
      final timbre = double.tryParse(_controllers['timbre_fiscal']?.text ?? '0') ?? 0;
      final netAPayer = totalTTC - retenue - timbre;

      if (netAPayer > 0) {
        _controllers['net_a_payer']?.text = netAPayer.toStringAsFixed(3);
        _editableData['net_a_payer'] = netAPayer;
      }
    }
  }

  Widget _buildRawTextView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Texte brut extrait par OCR:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: SelectableText(
              widget.rawText.isNotEmpty ? widget.rawText : 'Aucun texte extrait',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Données structurées:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ..._editableData.entries.map((entry) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      child: Text(
                        '${entry.key}:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        entry.value.toString(),
                        style: TextStyle(
                          color: entry.value.toString().isEmpty ? Colors.grey : Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              )
          ).toList(),
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
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }
}
