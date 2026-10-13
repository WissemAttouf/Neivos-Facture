// lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import '../models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  UserModel? _user;
  

 

  
  static const String _baseUploadUrl = 'http://10.123.109.205/uploads/profiles/';

  // 🔐 LOGIN
  Future<void> login(String email, String password) async {
    _isLoading = true;
    

    try {
      print('🔐 Tentative de connexion: $email');
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password.trim()}),
      ).timeout(const Duration(seconds: 30));

      print('📥 Réponse login: ${response.statusCode}');

      
          await _saveUser(data['user'], data['accessToken']);
          print('✅ LOGIN RÉUSSI: ${_user?.username} (Rôle: ${_user?.role})');

          notifyListeners();
          return;
        }
      }

      if (response.statusCode == 401) {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Identifiants incorrects');
      } else if (response.statusCode == 400) {
        throw Exception('Données invalides');
      }
      notifyListeners();
    }
  }

  // 📝 INSCRIPTION
  Future<void> register(String username, String email, String password, String gender) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('📝 Tentative d\'inscription: $username ($email)');
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'email': email.trim(),
          'password': password.trim(),
          'gender': gender,
        }),
      ).timeout(const Duration(seconds: 30));

      print('📥 Réponse inscription: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);

        

          print('✅ INSCRIPTION RÉUSSIE: ${_user?.username}');
          notifyListeners();
          return;
        }
      }

      if (response.statusCode == 409) {
        throw Exception('Un compte avec cet email existe déjà');
      } else if (response.statusCode == 400) {
        throw Exception('Données invalides');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors de l\'inscription');
      }

    }
  // ✅ EFFACER L'ERREUR
  void clearError() {
    if (_error.isNotEmpty) {
      _error = '';
      notifyListeners();
    }
  }

  // 🔄 AUTO-LOGIN
  Future<void> autoLogin() async {
    

        print('✅ Auto-login réussi: ${_user?.username} (Rôle: ${_user?.role})');
        notifyListeners();
      } else {
        print('ℹ️ Aucune donnée d\'auto-login trouvée');
      }
    } catch (e) {
      print('❌ Erreur auto-login: $e');
      await logout();
    }
  }

  // 🚪 DÉCONNEXION
  Future<void> logout() async {
    print('🚪 Déconnexion de l\'utilisateur...');
    _user = null;
    _authToken = null;
    _isConnected = false;
    _error = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userData');
    await prefs.remove('authToken');
    await prefs.remove('isLoggedIn');
    await prefs.remove('profileImageUrl');

    print('✅ Déconnexion réussie');
    notifyListeners();
  }

  // 💾 SAUVEGARDE LOCALE
  Future<void> _saveUser(Map<String, dynamic> userData, String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userData', jsonEncode(userData));
      await prefs.setString('authToken', token);
      await prefs.setBool('isLoggedIn', true);
      print('💾 Données utilisateur sauvegardées localement');
    } catch (e) {
      print('❌ Erreur sauvegarde locale: $e');
    }
  }

  // 🌍 TEST CONNEXION SERVEUR
  Future<bool> testServerConnection() async {
    try {
      print('🌍 Test de connexion au serveur...');
      final response = await http.get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 5));

      final isConnected = response.statusCode == 200;
      print('📡 Serveur ${isConnected ? 'accessible' : 'inaccessible'}');

      return isConnected;
    } catch (e) {
      print('❌ Serveur inaccessible: $e');
      return false;
    }
  }

  // ✅ OBTENIR L'ID UTILISATEUR
  
      }

      print('⚠️ Aucun ID utilisateur trouvé');
      return -1;
    } catch (e) {
      print('❌ Erreur récupération ID utilisateur: $e');
      return -1;
    }
  }

  // ✅ MISE À JOUR DU PROFIL
  Future<void> updateUserProfile({
    required String newUsername,
    required String newEmail,
    String? newPassword,
    String? currentPassword,
    File? profileImage,
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('🔄 Mise à jour du profil vers le serveur...');

      if (_authToken == null) {
        throw Exception('Non authentifié');
      }

      if (newUsername.isEmpty) throw Exception('Le nom d\'utilisateur est requis');
      if (newEmail.isEmpty) throw Exception('L\'email est requis');

      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(newEmail)) {
        throw Exception('Format d\'email invalide');
      }

      if (newPassword != null && newPassword.isNotEmpty) {
        if (currentPassword == null || currentPassword.isEmpty) {
          throw Exception('Le mot de passe actuel est requis');
        }
        if (newPassword.length < 6) {
          throw Exception('Le mot de passe doit contenir au moins 6 caractères');
        }
      }

      var uri = Uri.parse('$_baseUrl/profile');
      var request = http.MultipartRequest('PUT', uri);

      request.headers['Authorization'] = 'Bearer $_authToken';

      request.fields['username'] = newUsername;
      request.fields['email'] = newEmail;

      if (newPassword != null && newPassword.isNotEmpty) {
        request.fields['newPassword'] = newPassword;
        request.fields['currentPassword'] = currentPassword!;
      }

      if (profileImage != null) {
        if (!await profileImage.exists()) {
          throw Exception('Le fichier image n\'existe pas');
        }

        

      print('📥 Réponse status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['user'] != null) {
          _user = UserModel.fromJson(data['user']);
          await _saveUser(data['user'], _authToken!);
          print('✅ Profil mis à jour avec succès');
          notifyListeners();
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      print('❌ Erreur updateUserProfile: $_error');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ RÉCUPÉRER LE PROFIL
  Future<void> fetchUserProfile() async {
    if (_authToken == null) {
      print('❌ Token manquant pour fetchUserProfile');
      return;
    }

    try {
      print('🔄 Récupération du profil depuis le serveur...');
      final response = await http.get(
        Uri.parse('$_baseUrl/profile'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      );

      print('📥 Réponse fetchProfile: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['user'] != null) {
          _user = UserModel.fromJson(data['user']);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('userData', jsonEncode(data['user']));

         
      print('❌ Erreur fetchUserProfile: $e');
    }
  }

  // 🗑️ SUPPRIMER L'IMAGE DE PROFIL
  Future<void> deleteProfileImage() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      print('🗑️ Suppression de l\'image de profil...');

      final response = await http.delete(
        Uri.parse('$_baseUrl/profile/image'),
        headers: {
          'Authorization': 'Bearer $_authToken',
        },
      ).timeout(const Duration(seconds: 30));

      print('📥 Réponse suppression image: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          await fetchUserProfile();
          print('✅ Image de profil supprimée avec succès');
          notifyListeners();
          return;
        } else {
          throw Exception(data['message'] ?? 'Erreur lors de la suppression');
        }
      } else {
        throw Exception('Erreur serveur: ${response.statusCode}');
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      print('❌ Erreur deleteProfileImage: $_error');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

 
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Erreur lors du changement de mot de passe');
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      print('❌ Erreur changePassword: $_error');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ MOT DE PASSE OUBLIÉ (NOUVELLE FONCTION)
  Future<void> forgotPassword(String email) async {
    try {
      print('🔄 Demande de réinitialisation pour: $email');

      final response = await http.post(
        Uri.parse('$_baseUrl/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ Email de réinitialisation envoyé');
        return;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Erreur lors de la demande. Vérifiez l\'email.');
      }
    } catch (e) {
      print('❌ Erreur forgotPassword: $e');
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ✅ VALIDER LE TOKEN
  Future<bool> validateToken() async {
    if (_authToken == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/profile'),
        headers: {'Authorization': 'Bearer $_authToken'},
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  ;
  }

  // 🐛 DÉBOGAGE
  void debugPrintUser() {
    print('🔍 DEBUG USER:');
    print('   - ID: ${_user?.id}');
    print('   - Username: ${_user?.username}');
    print('   - Email: ${_user?.email}');
    print('   - Rôle: ${_user?.role}');
    print('   - Actif: ${_user?.isActive}');
    print('   - ProfileImage: ${_user?.profileImage}');
  }
}

