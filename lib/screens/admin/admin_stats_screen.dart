// lib/screens/admin/admin_stats_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/particle_background.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  List<dynamic> _bugReports = [];
  bool _isLoadingBugs = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);

    if (authProvider.authToken != null) {
      await adminProvider.loadAllData(authProvider.authToken!);
      await _loadBugReports(authProvider.authToken!);
    }
  }

  Future<void> _loadBugReports(String token) async {
    setState(() => _isLoadingBugs = true);
    try {
      // Ajustez l'URL de votre backend ici (identique à celle du login)
      final response = await http.get(
        Uri.parse('http://10.123.109.205:8086/api/admin/bug-reports'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _bugReports = data['reports'] ?? [];
          });
        }
      }
    } catch (e) {
      print('❌ Erreur chargement des bugs: $e');
    } finally {
      setState(() => _isLoadingBugs = false);
    }
  }

  String _formatAmount(dynamic value) {
    if (value == null) return '0.000 TND';
    try {
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return '${parsed.toStringAsFixed(3)} TND';
        return '$value TND';
      }
      if (value is num) return '${value.toStringAsFixed(3)} TND';
      return '0.000 TND';
    } catch (e) {
      return '0.000 TND';
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final adminProvider = Provider.of<AdminProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final stats = adminProvider.stats;
    final users = adminProvider.users;

    int totalUsers = stats?.totalUsers ?? users.length;
    int totalInvoices = stats?.totalInvoices ?? adminProvider.invoices.length;
    double totalAmount = stats?.totalAmount ?? 0;

    if (totalAmount == 0 && adminProvider.invoices.isNotEmpty) {
      for (var inv in adminProvider.invoices) {
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
    }

    int activeUsers = users.where((u) => u.isActive).length;
    int inactiveUsers = users.where((u) => !u.isActive).length;

    // N'afficher et ne compter que les admins et les comptables comme demandé
    int adminCount = users.where((u) => u.role == 'admin').length;
    int accountantCount = users.where((u) => u.role == 'accountant').length;

    if (adminProvider.isLoading && stats == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cartes statistiques principales
            LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = (constraints.maxWidth - 16) / 2;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: _buildStatCard(
                        context,
                        title: 'Utilisateurs',
                        value: totalUsers.toString(),
                        icon: Icons.people,
                        color: Colors.blue,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildStatCard(
                        context,
                        title: 'Factures scannées',
                        value: totalInvoices.toString(),
                        icon: Icons.receipt,
                        color: Colors.green,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildStatCard(
                        context,
                        title: 'Montant Total',
                        value: _formatAmount(totalAmount),
                        icon: Icons.attach_money,
                        color: Colors.orange,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: _buildStatCard(
                        context,
                        title: 'Actifs/Inactifs',
                        value: '$activeUsers/$inactiveUsers',
                        icon: Icons.person_outline,
                        color: Colors.purple,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Répartition des rôles (Uniquement Admin et Comptable modifiée)
            Card(
              elevation: 3,
              color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.admin_panel_settings, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 10),
                        Text(
                          'Répartition des rôles',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildRoleChip('Administrateurs', adminCount, Colors.red, isDarkMode),
                        _buildRoleChip('Comptables', accountantCount, Colors.blue, isDarkMode),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Remplacement d'Activité Récente par Bugs (Signalement)
            Card(
              elevation: 3,
              color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bug_report, color: Colors.orange),
                        const SizedBox(width: 10),
                        Text(
                          'Signalements de bugs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingBugs)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_bugReports.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text('Aucun bug n\'a été signalé récemment'),
                        ),
                      )
                    else
                      Column(
                        children: _bugReports.map((report) =>
                            _buildBugReportItem(context, report, isDarkMode)
                        ).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDarkMode,
  }) {
    return Card(
      elevation: 3,
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String label, int count, Color color, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.white70 : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBugReportItem(BuildContext context, Map<String, dynamic> report, bool isDarkMode) {
    String subject = report['subject'] ?? 'Sans sujet';
    String description = report['description'] ?? 'Aucune description';
    String userName = report['user_name'] ?? 'Utilisateur inconnu';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isDarkMode ? Colors.grey[800] : Colors.grey[50],
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.orangeAccent,
            child: Icon(Icons.bug_report, color: Colors.white, size: 20),
          ),
          title: Text(
            subject,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          subtitle: Text(
            'Signalé par: $userName\nLe: ${_formatDate(report['reported_at'])}',
            style: const TextStyle(fontSize: 11),
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black12 : Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Description du problème :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 8),
                  Text('Info Appareil: ${report['device_info'] ?? 'N/A'}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '';
    try {
      final parsed = DateTime.tryParse(date.toString());
      if (parsed != null) {
        return '${parsed.day.toString().padLeft(2,'0')}/${parsed.month.toString().padLeft(2,'0')}/${parsed.year} à ${parsed.hour.toString().padLeft(2,'0')}:${parsed.minute.toString().padLeft(2,'0')}';
      }
    } catch (e) {}
    return date.toString();
  }
}
