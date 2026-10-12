// validation_service.dart - VERSION CORRIGÉE
class ValidationService {
  // Validation CIN (Carte d'Identite Nationale Tunisienne)
  static bool validateCIN(String cin) {
    if (cin.isEmpty) return false;
    final cleanedCIN = cin.toUpperCase().replaceAll(' ', '');
    return RegExp(r'^[0-9]{8}$').hasMatch(cleanedCIN) ||
        RegExp(r'^[A-Z]{1,2}[0-9]{6}$').hasMatch(cleanedCIN);
  }

  // Validation Numero TVA Tunisien
  static bool validateTVA(String tva) {
    if (tva.isEmpty) return false;
    final cleanedTVA = tva.toUpperCase().replaceAll(' ', '');
    return RegExp(r'^[0-9]{8}[A-Z]{1}$').hasMatch(cleanedTVA) ||
        RegExp(r'^[A-Z]{2}[0-9]{9}$').hasMatch(cleanedTVA);
  }

  // Validation Matricule Fiscal Tunisien
  static bool validateMatriculeFiscal(String matricule) {
    if (matricule.isEmpty) return false;
    final cleanedMatricule = matricule.toUpperCase().replaceAll(' ', '');
    return RegExp(r'^[0-9]{7}[A-Z]{1}$').hasMatch(cleanedMatricule) ||
        RegExp(r'^[A-Z]{1,2}[0-9]{6}$').hasMatch(cleanedMatricule) ||
        RegExp(r'^[0-9]{8}$').hasMatch(cleanedMatricule);
  }

  // Validation IBAN Tunisien
  static bool validateIBAN(String iban) {
    if (iban.isEmpty) return false;
    final cleanedIBAN = iban.toUpperCase().replaceAll(' ', '');
    return RegExp(r'^TN59[0-9]{18}$').hasMatch(cleanedIBAN) ||
        RegExp(r'^TN[0-9]{2}[A-Z0-9]{20,30}$').hasMatch(cleanedIBAN);
  }

  // Validation email
  static bool validateEmail(String email) {
    if (email.isEmpty) return true; // Email optionnel
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  // Validation telephone Tunisien
  static bool validatePhone(String phone) {
    if (phone.isEmpty) return true; // Telephone optionnel
    final cleanedPhone = phone.replaceAll(' ', '').replaceAll('-', '').replaceAll('.', '');
    return RegExp(r'^(\+216|00216)?[2459][0-9]{7}$').hasMatch(cleanedPhone);
  }

  // Validation montant
  static bool validateAmount(String amount) {
    if (amount.isEmpty) return true; // Montant optionnel
    final cleanedAmount = amount.replaceAll(' ', '').replaceAll(',', '.');
    final numericValue = double.tryParse(cleanedAmount);
    return numericValue != null && numericValue >= 0;
  }

  // Validation date (format flexible)
  static bool validateDate(String date) {
    if (date.isEmpty) return true; // Date optionnelle

    // Formats acceptes: DD/MM/YYYY, DD-MM-YYYY, YYYY-MM-DD
    final formats = [
      RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$'),
      RegExp(r'^\d{1,2}-\d{1,2}-\d{4}$'),
      RegExp(r'^\d{4}-\d{2}-\d{2}$'),
    ];

    return formats.any((format) => format.hasMatch(date));
  }

  // Validation complete d'un document
  static Map<String, String> validateDocument(Map<String, dynamic> document) {
    final errors = <String, String>{};
    final extractedData = document;

    for (final entry in extractedData.entries) {
      final fieldName = entry.key;
      final fieldValue = entry.value?.toString() ?? '';

      if (fieldValue.isNotEmpty) {
        switch (fieldName.toLowerCase()) {
          case 'cin':
            if (!validateCIN(fieldValue)) {
              errors['cin'] = 'Numero CIN invalide';
            }
            break;
          case 'tva':
          case 'tva_number':
            if (!validateTVA(fieldValue)) {
              errors['tva'] = 'Numero TVA invalide';
            }
            break;
          case 'matricule_fiscal':
          case 'matricule':
            if (!validateMatriculeFiscal(fieldValue)) {
              errors['matricule_fiscal'] = 'Matricule fiscal invalide';
            }
            break;
          case 'iban':
            if (!validateIBAN(fieldValue)) {
              errors['iban'] = 'IBAN invalide';
            }
            break;
          case 'email':
            if (!validateEmail(fieldValue)) {
              errors['email'] = 'Email invalide';
            }
            break;
          case 'phone':
          case 'telephone':
            if (!validatePhone(fieldValue)) {
              errors['phone'] = 'Numero de telephone invalide';
            }
            break;
          case 'total_ht':
          case 'total_ttc':
          case 'tva_amount':
          case 'net_a_payer':
            if (!validateAmount(fieldValue)) {
              errors[fieldName] = 'Montant invalide';
            }
            break;
          case 'invoice_date':
          case 'date':
            if (!validateDate(fieldValue)) {
              errors[fieldName] = 'Format de date invalide (utilisez JJ/MM/AAAA)';
            }
            break;
        }
      }
    }

    return errors;
  }

  // Methode pour formater les valeurs
  static String formatAmount(String amount) {
    if (amount.isEmpty) return '';
    final cleaned = amount.replaceAll(' ', '').replaceAll(',', '.');
    final numericValue = double.tryParse(cleaned);
    if (numericValue == null) return amount;
    return numericValue.toStringAsFixed(3);
  }

  static String formatDate(String date) {
    if (date.isEmpty) return '';

    try {
      // Essayer de parser la date
      DateTime? parsedDate;

      if (date.contains('/')) {
        final parts = date.split('/');
        if (parts.length == 3) {
          parsedDate = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0])
          );
        }
      } else if (date.contains('-')) {
        parsedDate = DateTime.tryParse(date);
      }

      if (parsedDate != null) {
        return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
      }
    } catch (e) {
      // En cas d'erreur, retourner la date originale
    }

    return date;
  }
}


