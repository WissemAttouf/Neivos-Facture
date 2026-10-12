// lib/services/api_diagnostic_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiDiagnosticService {
  static Future<Map<String, dynamic>> performFullDiagnosis(String baseUrl) async {
    final results = <String, dynamic>{
      'server_accessible': false,
      'database_connected': false,
      'endpoints_working': <String>[],
      'errors': <String>[],
    };

    try {
      print('\n🔍 DIAGNOSTIC COMPLET API...');

      // Test connexion serveur
      print('1. Test de connexion serveur...');
      final healthResponse = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 10));

      if (healthResponse.statusCode == 200) {
        results['server_accessible'] = true;
        final healthData = json.decode(healthResponse.body);
        results['database_connected'] = healthData['database'] == 'Connected';
        print('✅ Serveur accessible - BDD: ${healthData['database']}');
      } else {
        (results['errors'] as List<String>).add('Serveur inaccessible: ${healthResponse.statusCode}');
      }

      // Test endpoints
      final endpoints = [
        {'name': 'OCR', 'url': '/api/ocr', 'method': 'POST'},
        {'name': 'Login', 'url': '/login', 'method': 'POST'},
      ];

      for (var endpoint in endpoints) {
        try {
          final response = await http.post(
            Uri.parse('$baseUrl${endpoint['url']}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'test': 'data'}),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200 || response.statusCode == 201) {
            (results['endpoints_working'] as List<String>).add(endpoint['name'] as String);
          }
        } catch (e) {
          // Ignorer les erreurs pour les tests
        }
      }

      print('✅ Diagnostic terminé');
      return results;

    } catch (e) {
      (results['errors'] as List<String>).add('Erreur diagnostic: $e');
      return results;
    }
  }

  static Future<void> quickDiagnose(String baseUrl) async {
    print('\n🔍 DIAGNOSTIC RAPIDE API...');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('🎉 SERVEUR ACCESSIBLE');
        print('📊 Status: ${data['status']}');
        print('🗄️  Base de données: ${data['database']}');
        print('🌐 URL: $baseUrl');
        print('📱 Votre application peut se connecter !');
      } else {
        print('❌ SERVEUR INACCESSIBLE');
        print('📡 Status: ${response.statusCode}');
        print('💡 Vérifiez: http://37.60.239.139:8086/health');
      }
    } catch (e) {
      print('❌ ERREUR CONNEXION: $e');
      print('🔧 Solutions:');
      print('1. Vérifiez que le serveur Node.js est démarré');
      print('2. Vérifiez le firewall Windows');
      print('3. Testez depuis votre navigateur mobile');
    }
  }
}
