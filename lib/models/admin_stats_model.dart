// lib/models/admin_stats_model.dart
class AdminStatsModel {
  final int totalUsers;
  final int totalInvoices;
  final int activeUsers;
  final int inactiveUsers;
  final int adminCount;
  final int accountantCount;
  final double totalAmount;
  final Map<String, int> monthlyInvoices;
  final List<Map<String, dynamic>> recentActivity;

  AdminStatsModel({
    required this.totalUsers,
    required this.totalInvoices,
    required this.activeUsers,
    required this.inactiveUsers,
    required this.adminCount,
    required this.accountantCount,
    required this.totalAmount,
    required this.monthlyInvoices,
    required this.recentActivity,
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      totalUsers: json['total_users'] ?? 0,
      totalInvoices: json['total_invoices'] ?? 0,
      activeUsers: json['active_users'] ?? 0,
      inactiveUsers: json['inactive_users'] ?? 0,
      adminCount: json['admin_count'] ?? 0,
      accountantCount: json['accountant_count'] ?? 0,
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      monthlyInvoices: Map<String, int>.from(json['monthly_invoices'] ?? {}),
      recentActivity: List<Map<String, dynamic>>.from(json['recent_activity'] ?? []),
    );
  }
}
