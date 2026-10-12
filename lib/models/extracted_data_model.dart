
import 'dart:convert';

class ExtractedData {
  final Map<String, dynamic> data;
  final double overallConfidence;
  final DateTime processedAt;
  final String processedWith;

  ExtractedData({
    required this.data,
    this.overallConfidence = 0.0,
    DateTime? processedAt,
    this.processedWith = 'api_ocr',
  }) : processedAt = processedAt ?? DateTime.now();

  factory ExtractedData.fromApiResponse(dynamic apiResponse) {
    if (apiResponse is Map) {
      return ExtractedData(
        data: Map<String, dynamic>.from(apiResponse['extractedData'] ?? {}),
        overallConfidence: (apiResponse['confidence'] ?? 0.0).toDouble(),
        processedWith: 'api_ocr_structured',
      );
    } else if (apiResponse is String) {
      return ExtractedData(
        data: {'raw_text': apiResponse},
        overallConfidence: 0.8,
        processedWith: 'api_ocr_text',
      );
    } else {
      return ExtractedData(
        data: {'error': 'Format de réponse non supporté'},
        overallConfidence: 0.0,
        processedWith: 'error',
      );
    }
  }

  factory ExtractedData.fromRawText(String text) {
    return ExtractedData(
      data: {'raw_text': text},
      overallConfidence: 0.7,
      processedWith: 'raw_text',
    );
  }

  String? get invoiceNumber => data['invoice_number']?.toString();
  String? get invoiceDate => data['invoice_date']?.toString();
  String? get supplierName => data['supplier_name']?.toString();
  String? get clientName => data['client_name']?.toString();
  String? get totalHT => data['total_ht']?.toString();
  String? get totalTTC => data['total_ttc']?.toString();
  String? get tvaAmount => data['tva_amount']?.toString();
  String? get tvaRate => data['tva_rate']?.toString();


  String? get netAPayer => data['net_a_payer']?.toString();
  String? get retenueSource => data['retenue_source']?.toString();
  String? get timbreFiscal => data['timbre_fiscal']?.toString();
  String? get tauxTVA => data['taux_tva']?.toString();
  String? get montantTVA => data['montant_tva']?.toString();


  String? get matriculeFiscalFournisseur => data['matricule_fiscal_fournisseur']?.toString() ?? data['mf_fournisseur']?.toString();
  String? get matriculeFiscalClient => data['matricule_fiscal_client']?.toString() ?? data['mf_client']?.toString();
  String? get matriculeFiscal => data['matricule_fiscal']?.toString();

  String? get rawText => data['raw_text']?.toString();


  double get calculatedNetAPayer {
    try {
      final ttc = double.tryParse(totalTTC ?? '') ?? 0.0;
      final retenue = double.tryParse(retenueSource ?? '') ?? 0.0;
      final timbre = double.tryParse(timbreFiscal ?? '') ?? 0.0;
      return ttc - retenue - timbre;
    } catch (e) {
      return 0.0;
    }
  }


  bool get hasCompleteFinancialData => totalTTC != null && totalTTC!.isNotEmpty;
  bool get hasNetAPayerData => netAPayer != null && netAPayer!.isNotEmpty;
  bool get hasRetenueSourceData => retenueSource != null && retenueSource!.isNotEmpty;
  bool get hasTimbreFiscalData => timbreFiscal != null && timbreFiscal!.isNotEmpty;
  bool get hasMatriculeFiscalData => matriculeFiscal != null && matriculeFiscal!.isNotEmpty;


  List<String> get missingFinancialFields {
    final missing = <String>[];
    if (!hasNetAPayerData) missing.add('Net à payer');
    if (!hasRetenueSourceData) missing.add('Retenue à la source');
    if (!hasTimbreFiscalData) missing.add('Timbre fiscal');
    if (!hasMatriculeFiscalData) missing.add('Matricule fiscal');
    return missing;
  }

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'overallConfidence': overallConfidence,
      'processedAt': processedAt.toIso8601String(),
      'processedWith': processedWith,
    };
  }

  String toJson() => json.encode(toMap());

  factory ExtractedData.fromJson(String jsonString) {
    final map = json.decode(jsonString);
    return ExtractedData(
      data: Map<String, dynamic>.from(map['data']),
      overallConfidence: (map['overallConfidence'] ?? 0.0).toDouble(),
      processedAt: DateTime.parse(map['processedAt']),
      processedWith: map['processedWith'] ?? 'unknown',
    );
  }

  bool get hasValidData => data.isNotEmpty && overallConfidence > 0.3;

  bool get hasStructuredData => data.keys.any((key) =>
  key != 'raw_text' && key != 'error' && data[key]?.toString().isNotEmpty == true);


  ExtractedData mergeWith(ExtractedData other) {
    final mergedData = Map<String, dynamic>.from(data);
    mergedData.addAll(other.data);

    return ExtractedData(
      data: mergedData,
      overallConfidence: (overallConfidence + other.overallConfidence) / 2,
      processedWith: '$processedWith + ${other.processedWith}',
    );
  }

  // ✅ MÉTHODE POUR CORRIGER LES CHAMPS MANQUANTS
  ExtractedData withFinancialCorrections({
    double? netAPayer,
    double? retenueSource,
    double? timbreFiscal,
    String? matriculeFiscal,
  }) {
    final correctedData = Map<String, dynamic>.from(data);

    if (netAPayer != null) correctedData['net_a_payer'] = netAPayer;
    if (retenueSource != null) correctedData['retenue_source'] = retenueSource;
    if (timbreFiscal != null) correctedData['timbre_fiscal'] = timbreFiscal;
    if (matriculeFiscal != null) correctedData['matricule_fiscal'] = matriculeFiscal;

    correctedData['manually_corrected'] = true;
    correctedData['correction_timestamp'] = DateTime.now().toIso8601String();

    return ExtractedData(
      data: correctedData,
      overallConfidence: overallConfidence + 0.1, // Augmente la confiance après correction
      processedAt: processedAt,
      processedWith: '$processedWith + manual_correction',
    );
  }


  String get formattedNetAPayer {
    final net = netAPayer ?? calculatedNetAPayer.toStringAsFixed(3);
    return '$net TND';
  }

  String get formattedRetenueSource {
    final retenue = retenueSource ?? '0.000';
    return '$retenue TND';
  }

  String get formattedTimbreFiscal {
    final timbre = timbreFiscal ?? '0.000';
    return '$timbre TND';
  }
}
