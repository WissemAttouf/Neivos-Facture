// lib/services/admin_api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class AdminApiService {
  static const String baseUrl = '10.123.109.205:8086';

  Map<String, String> _getHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // ============ GESTION DES UTILISATEURS ============

  Future<Map<String, dynamic>> getUsers(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/admin/users'),
      headers: _getHeaders(token),
    );
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> createUser(String token, Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/admin/users'),
      headers: _getHeaders(token),
      body: json.encode(userData),
    );
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> updateUser(String token, int userId, Map<String, dynamic> userData) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/admin/users/$userId'),
      headers: _getHeaders(token),
      body: json.encode(userData),
    );
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> deleteUser(String token, int userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/admin/users/$userId'),
      headers: _getHeaders(token),
    );
    return json.decode(response.body);
  }

  // ============ STATISTIQUES ============

  Future<Map<String, dynamic>> getStats(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/admin/stats'),
      headers: _getHeaders(token),
    );
    return json.decode(response.body);
  }

  // ============ GESTION DES FACTURES ============

  Future<Map<String, dynamic>> getAllInvoices(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/admin/invoices'),
      headers: _getHeaders(token),
    );
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> deleteInvoice(String token, String invoiceId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/api/admin/invoices/$invoiceId'),
      headers: _getHeaders(token),
    );
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> updateInvoice(String token, String invoiceId, Map<String, dynamic> data) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/admin/invoices/$invoiceId'),
      headers: _getHeaders(token),
      body: json.encode(data),
    );
    return json.decode(response.body);
  }

  // ============ PARAMÈTRES SYSTÈME ============

  Future<Map<String, dynamic>> getSettings(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/admin/settings'),
      headers: _getHeaders(token),
    );
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> updateSettings(String token, Map<String, dynamic> settings) async {
    final response = await http.put(
      Uri.parse('$baseUrl/api/admin/settings'),
      headers: _getHeaders(token),
      body: json.encode({'settings': settings}),
    );
    return json.decode(response.body);
  }
}
