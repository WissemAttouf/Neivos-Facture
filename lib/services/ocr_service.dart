// lib/services/ocr_service.dart
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../models/document_model.dart';
import './api_service.dart';

class OCRService {
  final ApiService _apiService;

  OCRService({required ApiService apiService}) : _apiService = apiService;

  // ✅ MÉTHODE PRINCIPALE CORRIGÉE
  Future<List<ScannedDocument>> processMultipleDocuments(List<File> imageFiles) async {
    try {
      print('🚀 OCRService: Début traitement multiple...');

      final ocrResults = await _apiService.extractMultipleInvoicesWithOCR(imageFiles);
      List<ScannedDocument> processedDocuments = [];

      for (int i = 0; i < ocrResults.length; i++) {
        final ocrResult = ocrResults[i];

        if (!ocrResult['success']) {
          print('⚠️ Échec OCR pour un document: ${ocrResult['error']}');
          continue;
        }

        final rawData = ocrResult['data'];
        final rawText = ocrResult['text']?.toString() ?? '';
        final confidence = ocrResult['confidence'] ?? 1.0;
        final source = ocrResult['source'] ?? 'unknown';

        Map<String, dynamic> extractedData = {};

        if (rawData is Map) {
          // ✅ 1. MAPPING EXACT DES CLÉS DE L'API SWAGGER (FR) VERS L'APP (EN)
          extractedData['supplier_name'] = rawData['nom_fournisseur'] ?? rawData['supplier_name'];
          extractedData['supplier_address'] = rawData['adresse_fournisseur'] ?? rawData['supplier_address'];
          extractedData['supplier_tax_id'] = rawData['mf_fournisseur'] ?? rawData['supplier_tax_id'];

          extractedData['client_name'] = rawData['nom_client'] ?? rawData['client_name'];
          extractedData['client_address'] = rawData['adresse_client'] ?? rawData['client_address'];
          extractedData['client_tax_id'] = rawData['mf_client'] ?? rawData['client_tax_id'];

          extractedData['invoice_number'] = rawData['numero_facture'] ?? rawData['invoice_number'];
          extractedData['invoice_date'] = rawData['date_facture'] ?? rawData['invoice_date'];
          extractedData['description'] = rawData['description'];

          // ✅ 2. FORMATAGE DES MONTANTS (Conversion des millimes, ex: 1824104 -> 1824.104)
          extractedData['total_ht'] = _formatMoney(rawData['total_ht']);
          extractedData['total_ttc'] = _formatMoney(rawData['total_ttc']);
          extractedData['tva_amount'] = _formatMoney(rawData['montant_tva'] ?? rawData['tva_amount']);
          extractedData['tva_rate'] = _formatRate(rawData['taux_tva'] ?? rawData['tva_rate']);
          extractedData['timbre_fiscal'] = _formatMoney(rawData['timbre_fiscal']);
          extractedData['retenue_source'] = _formatMoney(rawData['retenue_source']);
          extractedData['net_a_payer'] = _formatMoney(rawData['net_a_payer'] ?? rawData['total_ttc']);

          // Nettoyer les valeurs nulles pour ne pas polluer le formulaire
          extractedData.removeWhere((key, value) => value == null || value.toString().trim().isEmpty);

          // 3. SECOURS : Extraire du texte brut UNIQUEMENT ce qui manque vraiment
          if (rawText.isNotEmpty) {
            final missingFields = _extractMissingFields(extractedData, rawText);
            extractedData.addAll(missingFields);
          }

          // 4. Calculs finaux si des totaux manquent toujours
          extractedData = _addCalculatedFields(extractedData);
        }

        extractedData['raw_text'] = rawText;
        extractedData['confidence'] = confidence;
        extractedData['processed_with'] = source;
        extractedData['processed_at'] = DateTime.now().toIso8601String();

        _validateExtractedData(extractedData);

        final filePath = i < imageFiles.length ? imageFiles[i].path : imageFiles.first.path;

        final document = ScannedDocument(
          id: DateTime.now().millisecondsSinceEpoch.toString() + '_$i',
          documentType: DocumentType.invoice,
          filePath: filePath,
          extractedData: extractedData,
          createdAt: DateTime.now(),
          confidence: confidence.toDouble(),
          language: 'fr',
          processedWith: source,
        );

        processedDocuments.add(document);
      }

      return processedDocuments;
    } catch (e) {
      throw Exception('Erreur lors du traitement OCR: $e');
    }
  }

  Future<ScannedDocument> processDocument(File imageFile) async {
    final documents = await processMultipleDocuments([imageFile]);
    if (documents.isNotEmpty) return documents.first;
    throw Exception('L\'OCR n\'a retourné aucun résultat.');
  }

  // ✅ FONCTION MAGIQUE POUR CONVERTIR LES MILLIMES EN DINARS
  String? _formatMoney(dynamic value) {
    if (value == null) return null;
    String str = value.toString().trim();
    if (str.isEmpty) return null;

    // Si l'API renvoie un entier (ex: 1824104 -> 1824.104)
    if (value is int) {
      return (value / 1000).toStringAsFixed(3);
    }

    str = str.replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
    double? val = double.tryParse(str);
    if (val != null) {
      // Si c'est un grand nombre sans point décimal, on assume que c'est des millimes
      if (!str.contains('.') && val > 1000) {
        return (val / 1000).toStringAsFixed(3);
      }
      return val.toStringAsFixed(3);
    }
    return str;
  }

  String? _formatRate(dynamic value) {
    if (value == null) return null;
    String str = value.toString().replaceAll(',', '.').replaceAll(RegExp(r'[^\d.]'), '');
    return str;
  }

  Map<String, dynamic> _extractMissingFields(Map<String, dynamic> currentData, String text) {
    final extracted = <String, dynamic>{};
    final requiredFields = [
      'invoice_date', 'total_ht', 'tva_amount', 'tva_rate',
      'retenue_source', 'timbre_fiscal', 'matricule_fiscal',
      'client_name', 'supplier_name', 'invoice_number'
    ];

    for (final field in requiredFields) {
      if (!currentData.containsKey(field) || currentData[field] == null || currentData[field].toString().isEmpty) {
        final value = _extractSpecificField(field, text);
        if (value != null) extracted[field] = value;
      }
    }
    return extracted;
  }

  dynamic _extractSpecificField(String field, String text) {
    final cleanedText = text.toLowerCase();
    switch (field) {
      case 'invoice_date':
        final match = RegExp(r'(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})').firstMatch(cleanedText);
        return match?.group(1);
      case 'matricule_fiscal':
        final match = RegExp(r'(?:mf|matricule)[\s:]*([a-z0-9]{7,15})', caseSensitive: false).firstMatch(cleanedText);
        return match?.group(1)?.toUpperCase();
      case 'tva_rate':
        final match = RegExp(r'tva\s*[:.]?\s*(\d+(?:[.,]\d+)?)\s*%', caseSensitive: false).firstMatch(cleanedText);
        return match != null ? double.tryParse(match.group(1)!.replaceAll(',', '.')) : 19.0;
      case 'invoice_number':
        final match = RegExp(r'(?:facture|invoice)\s*(?:n[°o]?|numéro|numero|ref)?\s*[:.]?\s*([a-z0-9\-\/]+)', caseSensitive: false).firstMatch(cleanedText);
        return match?.group(1)?.trim().toUpperCase();
      case 'supplier_name':
        final match = RegExp(r'(?:fournisseur|supplier)[\s:]*([^\n\r]{10,80})', caseSensitive: false).firstMatch(text);
        return match?.group(1)?.trim();
      case 'client_name':
        final match = RegExp(r'(?:client|customer)[\s:]*([^\n\r]{10,80})', caseSensitive: false).firstMatch(text);
        return match?.group(1)?.trim();
      default:
        return null;
    }
  }

  Map<String, dynamic> _addCalculatedFields(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    if (result.containsKey('total_ttc') && !result.containsKey('total_ht')) {
      final ttc = double.tryParse(result['total_ttc'].toString()) ?? 0;
      final tvaRate = double.tryParse(result['tva_rate']?.toString() ?? '19') ?? 19.0;
      if (ttc > 0) {
        final ht = ttc / (1 + (tvaRate / 100));
        result['total_ht'] = ht.toStringAsFixed(3);
        result['tva_amount'] = (ttc - ht).toStringAsFixed(3);
      }
    }

    if (!result.containsKey('net_a_payer') && result.containsKey('total_ttc')) {
      final ttc = double.tryParse(result['total_ttc'].toString()) ?? 0;
      final timbre = double.tryParse(result['timbre_fiscal']?.toString() ?? '0.6') ?? 0.6;
      result['net_a_payer'] = (ttc - timbre).toStringAsFixed(3);
    }

    if (!result.containsKey('currency')) result['currency'] = 'TND';
    return result;
  }

  void _validateExtractedData(Map<String, dynamic> data) {
    // Validation silencieuse
  }

  Future<bool> testConnection() async {
    return await _apiService.testOcrConnection();
  }

  String getApiInfo() {
    return 'API NEIVOS OCR: ${ApiService.OCR_API_URL}';
  }
}

