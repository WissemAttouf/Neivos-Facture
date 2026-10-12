// providers/document_provider.dart - VERSION FINALE SANS DOUBLONS
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../models/document_model.dart';
import '../services/api_service.dart';
import '../services/ocr_service.dart';

class DocumentProvider with ChangeNotifier {
  final ApiService _apiService;
  List<ScannedDocument> _documents = [];
  bool _isLoading = false;
  String _error = '';
  ScannedDocument? _currentDocument;
  double _processingProgress = 0.0;
  int? _currentUserId;

  DocumentProvider({required ApiService apiService}) : _apiService = apiService;

  // Getters
  List<ScannedDocument> get documents => _documents;
  bool get isLoading => _isLoading;
  String get error => _error;
  ScannedDocument? get currentDocument => _currentDocument;
  double get processingProgress => _processingProgress;
  String? get errorMessage => _error.isNotEmpty ? _error : null;
  bool get isProcessing => _isLoading;
  int? get userId => _currentUserId;

  // ✅ DÉFINIR L'UTILISATEUR COURANT
  void setCurrentUser(int? userId) {
    if (_currentUserId != userId) {
      _currentUserId = userId;
      print('👤 DocumentProvider - Utilisateur courant: $userId');
    }
  }

  // ✅ CHARGER LES DOCUMENTS D'UN UTILISATEUR SPÉCIFIQUE
  Future<void> loadDocuments({int? userId}) async {
    final targetUserId = userId ?? _currentUserId;

    if (_isLoading) return;

    _isLoading = true;
    _error = '';

    try {
      print('📥 Chargement des documents pour user: $targetUserId');

      if (targetUserId == null) {
        print('⚠️ Aucun utilisateur connecté, chargement local uniquement');
        await _loadFromLocalStorage();
        _isLoading = false;
        notifyListeners();
        return;
      }

      List<dynamic> invoices = [];
      try {
        invoices = await _apiService.getInvoices(targetUserId.toString());
      } catch (e) {
        print('⚠️ Erreur API, utilisation du cache local: $e');
        invoices = [];
      }

      if (invoices.isNotEmpty) {
        print('📄 ${invoices.length} documents récupérés depuis API');

        final List<ScannedDocument> loadedDocs = [];

        for (final invoice in invoices) {
          try {
            final Map<String, dynamic> invoiceMap;
            if (invoice is Map) {
              invoiceMap = Map<String, dynamic>.from(invoice);
            } else {
              print('⚠️ Type de document inattendu: ${invoice.runtimeType}');
              continue;
            }

            invoiceMap['userId'] = targetUserId;
            final doc = ScannedDocument.fromMap(invoiceMap);
            loadedDocs.add(doc);
          } catch (e) {
            print('⚠️ Erreur conversion document: $e');
            continue;
          }
        }

        _documents = loadedDocs;
        print('✅ ${_documents.length} documents chargés avec succès depuis API');

        try {
          await _saveDocumentsToLocalStorage();
        } catch (e) {
          print('⚠️ Erreur sauvegarde cache: $e');
        }
      } else {
        print('⚠️ Aucun document depuis API, chargement local');
        await _loadFromLocalStorage();
      }

    } catch (e) {
      print('❌ Erreur loadDocuments: $e');
      _error = 'Erreur de chargement: $e';
      await _loadFromLocalStorage();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ SAUVEGARDER UN DOCUMENT (AVEC VÉRIFICATION DES DOUBLONS)
  Future<bool> saveDocument(ScannedDocument document, BuildContext context) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('💾 Tentative de sauvegarde du document...');
      print('📊 ID: ${document.id}');
      print('👤 User ID: ${document.userId ?? _currentUserId}');

      final userId = document.userId ?? _currentUserId;

      if (userId == null) {
        print('⚠️ Utilisateur non connecté, sauvegarde locale uniquement');
        final success = await _saveDocumentLocally(document);
        _isLoading = false;
        notifyListeners();
        return success;
      }

      // Préparer les données pour l'API
      final invoiceData = {
        'user_id': userId,
        'invoice_number': document.extractedData['invoice_number'] ?? 'INCONNU',
        'supplier_name': document.extractedData['supplier_name'] ?? 'INCONNU',
        'invoice_date': _formatDateForAPI(document.extractedData['invoice_date']),
        'total_ht': _parseAmount(document.extractedData['total_ht']),
        'total_ttc': _parseAmount(document.extractedData['total_ttc']),
        'tva_amount': _parseAmount(document.extractedData['tva_amount']),
        'net_a_payer': _parseAmount(document.extractedData['net_a_payer']),
        'retenue_source': _parseAmount(document.extractedData['retenue_source']),
        'timbre_fiscal': _parseAmount(document.extractedData['timbre_fiscal']),
        'matricule_fiscal': document.extractedData['matricule_fiscal'] ?? '',
        'client_name': document.extractedData['client_name'] ?? '',
        'client_address': document.extractedData['client_address'] ?? '',
        'client_tax_id': document.extractedData['client_tax_id'] ?? '',
        'supplier_address': document.extractedData['supplier_address'] ?? '',
        'supplier_tax_id': document.extractedData['supplier_tax_id'] ?? '',
        'tva_rate': _parseAmount(document.extractedData['tva_rate']),
        'currency': document.extractedData['currency'] ?? 'TND',
        'payment_terms': document.extractedData['payment_terms'] ?? '',
        'due_date': document.extractedData['due_date'] ?? '',
        'iban': document.extractedData['iban'] ?? '',
        'phone': document.extractedData['phone'] ?? '',
        'email': document.extractedData['email'] ?? '',
        'description': document.extractedData['description'] ?? '',
        'raw_text': document.extractedData['raw_text'] ?? '',
        'confidence': document.confidence,
        'processed_with': document.processedWith ?? 'neivos_ocr',
        'extracted_data': document.extractedData,
      };

      print('📦 Envoi à l\'API...');

      final saveResult = await _apiService.saveInvoice(invoiceData);

      // 🔴 GESTION DU DOUBLON ICI
      if (saveResult['duplicate'] == true) {
        print('⚠️ Doublon détecté par l\'API');
        _error = 'duplicate'; // Code spécial pour le frontend

        if (context.mounted) {
          _showDuplicateDialog(context, saveResult['message'] ?? 'Cette facture a déjà été scannée.');
        }

        _isLoading = false;
        notifyListeners();
        return false; // On retourne false car la sauvegarde a été bloquée
      }

      final bool apiSuccess = saveResult['success'] == true;

      if (apiSuccess) {
        print('✅ Document sauvegardé avec succès via API');

        final savedId = saveResult['document_id']?.toString() ?? document.id;
        final savedDocument = document.copyWith(id: savedId);

        _addOrUpdateDocument(savedDocument);
        await _saveToLocalStorage(savedDocument);
        _error = '';

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Facture sauvegardée avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        print('⚠️ Échec de la sauvegarde API: ${saveResult['message']}');
        _error = saveResult['message'] ?? 'Erreur API, sauvegarde locale activée';

        final success = await _saveDocumentLocally(document);
        _isLoading = false;
        notifyListeners();
        return success;
      }

    } catch (e) {
      print('❌ Erreur lors de la sauvegarde: $e');
      _error = 'Erreur lors de la sauvegarde: ${e.toString()}';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Fonction pour afficher le pop-up de doublon
  void _showDuplicateDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false, // L'utilisateur doit cliquer sur le bouton
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Document en double'),
            ],
          ),
          content: Text(
            message,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Fermer le dialog
              },
              child: const Text('Compris', style: TextStyle(fontSize: 16, color: Colors.blue)),
            ),
          ],
        );
      },
    );
  }

  // ✅ SAUVEGARDE LOCALE (FALLBACK)
  Future<bool> _saveDocumentLocally(ScannedDocument document) async {
    try {
      print('📱 Sauvegarde locale...');

      final localData = Map<String, dynamic>.from(document.extractedData);
      localData['saved_locally_at'] = DateTime.now().toIso8601String();
      localData['local_backup'] = true;

      final localDocument = document.copyWith(extractedData: localData);

      _addOrUpdateDocument(localDocument);
      await _saveToLocalStorage(localDocument);
      await _saveDocumentsToLocalStorage();

      print('✅ Document sauvegardé localement');
      _error = 'Document sauvegardé localement (mode déconnecté)';

      return true;
    } catch (e) {
      print('❌ Erreur sauvegarde locale: $e');
      _error = 'Échec de la sauvegarde locale: $e';
      return false;
    }
  }

  // ✅ AJOUTER OU METTRE À JOUR UN DOCUMENT
  void _addOrUpdateDocument(ScannedDocument document) {
    final existingIndex = _documents.indexWhere((doc) => doc.id == document.id);

    if (existingIndex >= 0) {
      _documents[existingIndex] = document;
      print('✏️ Document mis à jour: ${document.id}');
    } else {
      _documents.insert(0, document);
      print('📄 Nouveau document ajouté: ${document.id}');
    }

    if (_currentDocument?.id == document.id) {
      _currentDocument = document;
    }
  }

  // ✅ SUPPRIMER UN DOCUMENT (AVEC SUPPRESSION BASE DE DONNÉES)
  Future<bool> deleteDocument(String documentId, {int? userId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      print('🗑️ Suppression du document: $documentId');

      final targetUserId = userId ?? _currentUserId;
      bool apiSuccess = false;

      // 1. Supprimer de l'API si utilisateur connecté
      if (targetUserId != null) {
        try {
          // Essayer d'abord la suppression normale
          apiSuccess = await _apiService.deleteDocument(documentId);

          // Si échec, essayer la suppression admin (au cas où)
          if (!apiSuccess) {
            print('🔄 Tentative suppression via route admin...');
            apiSuccess = await _apiService.deleteInvoiceAsAdmin(documentId);
          }
        } catch (e) {
          print('⚠️ Erreur suppression API: $e');
          apiSuccess = false;
        }
      }

      // 2. Supprimer de la liste locale (même si API échoue)
      _documents.removeWhere((doc) => doc.id == documentId);

      // 3. Mettre à jour le cache local
      await _saveDocumentsToLocalStorage();

      // 4. Supprimer également du stockage local spécifique
      await _removeFromLocalStorage(documentId, targetUserId);

      notifyListeners();

      if (apiSuccess) {
        print('✅ Document supprimé avec succès (API et local)');
      } else {
        print('⚠️ Document supprimé localement uniquement (API non disponible)');
      }

      return true;

    } catch (e) {
      _error = 'Erreur lors de la suppression: $e';
      print('❌ Erreur suppression: $e');
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

// Supprimer du stockage local spécifique
  Future<void> _removeFromLocalStorage(String documentId, int? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_invoices_${userId ?? _currentUserId ?? 'guest'}';
      final localInvoices = prefs.getString(key) ?? '[]';
      final List<dynamic> invoices = json.decode(localInvoices);

      invoices.removeWhere((item) => item['id'] == documentId);

      await prefs.setString(key, json.encode(invoices));
      print('💾 Document supprimé du stockage local');
    } catch (e) {
      print('❌ Erreur suppression stockage local: $e');
    }
  }

  // ✅ SCAN DOCUMENT AVEC OCR
  Future<ScannedDocument?> scanDocument(String imagePath, BuildContext context) async {
    _isLoading = true;
    _error = '';
    _processingProgress = 0.0;
    notifyListeners();

    try {
      print('📸 Début du scan: $imagePath');

      final imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        throw Exception('Fichier image introuvable');
      }

      _processingProgress = 0.3;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));

      final ocrService = OCRService(apiService: _apiService);

      _processingProgress = 0.6;
      notifyListeners();

      final document = await ocrService.processDocument(imageFile);

      if (document != null) {
        _processingProgress = 0.9;
        notifyListeners();

        final documentWithUser = document.copyWith(
          userId: _currentUserId,
        );

        _currentDocument = documentWithUser;
        _error = '';

        print('✅ Scan réussi: ${documentWithUser.extractedData.length} champs extraits');
        print('👤 Associé à user: $_currentUserId');

        _processingProgress = 1.0;
        notifyListeners();

        return documentWithUser;
      } else {
        throw Exception('L\'OCR n\'a retourné aucun document');
      }
    } catch (e) {
      print('❌ Erreur lors du scan: $e');
      _error = 'Erreur lors du scan: $e';
      _processingProgress = 0.0;
      notifyListeners();

      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ GÉNÉRER PDF
  Future<String?> generateAndDownloadPDF(ScannedDocument document, BuildContext context) async {
    try {
      print('📄 Génération du PDF...');

      final status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('Permission de stockage refusée');
      }

      final pdf = await _generatePDF(document);

      final directory = await getExternalStorageDirectory();
      final downloadsDir = Directory('${directory?.path}/Download/Neivos_Factures');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      final invoiceNumber = document.extractedData['invoice_number'] ?? 'SANS_NUMERO';
      final fileName = 'Facture_${invoiceNumber}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = '${downloadsDir.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      print('✅ PDF généré: $filePath');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF généré: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      return filePath;

    } catch (e) {
      print('❌ Erreur génération PDF: $e');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur génération PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    }
  }

  // ✅ MÉTHODES DE STOCKAGE LOCAL
  Future<void> _saveToLocalStorage(ScannedDocument document) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'local_invoices_${_currentUserId ?? 'guest'}';
      final localInvoices = prefs.getString(key) ?? '[]';
      final List<dynamic> invoices = json.decode(localInvoices);

      invoices.removeWhere((item) => item['id'] == document.id);

      invoices.add({
        'id': document.id,
        'data': document.toMap(),
        'saved_at': DateTime.now().toIso8601String(),
      });

      await prefs.setString(key, json.encode(invoices));
      print('💾 Document sauvegardé localement pour user $_currentUserId');
    } catch (e) {
      print('❌ Erreur sauvegarde locale: $e');
    }
  }

  Future<void> _saveDocumentsToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final documentsData = _documents.map((doc) => doc.toMap()).toList();
      final key = 'cached_documents_${_currentUserId ?? 'guest'}';
      await prefs.setString(key, json.encode(documentsData));
      print('💾 ${_documents.length} documents en cache pour user $_currentUserId');
    } catch (e) {
      print('❌ Erreur sauvegarde cache: $e');
    }
  }

  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'cached_documents_${_currentUserId ?? 'guest'}';
      final cachedData = prefs.getString(key);

      if (cachedData != null && cachedData.isNotEmpty) {
        final List<dynamic> cachedDocuments = json.decode(cachedData);
        final List<ScannedDocument> loadedDocs = [];

        for (final item in cachedDocuments) {
          try {
            if (item is Map) {
              final doc = ScannedDocument.fromMap(Map<String, dynamic>.from(item));
              loadedDocs.add(doc);
            }
          } catch (e) {
            print('⚠️ Erreur parsing document cache: $e');
            continue;
          }
        }

        _documents = loadedDocs;
        print('📂 Documents chargés depuis cache: ${_documents.length}');
        if (_documents.isEmpty) {
          _error = 'Aucun document en cache';
        }
      } else {
        _documents = [];
        print('📂 Aucun document en cache');
      }
    } catch (e) {
      print('❌ Erreur chargement cache: $e');
      _error = 'Erreur chargement données locales';
      _documents = [];
    }
  }

  // ✅ MÉTHODES UTILITAIRES
  double _parseAmount(dynamic amount) {
    if (amount == null) return 0.0;
    if (amount is num) return amount.toDouble();
    if (amount is String) {
      final cleaned = amount
          .replaceAll(' ', '')
          .replaceAll(',', '.')
          .replaceAll('TND', '')
          .replaceAll('tnd', '')
          .trim();
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }

  String _formatDateForAPI(dynamic date) {
    if (date == null || date.toString().isEmpty) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }

    try {
      final dateStr = date.toString();

      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
        return dateStr;
      }

      if (dateStr.contains('/') || dateStr.contains('-')) {
        String separator = dateStr.contains('/') ? '/' : '-';
        final parts = dateStr.split(separator);
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            final year = parts[0].padLeft(4, '20');
            final month = parts[1].padLeft(2, '0');
            final day = parts[2].padLeft(2, '0');
            return '$year-$month-$day';
          } else {
            final day = parts[0].padLeft(2, '0');
            final month = parts[1].padLeft(2, '0');
            final year = parts[2].length == 2 ? '20${parts[2]}' : parts[2];
            return '$year-$month-$day';
          }
        }
      }

      final parsedDate = DateTime.tryParse(dateStr);
      if (parsedDate != null) {
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      }
    } catch (e) {
      print('⚠️ Erreur formatage date: $e');
    }

    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<pw.Document> _generatePDF(ScannedDocument document) async {
    final pdf = pw.Document();
    final extractedData = document.extractedData;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'FACTURE',
                  style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Numéro: ${extractedData['invoice_number'] ?? 'N/A'}'),
                        pw.Text('Date: ${_formatDateForDisplay(extractedData['invoice_date'])}'),
                        pw.Text('Devise: ${extractedData['currency'] ?? 'TND'}'),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Confiance: ${(document.confidence * 100).toStringAsFixed(1)}%'),
                        pw.Text('Scan: ${DateFormat('dd/MM/yyyy').format(document.createdAt)}'),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('FOURNISSEUR', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Text(extractedData['supplier_name'] ?? 'Non spécifié'),
                        pw.Text(extractedData['supplier_address'] ?? ''),
                        pw.Text('MF: ${extractedData['supplier_tax_id'] ?? ''}'),
                        pw.Text('Tél: ${extractedData['phone'] ?? ''}'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 20),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('CLIENT', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Text(extractedData['client_name'] ?? 'Non spécifié'),
                        pw.Text(extractedData['client_address'] ?? ''),
                        pw.Text('MF: ${extractedData['client_tax_id'] ?? ''}'),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              pw.Text('DÉTAILS FINANCIERS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),

              pw.Table(
                border: pw.TableBorder.all(),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2),
                  1: const pw.FlexColumnWidth(1),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('Montant (TND)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  _buildPDFTableRow('Total HT', extractedData['total_ht']),
                  _buildPDFTableRow('TVA (${extractedData['tva_rate'] ?? '19'}%)', extractedData['tva_amount']),
                  _buildPDFTableRow('Total TTC', extractedData['total_ttc']),
                  if (extractedData['retenue_source'] != null && _parseAmount(extractedData['retenue_source']) > 0)
                    _buildPDFTableRow('Retenue source', extractedData['retenue_source']),
                  if (extractedData['timbre_fiscal'] != null && _parseAmount(extractedData['timbre_fiscal']) > 0)
                    _buildPDFTableRow('Timbre fiscal', extractedData['timbre_fiscal']),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('NET À PAYER', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(
                          _formatAmountForPDF(extractedData['net_a_payer']),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (extractedData['description'] != null && extractedData['description'].toString().isNotEmpty) ...[
                pw.SizedBox(height: 20),
                pw.Text('Description:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text(extractedData['description'].toString()),
              ],

              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),

              pw.Center(
                child: pw.Text(
                  'Document généré par Neivos Facture - ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
                  style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf;
  }

  pw.TableRow _buildPDFTableRow(String label, dynamic value) {
    return pw.TableRow(
      children: [
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(label)),
        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(_formatAmountForPDF(value))),
      ],
    );
  }

  String _formatAmountForPDF(dynamic amount) {
    if (amount == null) return '0.000 TND';
    try {
      final numValue = _parseAmount(amount);
      return '${numValue.toStringAsFixed(3)} TND';
    } catch (e) {
      return '0.000 TND';
    }
  }

  String _formatDateForDisplay(dynamic date) {
    if (date == null) return 'Non spécifiée';
    try {
      if (date is DateTime) return DateFormat('dd/MM/yyyy').format(date);
      if (date is String) {
        if (date.contains('-')) {
          final parsed = DateTime.tryParse(date);
          if (parsed != null) return DateFormat('dd/MM/yyyy').format(parsed);
        }
        if (date.contains('/')) {
          final parts = date.split('/');
          if (parts.length == 3) {
            if (parts[0].length == 4) {
              return '${parts[2]}/${parts[1]}/${parts[0]}';
            } else {
              return date;
            }
          }
        }
      }
      return date.toString();
    } catch (e) {
      return date.toString();
    }
  }

  // ✅ SUPPRIMER LES DOCUMENTS TEMPORAIRES
  void removeTemporaryDocuments() {
    final tempDocs = _documents.where((doc) =>
    doc.extractedData['is_temporary'] == true
    ).toList();

    for (final tempDoc in tempDocs) {
      _documents.remove(tempDoc);
    }

    print('🗑️ ${tempDocs.length} document(s) temporaire(s) supprimé(s)');
    notifyListeners();
  }

  // ✅ AJOUTER UN DOCUMENT
  void addDocument(ScannedDocument document) {
    _documents.insert(0, document);
    _currentDocument = document;
    notifyListeners();
    print('📄 Nouveau document ajouté: ${document.id}');
  }

  // ✅ DÉFINIR LE DOCUMENT COURANT
  void setCurrentDocument(ScannedDocument document) {
    _currentDocument = document;
    notifyListeners();
  }

  // ✅ EFFACER LE DOCUMENT COURANT
  void clearCurrentDocument() {
    _currentDocument = null;
    notifyListeners();
  }

  // ✅ EFFACER LES ERREURS
  void clearError() {
    _error = '';
    notifyListeners();
  }

  // ✅ RÉINITIALISER LE PROVIDER
  void reset() {
    _documents.clear();
    _currentDocument = null;
    _error = '';
    _isLoading = false;
    _processingProgress = 0.0;
    _currentUserId = null;
    notifyListeners();
    print('🔄 DocumentProvider réinitialisé');
  }
}

