
import 'dart:convert';

class ExtractedData {
  
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
 


  String? get netAPayer => data['net_a_payer']?.toString();
 


  String? get matriculeFiscalFournisseur => data['matricule_fiscal_fournisseur']?.toString() ?? data['mf_fournisseur']?.toString();


  String? get rawText => data['raw_text']?.toString();


  double get calculatedNetAPayer {
    try {
      final ttc = double.tryParse(totalTTC ?? '') ?? 0.0;
     
    } catch (e) {
      return 0.0;
    }
  }


  bool get hasCompleteFinancialData => totalTTC != null && totalTTC!.isNotEmpty;
  

  List<String> get missingFinancialFields {
    final missing = <String>[];
    if (!hasNetAPayerData) missing.add('Net à payer');
  
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

  
    double? timbreFiscal,
    String? matriculeFiscal,
  }) {
    final correctedData = Map<String, dynamic>.from(data);

    if (netAPayer != null) correctedData['net_a_payer'] = netAPayer;
  

    correctedData['manually_corrected'] = true;
    correctedData['correction_timestamp'] = DateTime.now().toIso8601String();

    return ExtractedData(
      data: correctedData,
 
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
