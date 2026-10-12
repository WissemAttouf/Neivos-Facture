// models/document_model.dart
enum DocumentType {
  invoice,
  receipt,
  identity,
  other,
}

class ScannedDocument {
  final String id;
  final int? userId;
  final DocumentType documentType;
  final String? filePath;
  final Map<String, dynamic> extractedData;
  final DateTime createdAt;
  final double confidence;
  final String language;
  final String? processedWith;

  ScannedDocument({
    required this.id,
    this.userId,
    required this.documentType,
    this.filePath,
    required this.extractedData,
    required this.createdAt,
    required this.confidence,
    required this.language,
    this.processedWith,
  });

  // ✅ VERSION CORRIGÉE - Gère les conversions de types
  factory ScannedDocument.fromMap(Map<String, dynamic> map) {
    // Fonction utilitaire pour convertir en double en toute sécurité
    double? safeDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        // Nettoyer la chaîne (enlever les espaces, remplacer les virgules)
        final cleaned = value.replaceAll(' ', '').replaceAll(',', '.');
        return double.tryParse(cleaned);
      }
      return null;
    }

    // Fonction utilitaire pour convertir en int en toute sécurité
    int? safeInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) {
        return int.tryParse(value.replaceAll(' ', ''));
      }
      return null;
    }

    // Extraire l'ID
    final id = map['id']?.toString() ??
        map['_id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    // Extraire userId
    final userId = safeInt(map['user_id'] ?? map['userId']);

    // Extraire le type de document
    final documentType = _parseDocumentType(
        map['document_type'] ?? map['documentType']
    );

    // Extraire le chemin du fichier
    final filePath = map['file_path'] ?? map['filePath'] ?? map['image_path'];

    // Extraire la date de création
    final createdAt = _parseDate(map['created_at'] ?? map['createdAt']);

    // Extraire la confiance
    final confidence = safeDouble(map['confidence']) ?? 0.8;

    // Extraire la langue
    final language = map['language'] ?? 'fr';

    // Extraire la méthode de traitement
    final processedWith = map['processed_with'] ?? map['processedWith'];

    // ✅ Construire les données extraites
    final extractedData = <String, dynamic>{};

    // Liste des champs importants à extraire
    final importantFields = [
      'invoice_number', 'invoice_date', 'supplier_name', 'supplier_address',
      'supplier_tax_id', 'client_name', 'client_address', 'client_tax_id',
      'matricule_fiscal', 'total_ht', 'total_ttc', 'tva_amount', 'tva_rate',
      'net_a_payer', 'retenue_source', 'timbre_fiscal', 'currency',
      'payment_terms', 'due_date', 'iban', 'phone', 'email', 'description',
      'raw_text'
    ];

    // Ajouter les champs importants depuis la map principale
    for (final field in importantFields) {
      if (map.containsKey(field) && map[field] != null) {
        extractedData[field] = map[field].toString();
      }
    }

    // Si extractedData existe déjà dans la map, l'utiliser
    if (map['extractedData'] != null) {
      final ed = map['extractedData'];
      if (ed is Map) {
        ed.forEach((key, value) {
          extractedData[key.toString()] = value?.toString() ?? '';
        });
      }
    }

    return ScannedDocument(
      id: id,
      userId: userId,
      documentType: documentType,
      filePath: filePath,
      extractedData: extractedData,
      createdAt: createdAt,
      confidence: confidence,
      language: language,
      processedWith: processedWith,
    );
  }

  // Convertir en Map pour stockage local
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'documentType': documentType.toString(),
      'filePath': filePath,
      'extractedData': extractedData,
      'createdAt': createdAt.toIso8601String(),
      'confidence': confidence,
      'language': language,
      'processedWith': processedWith,
    };
  }

  // Créer une copie avec modifications
  ScannedDocument copyWith({
    String? id,
    int? userId,
    DocumentType? documentType,
    String? filePath,
    Map<String, dynamic>? extractedData,
    DateTime? createdAt,
    double? confidence,
    String? language,
    String? processedWith,
  }) {
    return ScannedDocument(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      documentType: documentType ?? this.documentType,
      filePath: filePath ?? this.filePath,
      extractedData: extractedData ?? this.extractedData,
      createdAt: createdAt ?? this.createdAt,
      confidence: confidence ?? this.confidence,
      language: language ?? this.language,
      processedWith: processedWith ?? this.processedWith,
    );
  }

  // Méthodes utilitaires statiques
  static DocumentType _parseDocumentType(dynamic type) {
    if (type == null) return DocumentType.invoice;

    final typeStr = type.toString().toLowerCase();
    if (typeStr.contains('invoice') || typeStr.contains('facture')) {
      return DocumentType.invoice;
    } else if (typeStr.contains('receipt') || typeStr.contains('reçu')) {
      return DocumentType.receipt;
    } else if (typeStr.contains('identity') || typeStr.contains('carte')) {
      return DocumentType.identity;
    } else {
      return DocumentType.other;
    }
  }

  static DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    try {
      if (date is DateTime) return date;
      if (date is String) {
        // Essayer de parser la date
        final parsed = DateTime.tryParse(date);
        if (parsed != null) return parsed;

        // Essayer avec des formats alternatifs
        if (date.contains('/')) {
          final parts = date.split('/');
          if (parts.length == 3) {
            final day = int.tryParse(parts[0]) ?? 1;
            final month = int.tryParse(parts[1]) ?? 1;
            final year = int.tryParse(parts[2]) ?? 2000;
            return DateTime(year, month, day);
          }
        }
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }
}
