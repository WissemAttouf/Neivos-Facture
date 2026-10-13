// lib/screens/admin/admin_users_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/particle_background.dart';
import 'admin_user_form_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _searchQuery = '';
  String _filterRole = 'Tous';
  String _filterStatus = 'Tous';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

 

  List<UserModel> get _filteredUsers {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    var users = adminProvider.users;

    if (_searchQuery.isNotEmpty) {
      users = users.where((u) =>
      u.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          u.email.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    if (_filterRole != 'Tous') {
      users = users.where((u) => u.role == _filterRole.toLowerCase()).toList();
    }

    if (_filterStatus != 'Tous') {
      final isActive = _filterStatus == 'Actif';
      users = users.where((u) => u.isActive == isActive).toList();
    }

    return users;
  }

  
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final adminProvider = Provider.of<AdminProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isAdmin = authProvider.isAdmin;
    final users = _filteredUsers;

    if (!isAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
            

    return Column(
      children: [
        // Barre de recherche et filtres
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Rechercher un utilisateur...',
                  prefixIcon: Icon(Icons.search, color: Theme.of(context).textTheme.bodyMedium?.color),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
             
        // Liste des utilisateurs
        Expanded(
          child: adminProvider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun utilisateur trouvé',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return _buildUserCard(user, context, authProvider.authToken!);
            },
          ),
        ),
      ],
    );
  }

 
  }

  Widget _buildStatusChip(String label, String selected) {
    final isSelected = _filterStatus == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _filterStatus = selected ? label : 'Tous';
          });
        },
        backgroundColor: Theme.of(context).cardColor,
        selectedColor: label == 'Actif' ? Colors.green : Colors.red,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
    );
  }

  Widget _buildUserCard(UserModel user, BuildContext context, String token) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).user?.id;
    final roleColor = _getRoleColor(user.role);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: roleColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: roleColor,
              ),
            ),
          ),
        ),
       
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.roleName,
                    style: TextStyle(fontSize: 10, color: roleColor),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: user.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.isActive ? 'Actif' : 'Inactif',
                    style: TextStyle(
                      fontSize: 10,
                      color: user.isActive ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        ))
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(user.isActive ? Icons.block : Icons.check_circle, size: 20,
                      color: user.isActive ? Colors.orange : Colors.green),
                  const SizedBox(width: 8),
                  Text(user.isActive ? 'Désactiver' : 'Activer'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'role',
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, size: 20),
                  SizedBox(width: 8),
                  Text('Changer rôle')
                ],
              ),
            ),
          ],
          onSelected: (value) => _handleUserAction(value, user, token, context),
        ),
        onTap: () => _editUser(user, token),
      ),
    );
  }

      ),
    ).then((_) => _loadUsers());
  }

  void _confirmDeleteUser(UserModel user, String token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer l\'utilisateur'),
        content: Text('Êtes-vous sûr de vouloir supprimer "${user.username}" ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final adminProvider = Provider.of<AdminProvider>(context, listen: false);
              final success = await adminProvider.deleteUser(token, user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Utilisateur supprimé' : 'Erreur lors de la suppression'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleUserStatus(UserModel user, String token) async {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
    final success = await adminProvider.toggleUserStatus(token, user.id, !user.isActive);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Statut mis à jour' : 'Erreur'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  void _showRoleDialog(UserModel user, String token) {
    final roles = ['accountant', 'admin'];
    String selectedRole = user.role == 'user' ? 'accountant' : user.role;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Changer le rôle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: roles.map((role) {
            return RadioListTile<String>(
              title: Text(role == 'admin' ? 'Administrateur' : 'Comptable'),
              value: role,
              groupValue: selectedRole,
              onChanged: (value) {
                if (value != null) {
                  selectedRole = value;
                  Navigator.pop(ctx);
                  _updateUserRole(user, token, selectedRole);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _updateUserRole(UserModel user, String token, String newRole) async {
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);
   
        ),
      );
    }
  }
}
