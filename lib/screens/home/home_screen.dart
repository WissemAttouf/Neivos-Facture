import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/particle_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }



  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    // ✅ Récupération de TOUTES les données utilisateur (y compris l'image)
    final username = authProvider.user?.username ?? 'Utilisateur';
    final email = authProvider.user?.email ?? 'email@exemple.com';
    final profileImage = authProvider.user?.profileImage; // <-- C'est cette ligne qui manquait !
    final initial = username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/ssvg.PNG',
              height: 40,
              width: 40,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.receipt, size: 30),
            ),
            const SizedBox(width: 8),
            Text(
              'NEIVOS FACTURE',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).appBarTheme.foregroundColor,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ✅ Drawer avec image de profil
            UserAccountsDrawerHeader(
              accountName: Text(
                username,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(email),

              // ✅ C'EST ICI QUE L'IMAGE REMPLACE LA LETTRE
              
                          ),
                        ),
                      );
                    },
                  )
                  // Si pas d'image du tout, on affiche l'initiale
                      : Center(
                    child: Text(
                      initial,
                      style: TextStyle(
                        fontSize: 36,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.document_scanner),
              title: const Text('Scanner'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/scan');
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Documents'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/documents');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profil'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
            ),
            ListTile(
              leading: const Icon(Icons.chat),
              title: const Text('Chat IA'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/chat');
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Paramètres'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Déconnexion', style: TextStyle(color: Colors.red)),
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          ParticleBackground(isDarkMode: isDarkMode),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour, $username!',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Que souhaitez-vous faire aujourd\'hui?',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 1.4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildActionCard(
                        context,
                        icon: Icons.document_scanner,
                        label: 'Scanner',
                        color: Theme.of(context).primaryColor,
                        route: '/scan',
                      ),
                      _buildActionCard(
                        context,
                        icon: Icons.folder,
                        label: 'Documents',
                        color: Theme.of(context).colorScheme.secondary,
                        route: '/documents',
                      ),
                      _buildActionCard(
                        context,
                        icon: Icons.person,
                        label: 'Profil',
                        color: Colors.blue,
                 
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      BuildContext context, {
        required IconData icon,
        required String label,
        required Color color,
        required String route,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
      
          ),
        ],
      ),
    );
  }
}
