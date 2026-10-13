// models/document_model.dart
enum DocumentType {
  invoice,
  receipt,
  identity,
  other,
}

class ScannedDocument {
  final String id;
  

  ScannedDocument({
    required this.id,
    this.userId,
   
  factory ScannedDocument.fromMap(Map<String, dynamic> map) {
    // Fonction utilitaire pour convertir en double en toute sécurité
    double? safeDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
     
      }
      return null;
    }

    // Fonction utilitaire pour convertir en int en toute sécurité
    int? safeInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      
      }
      return null;
    }

    // Extraire l'ID
    final id = map['id']?.toString() ??
        map['_id']?.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    
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
      
    );
  }

  // Convertir en Map pour stockage local
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'documentType': documentType.toString(),
      'filePath': filePath,
      
    };
  }

  // Créer une copie avec modifications
  ScannedDocument copyWith({
    String? id,
    int? userId,
    DocumentType? documentType,
    
  }) {
    return ScannedDocument(
      id: id ?? this.id,
      userId: userId ?? this.userId,
     
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
     

        // Essayer avec des formats alternatifs
        if (date.contains('/')) {
          final parts = date.split('/');
          if (parts.length == 3) {
            
        }
      }
      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }
}
