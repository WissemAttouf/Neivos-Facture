// lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  final String baseUrl;
  static const String OCR_API_URL = 'http://37.60.239.139:8775';

  ApiService({required this.baseUrl});

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('authToken');
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<bool> testOcrConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur test connexion: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('authToken', result['accessToken']);
          await prefs.setString('userData', json.encode(result['user']));
          return result;
        }
      }
      throw Exception('Identifiants incorrects');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> register(String username, String email, String password, String gender) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': username,
          'email': email,
          'password': password,
          'gender': gender,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 201) {
        final result = json.decode(response.body);
        if (result['success'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('authToken', result['accessToken']);
          await prefs.setString('userData', json.encode(result['user']));
          return result;
        }
      }
      throw Exception('Erreur inscription');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('authToken');
    await prefs.remove('userData');
  }

  // ✅ MÉTHODE PRINCIPALE D'EXTRACTION OCR MULTIPLE
  Future<List<Map<String, dynamic>>> extractMultipleInvoicesWithOCR(List<File> imageFiles) async {
    print('🚀 Extraction OCR Multiple (${imageFiles.length} fichiers)...');

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$OCR_API_URL/extract-invoices/'),
      );

      for (var i = 0; i < imageFiles.length; i++) {
        final fileBytes = await imageFiles[i].readAsBytes();
        final fileName = 'invoice_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        request.files.add(
          http.MultipartFile.fromBytes(
            'files',
            fileBytes,
            filename: fileName,
            contentType: http.MediaType('image', 'jpeg'),
          ),
        );
      }

      request.headers['Accept'] = 'application/json';

      print('📤 Envoi à API OCR...');
      final streamedResponse = await request.send().timeout(const Duration(seconds: 120));
      final response = await http.Response.fromStream(streamedResponse);

      print('📊 Status API OCR: ${response.statusCode}');
      print('📥 Réponse brute API OCR: ${response.body}'); // <-- TRÈS IMPORTANT POUR LE DÉBOGAGE

      return _parseMultipleOCRResponse(response);

    } on SocketException catch (e) {
      print('❌ Erreur réseau: $e');
      throw Exception('Impossible de se connecter au serveur OCR');
    } on TimeoutException catch (e) {
      print('❌ Timeout: $e');
      throw Exception('Timeout de connexion (120s)');
    } catch (e) {
      print('❌ Erreur API: $e');
      rethrow;
    }
  }

  // ✅ ANALYSE DE LA RÉPONSE OCR MULTIPLE (CORRIGÉE)
  List<Map<String, dynamic>> _parseMultipleOCRResponse(http.Response response) {
    if (response.statusCode == 200) {
      try {
        final result = json.decode(response.body);
        List<Map<String, dynamic>> allResults = [];

        // L'API Swagger renvoie une liste d'objets
        if (result is List) {
          for (var item in result) {
            Map<String, dynamic> extractedData = {};

            // ✅ CORRECTION MAJEURE ICI : On lit directement "data_json"
            if (item is Map && item.containsKey('data_json')) {
              final dataJson = item['data_json'];

              if (dataJson is Map) {
                // Si c'est déjà un Map (objet JSON)
                extractedData = Map<String, dynamic>.from(dataJson);
              } else if (dataJson is String) {
                // Si c'est une String JSON qu'il faut décoder
                try {
                  final parsed = json.decode(dataJson);
                  extractedData = Map<String, dynamic>.from(parsed);
                } catch (e) {
                  print('⚠️ Erreur parsing string data_json: $e');
                }
              }
            }

            print('✅ Données extraites brutes: $extractedData');

            // On standardise les clés (nom_fournisseur -> supplier_name, etc.)
            extractedData = _standardizeData(extractedData);

            allResults.add({
              'success': true,
              'data': extractedData,
              'text': item['raw_text']?.toString() ?? '',
              'confidence': 1.0,
            });
          }
        }
        // Au cas où l'API renvoie un seul objet au lieu d'une liste
        else if (result is Map) {
          Map<String, dynamic> extractedData = {};
          if (result.containsKey('data_json')) {
            final dataJson = result['data_json'];
            if (dataJson is Map) {
              extractedData = Map<String, dynamic>.from(dataJson);
            }
          } else {
            extractedData = Map<String, dynamic>.from(result);
          }

          extractedData = _standardizeData(extractedData);
          allResults.add({
            'success': true,
            'data': extractedData,
            'text': result['raw_text']?.toString() ?? '',
            'confidence': 1.0,
          });
        }

        return allResults;

      } catch (e) {
        print('⚠️ Erreur parsing JSON global: $e');
        throw Exception('Erreur de traitement des données OCR');
      }
    } else {
      throw Exception('API OCR échouée: ${response.statusCode}');
    }
  }

  // ✅ STANDARDISATION DES DONNÉES (Traduction FR -> EN)
  Map<String, dynamic> _standardizeData(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);

    // Ce mapping fait le lien entre ce que l'API Swagger donne et ce que l'App attend
    final mapping = {
      'nom_fournisseur': 'supplier_name',
      'adresse_fournisseur': 'supplier_address',
      'mf_fournisseur': 'supplier_tax_id',
      'nom_client': 'client_name',
      'adresse_client': 'client_address',
      'mf_client': 'client_tax_id',
      'numero_facture': 'invoice_number',
      'date_facture': 'invoice_date',
      'total_ht': 'total_ht',
      'total_ttc': 'total_ttc',
      'montant_tva': 'tva_amount',
      'taux_tva': 'tva_rate',
      'description': 'description'
    };

    // On parcourt les données reçues de l'API
    final originalKeys = List<String>.from(result.keys);
    for (final key in originalKeys) {
      final value = result[key];
      if (value == null) continue;

      // Si la clé de l'API existe dans notre mapping, on crée la nouvelle clé anglaise
      if (mapping.containsKey(key)) {
        final newKey = mapping[key]!;
        result[newKey] = value;
      }
    }

    return result;
  }

  Future<List<dynamic>> getInvoices(String userId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/invoices/user/$userId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['invoices'] ?? [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteDocument(String documentId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/invoices/$documentId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteInvoiceAsAdmin(String invoiceId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/admin/invoices/$invoiceId'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> saveInvoice(Map<String, dynamic> invoiceData) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Non authentifié');

      final response = await http.post(
        Uri.parse('$baseUrl/api/invoices/save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(invoiceData),
      );

      final responseData = json.decode(response.body);
      if (response.statusCode == 201 || response.statusCode == 409) {
        return responseData;
      } else {
        throw Exception(responseData['message'] ?? 'Erreur lors de la sauvegarde');
      }
    } catch (e) {
      throw Exception('Erreur de connexion: $e');
    }
  }
}
