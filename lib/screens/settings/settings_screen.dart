import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/particle_background.dart';

class SettingsScreen extends StatefulWidget {
  final String? accessToken;

  const SettingsScreen({super.key, this.accessToken});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Paramètres de scan
  String _selectedImageQuality = 'Moyenne';
  String _selectedScanMode = 'Standard';
  bool _autoEnhance = true;
  List<String> _selectedOcrLanguages = ['Français', 'Anglais'];
  String _fileNamingConvention = 'TypeDuDoc_Date_Heure';

  // Paramètres d'apparence
  bool _highContrastMode = false;
  double _fontSizeScale = 1.0;

  // État
  bool _isLoading = false;
  bool _isSaving = false;
  String _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Charger les paramètres depuis SharedPreferences
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      setState(() {
        _selectedImageQuality = prefs.getString('imageQuality') ?? 'Moyenne';
        _selectedScanMode = prefs.getString('scanMode') ?? 'Standard';
        _autoEnhance = prefs.getBool('autoEnhance') ?? true;
        _fileNamingConvention = prefs.getString('fileNaming') ?? 'TypeDuDoc_Date_Heure';
        _highContrastMode = prefs.getBool('highContrast') ?? false;
        _fontSizeScale = prefs.getDouble('fontSize') ?? 1.0;

        // Charger les langues
        final languages = prefs.getStringList('ocrLanguages');
        if (languages != null) {
          _selectedOcrLanguages = languages;
        }
      });

      print('✅ Paramètres chargés');
    } catch (e) {
      print('❌ Erreur chargement paramètres: $e');
      _showSnackBar('Erreur de chargement des paramètres', Colors.orange);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Sauvegarder les paramètres
  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // Sauvegarder tous les paramètres
      await prefs.setString('imageQuality', _selectedImageQuality);
      await prefs.setString('scanMode', _selectedScanMode);
      await prefs.setBool('autoEnhance', _autoEnhance);
      await prefs.setString('fileNaming', _fileNamingConvention);
      await prefs.setBool('highContrast', _highContrastMode);
      await prefs.setDouble('fontSize', _fontSizeScale);
      await prefs.setStringList('ocrLanguages', _selectedOcrLanguages);

      // Appliquer les paramètres d'apparence
      _applyAppearanceSettings();

      _showSnackBar('✅ Paramètres sauvegardés avec succès!', Colors.green);
      print('✅ Paramètres sauvegardés');

    } catch (e) {
      print('❌ Erreur sauvegarde: $e');
      _showSnackBar('❌ Erreur de sauvegarde: $e', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // Appliquer les paramètres d'apparence
  void _applyAppearanceSettings() {
    // Note: Le contraste élevé et la taille de police seront appliqués
    // via un Provider ou un Theme personnalisé
    print('📱 Application des paramètres d\'apparence');
    print('   - Contraste élevé: $_highContrastMode');
    print('   - Taille police: ${(_fontSizeScale * 100).toInt()}%');
  }

  // Réinitialiser aux valeurs par défaut
  Future<void> _resetToDefault() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Réinitialiser'),
        content: const Text('Voulez-vous vraiment réinitialiser tous les paramètres ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() {
                _selectedImageQuality = 'Moyenne';
                _selectedScanMode = 'Standard';
                _autoEnhance = true;
                _selectedOcrLanguages = ['Français', 'Anglais'];
                _fileNamingConvention = 'TypeDuDoc_Date_Heure';
                _highContrastMode = false;
                _fontSizeScale = 1.0;
              });
              await _saveSettings();
              _showSnackBar('✅ Paramètres réinitialisés', Colors.green);
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isLoggedIn = authProvider.isLoggedIn;

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
              const Icon(Icons.settings, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              'PARAMÈTRES',
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
        actions: [
          // Bouton réinitialiser
          IconButton(
            icon: const Icon(Icons.restore, color: Colors.white),
            onPressed: _resetToDefault,
            tooltip: 'Réinitialiser',
          ),
          // Bouton sauvegarder
          IconButton(
            icon: _isSaving
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.save, color: Colors.white),
            onPressed: _isSaving ? null : _saveSettings,
            tooltip: 'Sauvegarder',
          ),
        ],
      ),
      body: Stack(
        children: [
          ParticleBackground(isDarkMode: isDarkMode),
          _isLoading
              ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
              : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PARAMÈTRES DE SCAN
                _buildSectionCard(
                  title: ' Paramètres de Scan',
                  icon: Icons.document_scanner,
                  children: [
                    _buildDropdownSetting(
                      title: 'Qualité d\'image',
                      value: _selectedImageQuality,
                      items: ['Faible', 'Moyenne', 'Élevée'],
                      onChanged: (value) => setState(() => _selectedImageQuality = value!),
                      description: 'Qualité des images scannées',
                    ),
                    _buildDropdownSetting(
                      title: 'Mode de scan',
                      value: _selectedScanMode,
                      items: ['Standard', 'Document', 'Carte d\'identité'],
                      onChanged: (value) => setState(() => _selectedScanMode = value!),
                      description: 'Type de document à scanner',
                    ),
                    _buildSwitchSetting(
                      title: 'Amélioration automatique',
                      value: _autoEnhance,
                      onChanged: (value) => setState(() => _autoEnhance = value),
                      subtitle: 'Améliore automatiquement la qualité des images',
                    ),
                    _buildLanguageSelector(),
                    _buildDropdownSetting(
                      title: 'Nommage des fichiers',
                      value: _fileNamingConvention,
                      items: ['TypeDuDoc_Date_Heure', 'Date_TypeDuDoc_Heure', 'Personnalisé'],
                      onChanged: (value) => setState(() => _fileNamingConvention = value!),
                      description: 'Format de nom des fichiers sauvegardés',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // APPAREIL PHOTO
                _buildSectionCard(
                  title: 'Appareil Photo',
                  icon: Icons.camera_alt,
                  children: [
                    _buildInfoTile(
                      title: 'Résolution',
                      value: '1920 x 1080',
                      icon: Icons.high_quality,
                    ),
                    _buildInfoTile(
                      title: 'Format',
                      value: 'JPG',
                      icon: Icons.image,
                    ),
                    _buildInfoTile(
                      title: 'Flash',
                      value: 'Automatique',
                      icon: Icons.flash_on,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // PARAMÈTRES D'APPARENCE
                _buildSectionCard(
                  title: ' Apparence',
                  icon: Icons.palette,
                  children: [
                    ListTile(
                      leading: Icon(
                        themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: Text(
                        'Mode thème',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      subtitle: Text(
                        _getThemeModeName(themeProvider.themeMode),
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                      trailing: DropdownButton<ThemeMode>(
                        value: themeProvider.themeMode,
                        onChanged: (ThemeMode? newMode) {
                          if (newMode != null) {
                            themeProvider.setThemeMode(newMode);
                          }
                        },
                        dropdownColor: Theme.of(context).cardColor,
                        icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).primaryColor),
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        underline: Container(height: 1, color: Theme.of(context).dividerColor),
                        items: const [
                          DropdownMenuItem(
                            value: ThemeMode.system,
                            child: Text('Automatique'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.light,
                            child: Text('Clair'),
                          ),
                          DropdownMenuItem(
                            value: ThemeMode.dark,
                            child: Text('Sombre'),
                          ),
                        ],
                      ),
                    ),
                    _buildSwitchSetting(
                      title: 'Mode contraste élevé',
                      value: _highContrastMode,
                      onChanged: (value) => setState(() => _highContrastMode = value),
                      subtitle: 'Améliore la lisibilité',
                    ),
                    _buildSliderSetting(
                      title: 'Taille de police',
                      value: _fontSizeScale,
                      min: 0.8,
                      max: 1.5,
                      divisions: 7,
                      onChanged: (value) => setState(() => _fontSizeScale = value),
                    ),
                  ],
                ),

                const SizedBox(height: 16),




                const SizedBox(height: 16),

                // COMPTE (UNIQUEMENT SI CONNECTÉ)
                if (isLoggedIn)
                  _buildSectionCard(
                    title: 'Compte',
                    icon: Icons.account_circle,
                    children: [
                      ListTile(
                        leading: Icon(Icons.person, color: Theme.of(context).primaryColor),
                        title: Text(
                          'Profil',
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        ),
                        subtitle: Text(
                          authProvider.user?.email ?? 'email@exemple.com',
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                        ),
                        onTap: () => Navigator.pushNamed(context, '/profile'),
                      ),
                      ListTile(
                        leading: Icon(Icons.logout, color: Colors.red),
                        title: Text(
                          'Déconnexion',
                          style: const TextStyle(color: Colors.red),
                        ),
                        onTap: _showLogoutDialog,
                      ),
                    ],
                  ),

                const SizedBox(height: 16),

                // À PROPOS
                _buildSectionCard(
                  title: 'À propos',
                  icon: Icons.info_outline,
                  children: [
                    _buildInfoTile(
                      title: 'Version',
                      value: _appVersion,
                      icon: Icons.info,
                    ),
                    ListTile(
                      leading: Icon(Icons.update, color: Theme.of(context).primaryColor),
                      title: Text(
                        'Mise à jour',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      subtitle: const Text('Vérifier les mises à jour'),
                      onTap: () => _showSnackBar('Dernière version installée', Colors.green),
                    ),
                    ListTile(
                      leading: Icon(Icons.help, color: Theme.of(context).primaryColor),
                      title: Text(
                        'Aide',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      onTap: () => Navigator.pushNamed(context, '/help'),
                    ),

                  ],
                ),

                const SizedBox(height: 20),

                // Message de confirmation de sauvegarde
                if (_isSaving)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Sauvegarde en cours...',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required IconData icon, required List<Widget> children}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      color: isDarkMode ? const Color(0xFF2D2D2D) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownSetting({
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? description,
  }) {
    return Column(
      children: [
        ListTile(
          title: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: description != null
              ? Text(
            description,
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12),
          )
              : null,
          trailing: DropdownButton<String>(
            value: value,
            onChanged: onChanged,
            dropdownColor: Theme.of(context).cardColor,
            icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).primaryColor),
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            underline: Container(height: 1, color: Theme.of(context).dividerColor),
            items: items.map((item) => DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
              ),
            )).toList(),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSwitchSetting({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) {
    return Column(
      children: [
        SwitchListTile(
          title: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
            subtitle,
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12),
          )
              : null,
          value: value,
          onChanged: onChanged,
          activeColor: Theme.of(context).primaryColor,
          inactiveTrackColor: Colors.grey[600],
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSliderSetting({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: Theme.of(context).primaryColor,
          inactiveColor: Colors.grey[600],
          thumbColor: Theme.of(context).primaryColor,
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildLanguageSelector() {
    return Column(
      children: [
        ListTile(
          title: Text(
            'Langues OCR',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            _selectedOcrLanguages.join(', '),
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
          ),
          trailing: Icon(Icons.language, color: Theme.of(context).primaryColor),
          onTap: _showLanguageDialog,
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          title: Text(
            title,
            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          trailing: Text(
            value,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _showLanguageDialog() async {
    final availableLanguages = ['Français', 'Anglais', 'Espagnol', 'Allemand', 'Italien', 'Arabe'];
    var tempSelected = List<String>.from(_selectedOcrLanguages);

    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Row(
                children: [
                  Icon(Icons.translate, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 10),
                  Text(
                    'Langues OCR',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = availableLanguages[index];
                    return CheckboxListTile(
                      title: Text(
                        lang,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      ),
                      value: tempSelected.contains(lang),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            tempSelected.add(lang);
                          } else {
                            tempSelected.remove(lang);
                          }
                        });
                      },
                      activeColor: Theme.of(context).primaryColor,
                      checkColor: Colors.white,
                      tileColor: Theme.of(context).cardColor,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  child: Text(
                    'Annuler',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                TextButton(
                  child: Text(
                    'OK',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context, tempSelected),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _selectedOcrLanguages = result);
    }
  }

  Future<void> _showClearCacheDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider le cache'),
        content: const Text('Voulez-vous vraiment vider le cache ?\nLes documents enregistrés ne seront pas supprimés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Simuler le nettoyage du cache
              Future.delayed(const Duration(seconds: 1), () {
                _showSnackBar('✅ Cache vidé avec succès', Colors.green);
              });
            },
            child: const Text(
              'Vider',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              Provider.of<AuthProvider>(context, listen: false).logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
            child: const Text(
              'Déconnecter',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'Automatique';
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
    }
  }
}
