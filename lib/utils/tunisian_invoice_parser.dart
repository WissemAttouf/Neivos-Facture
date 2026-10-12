// lib/utils/tunisian_invoice_parser.dart - VERSION COMPLÈTE
import 'package:intl/intl.dart';

class TunisianInvoiceParser {
  // ✅ EXTRACTION DES CHAMPS SPÉCIFIQUES AUX FACTURES TUNISIENNES
  static Map<String, dynamic> extractTunisianFields(String text) {
    final result = <String, dynamic>{};

    if (text.isEmpty) {
      print('⚠️ Parser tunisien: Texte vide');
      return result;
    }

    print('🔍 Parser tunisien - Analyse du texte (${text.length} caractères)...');

    // 1. NUMÉRO DE FACTURE (formats tunisiens)
    final invoiceNumber = _extractInvoiceNumber(text);
    if (invoiceNumber.isNotEmpty) {
      result['invoice_number'] = invoiceNumber;
      print('✅ Numéro facture: $invoiceNumber');
    }

    // 2. DATE DE FACTURE
    final invoiceDate = _extractInvoiceDate(text);
    if (invoiceDate.isNotEmpty) {
      result['invoice_date'] = invoiceDate;
      print('✅ Date facture: $invoiceDate');
    }

    // 3. FOURNISSEUR
    final supplierName = _extractSupplierName(text);
    if (supplierName.isNotEmpty) {
      result['supplier_name'] = supplierName;
      print('✅ Fournisseur: $supplierName');
    }

    // 4. CLIENT
    final clientName = _extractClientName(text);
    if (clientName.isNotEmpty) {
      result['client_name'] = clientName;
      print('✅ Client: $clientName');
    }

    // 5. MONTANTS FINANCIERS
    final amounts = _extractFinancialAmounts(text);
    result.addAll(amounts);

    // 6. MATRICULE FISCAL
    final matriculeFiscal = _extractMatriculeFiscal(text);
    if (matriculeFiscal.isNotEmpty) {
      result['matricule_fiscal'] = matriculeFiscal;
      print('✅ Matricule fiscal: $matriculeFiscal');
    }

    // 7. ADRESSES
    final addresses = _extractAddresses(text);
    result.addAll(addresses);

    // 8. INFORMATIONS DE CONTACT
    final contactInfo = _extractContactInfo(text);
    result.addAll(contactInfo);

    // 9. INFORMATIONS BANCAIRES
    final bankInfo = _extractBankInfo(text);
    result.addAll(bankInfo);

    // 10. DÉTAILS SUPPLEMENTAIRES
    final details = _extractDetails(text);
    result.addAll(details);

    print('📊 Parser tunisien terminé: ${result.length} champs extraits');
    return result;
  }

  // ✅ EXTRACTION NUMÉRO DE FACTURE
  static String _extractInvoiceNumber(String text) {
    final patterns = [
      // Format tunisien standard: Facture N° 2024/001
      r'Facture\s*(?:N[°o]|No|Numero|Numéro)?\s*[:.]?\s*([A-Z0-9\-/]+)',
      r'FACTURE\s*(?:N[°o]|No|NUMERO)?\s*[:.]?\s*([A-Z0-9\-/]+)',
      r'Invoice\s*(?:#|No)?\s*[:.]?\s*([A-Z0-9\-/]+)',
      r'Bon\s*de\s*Commande\s*(?:N[°o]|No)?\s*[:.]?\s*([A-Z0-9\-/]+)',
      r'BC\s*[:.]?\s*([A-Z0-9\-/]+)',
      r'BL\s*[:.]?\s*([A-Z0-9\-/]+)', // Bon de Livraison
      // Format: REF: 2024-001
      r'(?:Ref|REF|Réf|RÉF)\s*[:.]?\s*([A-Z0-9\-/]+)',
      // Format: N°: INV-2024-001
      r'N[°o]\s*[:.]?\s*([A-Z0-9\-/]+)',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }

    return '';
  }

  // ✅ EXTRACTION DATE DE FACTURE
  static String _extractInvoiceDate(String text) {
    final patterns = [
      // Format: Date: 25/12/2024
      r'Date\s*[:.]?\s*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})',
      r'DATE\s*[:.]?\s*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})',
      // Format: Le 25 Décembre 2024
      r'Le\s+(\d{1,2}\s+\w+\s+\d{4})',
      // Format: Émis le: 25-12-2024
      r'(?:Émis|Emit|Emis)\s+(?:le|à)?\s*[:.]?\s*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})',
      // Format: 25/12/24
      r'\b(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2})\b',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return _normalizeDate(match.group(1)!.trim());
      }
    }

    return '';
  }

  // ✅ NORMALISATION DES DATES
  static String _normalizeDate(String dateStr) {
    try {
      // Essayer différents formats
      if (dateStr.contains('/')) {
        final parts = dateStr.split('/');
        if (parts.length == 3) {
          final day = parts[0].padLeft(2, '0');
          final month = parts[1].padLeft(2, '0');
          final year = parts[2].length == 2 ? '20${parts[2]}' : parts[2];
          return '$year-$month-$day';
        }
      } else if (dateStr.contains('-')) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            return dateStr; // Format déjà YYYY-MM-DD
          } else {
            final day = parts[0].padLeft(2, '0');
            final month = parts[1].padLeft(2, '0');
            final year = parts[2].length == 2 ? '20${parts[2]}' : parts[2];
            return '$year-$month-$day';
          }
        }
      } else if (dateStr.contains('.')) {
        final parts = dateStr.split('.');
        if (parts.length == 3) {
          final day = parts[0].padLeft(2, '0');
          final month = parts[1].padLeft(2, '0');
          final year = parts[2].length == 2 ? '20${parts[2]}' : parts[2];
          return '$year-$month-$day';
        }
      }

      // Essayer avec DateTime
      final parsedDate = DateTime.tryParse(dateStr);
      if (parsedDate != null) {
        return DateFormat('yyyy-MM-dd').format(parsedDate);
      }
    } catch (e) {
      print('⚠️ Erreur normalisation date: $e');
    }

    return dateStr;
  }

  // ✅ EXTRACTION NOM DU FOURNISSEUR
  static String _extractSupplierName(String text) {
    final patterns = [
      r'Fournisseur\s*[:.]?\s*([^\n\r]{5,100})',
      r'FOURNISSEUR\s*[:.]?\s*([^\n\r]{5,100})',
      r'Vendeur\s*[:.]?\s*([^\n\r]{5,100})',
      r'VENDEUR\s*[:.]?\s*([^\n\r]{5,100})',
      r'Société\s*[:.]?\s*([^\n\r]{5,100})',
      r'SOCIÉTÉ\s*[:.]?\s*([^\n\r]{5,100})',
      r'Entreprise\s*[:.]?\s*([^\n\r]{5,100})',
      r'Nom\s*[:.]?\s*([^\n\r]{5,100})',
      // Format: SARL XXX
      r'(?:SARL|S\.A\.R\.L|EURL|S\.A|S\.A\.)\s+([^\n\r]{5,100})',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final name = match.group(1)!.trim();
        // Nettoyer le nom (supprimer les chiffres, caractères spéciaux)
        return _cleanName(name);
      }
    }

    return '';
  }

  // ✅ EXTRACTION NOM DU CLIENT
  static String _extractClientName(String text) {
    final patterns = [
    r'Client\s*[:.]?\s*([^\n\r]{5,100})',
    r'CLIENT\s*[:.]?\s*([^\n\r]{5,100})',
    r'Acheteur\s*[:.]?\s*([^\n\r]{5,100})',
    r'ACHETEUR\s*[:.]?\s*([^\n\r]{5,100})',
    r'Destinataire\s*[:.]?\s*([^\n\r]{5,100})',

    ];

    for (final pattern in patterns) {
    final regex = RegExp(pattern, caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null && match.group(1) != null) {
    final name = match.group(1)!.trim();
    return _cleanName(name);
    }
    }

    return '';
  }

  // ✅ NETTOYAGE DES NOMS
  static String _cleanName(String name) {
    // Supprimer les chiffres, caractères spéciaux
    var cleaned = name.replaceAll(RegExp(r'[\d\t\n\r]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'[^\w\sàâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ\.\-]'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Limiter la longueur
    if (cleaned.length > 100) {
      cleaned = cleaned.substring(0, 100);
    }

    return cleaned;
  }

  // ✅ EXTRACTION DES MONTANTS FINANCIERS
  static Map<String, dynamic> _extractFinancialAmounts(String text) {
    final result = <String, dynamic>{};

    // 1. TOTAL HT
    final htPatterns = [
      r'Total\s+HT\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'HT\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'Montant\s+HT\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'Hors\s+Taxes?\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
    ];

    for (final pattern in htPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final amount = _extractAmount(match.group(1)!);
        if (amount.isNotEmpty) {
          result['total_ht'] = amount;
          print('✅ Total HT: $amount');
          break;
        }
      }
    }

    // 2. TOTAL TTC
    final ttcPatterns = [
      r'Total\s+TTC\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'TTC\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'Montant\s+TTC\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'Total\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
    ];

    for (final pattern in ttcPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final amount = _extractAmount(match.group(1)!);
        if (amount.isNotEmpty) {
          result['total_ttc'] = amount;
          print('✅ Total TTC: $amount');
          break;
        }
      }
    }

    // 3. NET À PAYER
    final netPatterns = [
      r'Net\s+(?:à|a)\s+Payer\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'NET\s+A\s+PAYER\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'Montant\s+Net\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'Solde\s+à\s+Payer\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
    ];

    for (final pattern in netPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final amount = _extractAmount(match.group(1)!);
        if (amount.isNotEmpty) {
          result['net_a_payer'] = amount;
          print('✅ Net à payer: $amount');
          break;
        }
      }
    }

    // 4. TVA
    final tvaPatterns = [
      r'TVA\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'Montant\s+TVA\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'Taxe\s+sur\s+la\s+Valeur\s+Ajoutée\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
    ];

    for (final pattern in tvaPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final amount = _extractAmount(match.group(1)!);
        if (amount.isNotEmpty) {
          result['tva_amount'] = amount;
          print('✅ TVA: $amount');
          break;
        }
      }
    }

    // 5. TAUX TVA
    final tvaRatePatterns = [
      r'Taux\s+TVA\s*[:.]?\s*([\d,.]+\s*%)',
      r'TVA\s+([\d,.]+\s*%)',
      r'Taux\s*[:.]?\s*([\d,.]+\s*%)',
    ];

    for (final pattern in tvaRatePatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final rate = match.group(1)!.replaceAll('%', '').trim().replaceAll(',', '.');
        result['tva_rate'] = rate;
        print('✅ Taux TVA: $rate%');
        break;
      }
    }

    // 6. RETENUE À LA SOURCE (spécifique Tunisie)
    final retenuePatterns = [
      r'Retenue\s+à\s+la\s+Source\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'RETENUE\s+SOURCE\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'R\.S\.\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
    ];

    for (final pattern in retenuePatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final amount = _extractAmount(match.group(1)!);
        if (amount.isNotEmpty) {
          result['retenue_source'] = amount;
          print('✅ Retenue source: $amount');
          break;
        }
      }
    }

    // 7. TIMBRE FISCAL
    final timbrePatterns = [
      r'Timbre\s+Fiscal\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'TIMBRE\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
      r'Droit\s+de\s+Timbre\s*[:.]?\s*([\d\s,.]+\s*(?:TND|€|EUR|USD|DH|Dinars?)?)',
    ];

    for (final pattern in timbrePatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        final amount = _extractAmount(match.group(1)!);
        if (amount.isNotEmpty) {
          result['timbre_fiscal'] = amount;
          print('✅ Timbre fiscal: $amount');
          break;
        }
      }
    }

    return result;
  }

  // ✅ EXTRACTION DES MONTANTS
  static String _extractAmount(String text) {
    // Extraire les chiffres, points et virgules
    final cleaned = text.replaceAll(RegExp(r'[^\d,.]'), '').replaceAll(',', '.');

    // Vérifier si c'est un nombre valide
    if (cleaned.isEmpty) return '';

    try {
      final number = double.tryParse(cleaned);
      if (number != null && number > 0) {
        return number.toStringAsFixed(3);
      }
    } catch (e) {
      print('⚠️ Erreur parsing montant: $e');
    }

    return '';
  }

  // ✅ EXTRACTION MATRICULE FISCAL
  static String _extractMatriculeFiscal(String text) {
    final patterns = [
      // Format tunisien: 7 chiffres + 1 lettre
      r'Matricule\s+Fiscal\s*[:.]?\s*([A-Z0-9]{7}[A-Z])',
      r'MF\s*[:.]?\s*([A-Z0-9]{7}[A-Z])',
      r'M\.F\.\s*[:.]?\s*([A-Z0-9]{7}[A-Z])',
      r'Identifiant\s+Fiscal\s*[:.]?\s*([A-Z0-9]{7}[A-Z])',
      r'ID\.\s+Fisc\.\s*[:.]?\s*([A-Z0-9]{7}[A-Z])',
      // Autres formats possibles
      r'MF\s*:\s*(\d{7}[A-Z])',
      r'Matricule\s*:\s*(\d{7}[A-Z])',
    ];

    for (final pattern in patterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim().toUpperCase();
      }
    }

    return '';
  }

  // ✅ EXTRACTION DES ADRESSES
  static Map<String, dynamic> _extractAddresses(String text) {
    final result = <String, dynamic>{};

    // Adresse fournisseur
    final supplierAddrPatterns = [
      r'Adresse\s+(?:Fournisseur|Vendeur)\s*[:.]?\s*([^\n\r]{10,200})',
      r'Siège\s+Social\s*[:.]?\s*([^\n\r]{10,200})',
    ];

    for (final pattern in supplierAddrPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        result['supplier_address'] = _cleanAddress(match.group(1)!);
        print('✅ Adresse fournisseur extraite');
        break;
      }
    }

    // Adresse client
    final clientAddrPatterns = [
      r'Adresse\s+(?:Client|Acheteur)\s*[:.]?\s*([^\n\r]{10,200})',
      r'Adresse\s+de\s+Livraison\s*[:.]?\s*([^\n\r]{10,200})',
    ];

    for (final pattern in clientAddrPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null && match.group(1) != null) {
        result['client_address'] = _cleanAddress(match.group(1)!);
        print('✅ Adresse client extraite');
        break;
      }
    }

    return result;
  }

  // ✅ NETTOYAGE DES ADRESSES
  static String _cleanAddress(String address) {
    var cleaned = address.trim();
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');

    // Limiter la longueur
    if (cleaned.length > 200) {
      cleaned = cleaned.substring(0, 200);
    }

    return cleaned;
  }

  // ✅ EXTRACTION DES INFORMATIONS DE CONTACT
  static Map<String, dynamic> _extractContactInfo(String text) {
    final result = <String, dynamic>{};

    // Téléphone
    final phoneRegex = RegExp(r'(?:Tél|Tel|Phone|Téléphone)\s*[:.]?\s*([+\d\s\-]{8,20})', caseSensitive: false);
    final phoneMatch = phoneRegex.firstMatch(text);
    if (phoneMatch != null && phoneMatch.group(1) != null) {
      result['phone'] = _cleanPhone(phoneMatch.group(1)!);
      print('✅ Téléphone: ${result['phone']}');
    }

    // Email
    final emailRegex = RegExp(r'(?:Email|E-mail|Mail)\s*[:.]?\s*([\w\.-]+@[\w\.-]+\.\w+)', caseSensitive: false);
    final emailMatch = emailRegex.firstMatch(text);
    if (emailMatch != null && emailMatch.group(1) != null) {
      result['email'] = emailMatch.group(1)!.trim();
      print('✅ Email: ${result['email']}');
    }

    // Fax (optionnel)
    final faxRegex = RegExp(r'(?:Fax|FAX)\s*[:.]?\s*([+\d\s\-]{8,20})', caseSensitive: false);
    final faxMatch = faxRegex.firstMatch(text);
    if (faxMatch != null && faxMatch.group(1) != null) {
      result['fax'] = _cleanPhone(faxMatch.group(1)!);
    }

    return result;
  }

  // ✅ NETTOYAGE NUMÉRO DE TÉLÉPHONE
  static String _cleanPhone(String phone) {
    var cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');

    // Format tunisien: +216 XX XXX XXX
    if (cleaned.startsWith('00216')) {
      cleaned = '+216${cleaned.substring(5)}';
    } else if (cleaned.startsWith('216')) {
      cleaned = '+$cleaned';
    }

    return cleaned;
  }

  // ✅ EXTRACTION DES INFORMATIONS BANCAIRES
  static Map<String, dynamic> _extractBankInfo(String text) {
    final result = <String, dynamic>{};

    // IBAN (format tunisien: TN59 XXXX XXXX XXXX XXXX XXXX)
    final ibanRegex = RegExp(r'(?:IBAN|Iban|RIB|Rib|Compte)\s*[:.]?\s*([A-Z]{2}\d{2}\s*(?:[A-Z0-9]\s*){15,34})', caseSensitive: false);
    final ibanMatch = ibanRegex.firstMatch(text);
    if (ibanMatch != null && ibanMatch.group(1) != null) {
      result['iban'] = ibanMatch.group(1)!.replaceAll(' ', '').toUpperCase();
      print('✅ IBAN: ${result['iban']}');
    }

    // Banque
    final bankRegex = RegExp(r'(?:Banque|Bank|BANK)\s*[:.]?\s*([^\n\r]{5,100})', caseSensitive: false);
    final bankMatch = bankRegex.firstMatch(text);
    if (bankMatch != null && bankMatch.group(1) != null) {
      result['bank_name'] = bankMatch.group(1)!.trim();
    }

    // SWIFT/BIC
    final swiftRegex = RegExp(r'(?:SWIFT|BIC|Swift|Bic)\s*[:.]?\s*([A-Z]{6}[A-Z0-9]{2}(?:[A-Z0-9]{3})?)', caseSensitive: false);
    final swiftMatch = swiftRegex.firstMatch(text);
    if (swiftMatch != null && swiftMatch.group(1) != null) {
      result['swift_code'] = swiftMatch.group(1)!.trim().toUpperCase();
    }

    return result;
  }

  // ✅ EXTRACTION DES DÉTAILS SUPPLEMENTAIRES
  static Map<String, dynamic> _extractDetails(String text) {
    final result = <String, dynamic>{};

    // Conditions de paiement
    final paymentTermsRegex = RegExp(r'(?:Conditions|Modalités)\s+(?:de\s+)?Paiement\s*[:.]?\s*([^\n\r]{10,200})', caseSensitive: false);
    final paymentTermsMatch = paymentTermsRegex.firstMatch(text);
    if (paymentTermsMatch != null && paymentTermsMatch.group(1) != null) {
      result['payment_terms'] = paymentTermsMatch.group(1)!.trim();
      print('✅ Conditions paiement: ${result['payment_terms']}');
    }

    // Date d'échéance
    final dueDateRegex = RegExp(r'(?:Échéance|Echeance|Due\s+Date)\s*[:.]?\s*(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4})', caseSensitive: false);
    final dueDateMatch = dueDateRegex.firstMatch(text);
    if (dueDateMatch != null && dueDateMatch.group(1) != null) {
      result['due_date'] = _normalizeDate(dueDateMatch.group(1)!.trim());
      print('✅ Date échéance: ${result['due_date']}');
    }

    // Description
    final descriptionRegex = RegExp(r'(?:Description|Désignation|Article)\s*[:.]?\s*([^\n\r]{10,500})', caseSensitive: false);
    final descriptionMatch = descriptionRegex.firstMatch(text);
    if (descriptionMatch != null && descriptionMatch.group(1) != null) {
      result['description'] = descriptionMatch.group(1)!.trim();
    }

    // Devise (par défaut TND pour Tunisie)
    result['currency'] = 'TND';

    // Pays (par défaut Tunisie)
    result['country'] = 'Tunisie';

    return result;
  }

  // ✅ MÉTHODE POUR VALIDER UNE FACTURE TUNISIENNE
  static Map<String, dynamic> validateTunisianInvoice(Map<String, dynamic> data) {
    final errors = <String, String>{};
    final warnings = <String, String>{};

    // Champs obligatoires
    final requiredFields = ['invoice_number', 'invoice_date', 'supplier_name', 'total_ttc'];
    for (final field in requiredFields) {
      if (!data.containsKey(field) || data[field]?.toString().isEmpty == true) {
        errors[field] = 'Champ obligatoire manquant';
      }
    }

    // Validation du matricule fiscal (format: 7 chiffres + 1 lettre)
    if (data.containsKey('matricule_fiscal')) {
      final mf = data['matricule_fiscal'].toString();
      if (!RegExp(r'^[A-Z0-9]{7}[A-Z]$').hasMatch(mf)) {
        warnings['matricule_fiscal'] = 'Format matricule fiscal suspect';
      }
    }

    // Validation des montants
    final amountFields = ['total_ht', 'total_ttc', 'tva_amount', 'net_a_payer'];
    for (final field in amountFields) {
      if (data.containsKey(field)) {
        final amountStr = data[field].toString();
        if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(amountStr)) {
          warnings[field] = 'Format montant invalide';
        }
      }
    }

    return {
      'is_valid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
      'missing_fields': _getMissingFields(data),
    };
  }

  // ✅ IDENTIFIER LES CHAMPS MANQUANTS
  static List<String> _getMissingFields(Map<String, dynamic> data) {
    final idealFields = [
      'invoice_number', 'invoice_date', 'supplier_name', 'supplier_address',
      'supplier_tax_id', 'client_name', 'client_address', 'client_tax_id',
      'total_ht', 'total_ttc', 'tva_amount', 'tva_rate', 'net_a_payer',
      'retenue_source', 'timbre_fiscal', 'matricule_fiscal', 'currency',
      'payment_terms', 'due_date', 'iban', 'phone', 'email', 'description'
    ];

    return idealFields.where((field) =>
    !data.containsKey(field) || data[field]?.toString().isEmpty == true
    ).toList();
  }

  // ✅ MÉTHODE POUR CALCULER LES CHAMPS MANQUANTS
  static Map<String, dynamic> calculateMissingFields(Map<String, dynamic> data) {
    final calculated = Map<String, dynamic>.from(data);

    final totalHT = double.tryParse(data['total_ht']?.toString() ?? '0') ?? 0;
    final totalTTC = double.tryParse(data['total_ttc']?.toString() ?? '0') ?? 0;
    final tvaAmount = double.tryParse(data['tva_amount']?.toString() ?? '0') ?? 0;
    final tvaRate = double.tryParse(data['tva_rate']?.toString() ?? '0') ?? 0;

    // Calculer TVA si manquant
    if (totalHT > 0 && totalTTC > totalHT && tvaAmount == 0) {
      final calculatedTVA = totalTTC - totalHT;
      calculated['tva_amount'] = calculatedTVA.toStringAsFixed(3);

      if (tvaRate == 0) {
        final calculatedRate = (calculatedTVA / totalHT) * 100;
        calculated['tva_rate'] = calculatedRate.toStringAsFixed(1);
      }
    }

    // Calculer net à payer si manquant
    if (totalTTC > 0 && !calculated.containsKey('net_a_payer')) {
      final retenue = double.tryParse(data['retenue_source']?.toString() ?? '0') ?? 0;
      final timbre = double.tryParse(data['timbre_fiscal']?.toString() ?? '0') ?? 0;
      final netAPayer = totalTTC - retenue - timbre;

      if (netAPayer > 0) {
        calculated['net_a_payer'] = netAPayer.toStringAsFixed(3);
        calculated['net_a_payer_calculated'] = true;
      }
    }

    // Ajouter timbre fiscal par défaut (0.600 TND)
    if (!calculated.containsKey('timbre_fiscal')) {
      calculated['timbre_fiscal'] = '0.600';
      calculated['timbre_fiscal_default'] = true;
    }

    return calculated;
  }
}
