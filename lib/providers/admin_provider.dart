// lib/providers/admin_provider.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/admin_stats_model.dart';
import '../services/admin_api_service.dart';

class AdminProvider with ChangeNotifier {


  Future<void> loadAllData(String token) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    print('🔄 Chargement de toutes les données admin...');

  
      print('✅ Toutes les données chargées avec succès');
    } catch (e) {
      print('❌ Erreur chargement données: $e');
      _error = 'Erreur: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadStats(String token) async {
    try {
     
      }
    } catch (e) {
      print('❌ Exception stats: $e');
    }
    notifyListeners();
  }

  Future<void> loadUsers(String token) async {
    try {
      print('👥 Chargement des utilisateurs...');
      final response = await _apiService.getUsers(token);

      if (response['success'] == true) {
        _users = (response['users'] as List)
            .map((u) => UserModel.fromJson(u))
            .toList();
       
      }
    } catch (e) {
      print('❌ Exception users: $e');
    }
    notifyListeners();
  }

  Future<void> loadAllInvoices(String token) async {
    try {
      print('📄 Chargement des factures...');
      final response = await _apiService.getAllInvoices(token);

      
          totalAmount += amount;
        }
        print('💰 Montant total des factures: ${totalAmount.toStringAsFixed(3)} TND');
      }
    } catch (e) {
      print('❌ Exception invoices: $e');
    }
    notifyListeners();
  }

  // ============ GESTION DES UTILISATEURS ============

  Future<bool> createUser(String token, Map<String, dynamic> userData) async {
    _isLoading = true;
    notifyListeners();

   
      notifyListeners();
    }
  }

  Future<bool> updateUser(String token, int userId, Map<String, dynamic> userData) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.updateUser(token, userId, userData);
      if (response['success'] == true) {
        await loadUsers(token);
        await loadStats(token);
        return true;
      } else {
        _error = response['message'] ?? 'Erreur modification utilisateur';
        return false;
      }
    } catch (e) {
      _error = 'Erreur: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteUser(String token, int userId) async {
    _isLoading = true;
    notifyListeners();

    
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changeUserRole(String token, int userId, String role) async {
    return updateUser(token, userId, {'role': role});
  }

  Future<bool> toggleUserStatus(String token, int userId, bool isActive) async {
    return updateUser(token, userId, {'is_active': isActive});
  }

  // ============ GESTION DES FACTURES ============

  Future<bool> deleteInvoice(String token, String invoiceId) async {
    _isLoading = true;
    notifyListeners();

    
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateInvoice(String token, String invoiceId, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    
  // ============ PARAMÈTRES SYSTÈME ============

  Future<void> loadSettings(String token) async {
    try {
      final response = await _apiService.getSettings(token);
      if (response['success'] == true) {
        _systemSettings = response['settings'] ?? {};
      }
    } catch (e) {
      print('❌ Erreur chargement paramètres: $e');
    }
    notifyListeners();
  }

  Future<bool> updateSettings(String token, Map<String, dynamic> settings) async {
    _isLoading = true;
    notifyListeners();

   
  void clearError() {
    _error = '';
    notifyListeners();
  }

  void reset() {
    _users = [];
   
}
