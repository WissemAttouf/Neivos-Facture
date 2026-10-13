// lib/screens/admin/admin_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/admin_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/particle_background.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _isLoading = false;
  String _maxUploadSize = '5';
  List<String> _allowedFileTypes = ['jpg', 'png', 'pdf'];

  final _maxUploadController = TextEditingController();
  final List<String> _fileTypes = ['jpg', 'png', 'pdf', 'jpeg', 'tiff'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

 
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final adminProvider = Provider.of<AdminProvider>(context, listen: false);

    final settings = {
      'max_upload_size': int.tryParse(_maxUploadController.text) ?? 5,
      'allowed_file_types': _allowedFileTypes,
    };

    final success = await adminProvider.updateSettings(authProvider.authToken!, settings);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ Paramètres sauvegardés' : '❌ Erreur lors de la sauvegarde'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveSettings,
            tooltip: 'Sauvegarder',
          ),
        ],
      ),
      body: Stack(
        children: [
          ParticleBackground(isDarkMode: isDarkMode),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Configuration générale exclusive au upload
                  _buildSection(
                    title: 'Configuration Générale',
                    icon: Icons.settings,
                    children: [
                      _buildTextField(_maxUploadController, 'Taille max upload par fichier (MB)', Icons.cloud_upload, isNumber: true),
                      const SizedBox(height: 16),
                      Text(
                        'Types de fichiers autorisés :',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                     
                              });
                            },
                            backgroundColor: Theme.of(context).cardColor,
                            selectedColor: Colors.green.withOpacity(0.4),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Informations système
                  _buildSection(
                    title: 'Informations système',
                    icon: Icons.info,
                    children: [
                      _buildInfoTile('Version Logiciel', '1.0.0 (Production)'),
                      _buildInfoTile('Base de données', 'MySQL Connectée'),
                      _buildInfoTile('Moteur OCR', 'Neivos Scanner AI'),
                    ],
                  ),

                 

                  const SizedBox(height: 20),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  
      ),
    );
  }
}
