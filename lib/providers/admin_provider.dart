// lib/providers/admin_provider.dart
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/admin_stats_model.dart';
import '../services/admin_api_service.dart';

class AdminProvider with ChangeNotifier {
  final AdminApiService _apiService = AdminApiService();

  List<UserModel> _users = [];
  bool _isLoading = false;
  String _error = '';
  AdminStatsModel? _stats;
  List<Map<String, dynamic>> _invoices = [];
  Map<String, dynamic> _systemSettings = {};

  List<UserModel> get users => _users;
  bool get isLoading => _isLoading;
  String get error => _error;
  AdminStatsModel? get stats => _stats;
  List<Map<String, dynamic>> get invoices => _invoices;
  Map<String, dynamic> get systemSettings => _systemSettings;

  // ============ CHARGEMENT DES DONNÉES ============

  Future<void> loadAllData(String token) async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    print('🔄 Chargement de toutes les données admin...');

    try {
      // Charger les statistiques
      await loadStats(token);

      // Charger les utilisateurs
      await loadUsers(token);

      // Charger les factures
      await loadAllInvoices(token);

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
      print('📊 Chargement des statistiques...');
      final response = await _apiService.getStats(token);
      print('📥 Réponse stats: ${response['success']}');

      if (response['success'] == true) {
        _stats = AdminStatsModel.fromJson(response['stats']);
        print('✅ Stats: ${_stats?.totalUsers} utilisateurs, ${_stats?.totalInvoices} factures, ${_stats?.totalAmount} TND');
      } else {
        print('❌ Erreur stats: ${response['message']}');
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
        print('✅ ${_users.length} utilisateurs chargés');

        // Afficher les rôles
        int adminCount = _users.where((u) => u.role == 'admin').length;
        int accountantCount = _users.where((u) => u.role == 'accountant').length;
        int userCount = _users.where((u) => u.role == 'user').length;
        print('   - Admins: $adminCount');
        print('   - Comptables: $accountantCount');
        print('   - Utilisateurs: $userCount');
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

      if (response['success'] == true) {
        _invoices = List<Map<String, dynamic>>.from(response['invoices']);
        print('✅ ${_invoices.length} factures chargées');

        // Calculer le montant total réel
        double totalAmount = 0;
        for (var inv in _invoices) {
          double amount = 0;
          if (inv['total_ttc'] != null) {
            if (inv['total_ttc'] is num) {
              amount = (inv['total_ttc'] as num).toDouble();
            } else if (inv['total_ttc'] is String) {
              amount = double.tryParse(inv['total_ttc']) ?? 0;
            }
          }
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

    try {
      final response = await _apiService.createUser(token, userData);
      if (response['success'] == true) {
        await loadUsers(token);
        await loadStats(token);
        return true;
      } else {
        _error = response['message'] ?? 'Erreur création utilisateur';
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

    try {
      final response = await _apiService.deleteUser(token, userId);
      if (response['success'] == true) {
        await loadUsers(token);
        await loadStats(token);
        return true;
      } else {
        _error = response['message'] ?? 'Erreur suppression utilisateur';
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

    try {
      final response = await _apiService.deleteInvoice(token, invoiceId);
      if (response['success'] == true) {
        await loadAllInvoices(token);
        await loadStats(token);
        return true;
      } else {
        _error = response['message'] ?? 'Erreur suppression facture';
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

  Future<bool> updateInvoice(String token, String invoiceId, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.updateInvoice(token, invoiceId, data);
      if (response['success'] == true) {
        await loadAllInvoices(token);
        await loadStats(token);
        return true;
      } else {
        _error = response['message'] ?? 'Erreur modification facture';
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

    try {
      final response = await _apiService.updateSettings(token, settings);
      if (response['success'] == true) {
        _systemSettings = {..._systemSettings, ...settings};
        return true;
      } else {
        _error = response['message'] ?? 'Erreur mise à jour paramètres';
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

  void clearError() {
    _error = '';
    notifyListeners();
  }

  void reset() {
    _users = [];
    _invoices = [];
    _stats = null;
    _systemSettings = {};
    _error = '';
    _isLoading = false;
    notifyListeners();
  }
}
