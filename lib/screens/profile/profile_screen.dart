import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/particle_background.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _currentPasswordController;
  late TextEditingController _newPasswordController;
  late TextEditingController _confirmPasswordController;

  File? _profileImage;
  bool _storagePermissionGranted = false;
  bool _isCheckingPermission = false;
  bool _showPasswordFields = false;
  bool _isSaving = false;
  String _saveError = '';

  @override
 

  Future<void> _checkStoragePermission() async {
    if (_isCheckingPermission) return;

    _isCheckingPermission = true;

    try {
      bool granted = false;

      if (await Permission.storage.isGranted) {
        granted = true;
      } else if (await Permission.photos.isGranted) {
        granted = true;
      } else {
        if (await Permission.storage.request().isGranted) {
          granted = true;
        } else if (await Permission.photos.request().isGranted) {
          granted = true;
        }
      }

      setState(() => _storagePermissionGranted = granted);

    } catch (e) {
      print('❌ Erreur permission: $e');
      setState(() => _storagePermissionGranted = false);
    } finally {
      _isCheckingPermission = false;
    }
  }

  Future<void> _pickImage() async {
    try {
      if (!await Permission.storage.isGranted && !await Permission.photos.isGranted) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission requise pour accéder aux photos'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        setState(() => _storagePermissionGranted = true);
      }

      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null && mounted) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      print('❌ Erreur sélection image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage() {
    setState(() {
      _profileImage = null;
    });
  }

  Future<void> _testImageUrl() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final url = auth.user?.profileImage;

    if (url != null && url.isNotEmpty) {
      print('🔍 Test URL: $url');

      try {
        final response = await http.head(Uri.parse(url));
        print('📡 Status: ${response.statusCode}');

        
              SnackBar(
                content: Text('❌ Image inaccessible: ${response.statusCode}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } catch (e) {
        print('❌ Erreur: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      print('❌ URL image null');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Pas d\'image de profil'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _saveError = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      final currentUser = authProvider.user;
      final usernameChanged = _nameController.text.trim() != (currentUser?.username ?? '');
      final emailChanged = _emailController.text.trim() != (currentUser?.email ?? '');
      final passwordChanged = _showPasswordFields && _newPasswordController.text.isNotEmpty;
      final imageChanged = _profileImage != null;

      if (!usernameChanged && !emailChanged && !passwordChanged && !imageChanged) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucune modification détectée'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      if (passwordChanged && _currentPasswordController.text.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Le mot de passe actuel est requis pour changer le mot de passe'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      await authProvider.updateUserProfile(
        newUsername: _nameController.text.trim(),
        newEmail: _emailController.text.trim(),
        newPassword: passwordChanged ? _newPasswordController.text : null,
        currentPassword: passwordChanged ? _currentPasswordController.text : null,
        profileImage: _profileImage,
      );

      // ✅ Recharger le profil
      await authProvider.fetchUserProfile();

      if (mounted) {
        setState(() {
          _profileImage = null;
        });

        if (_showPasswordFields) {
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          setState(() => _showPasswordFields = false);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour avec succès', style: TextStyle(color: Colors.white)),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saveError = e.toString().replaceAll('Exception: ', '');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${_saveError}', style: const TextStyle(color: Colors.white)),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

 
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;

    final username = authProvider.user?.username ?? '';
    final email = authProvider.user?.email ?? '';
    final initial = username.isNotEmpty ? username.substring(0, 1).toUpperCase() : 'U';
    final profileImage = authProvider.user?.profileImage;

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
      body: Stack(
        children: [
          ParticleBackground(isDarkMode: isDarkMode),
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Photo de profil
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            border: Border.all(
                              color: AppTheme.primaryColor,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: _profileImage != null
                                ? Image.file(
                              _profileImage!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            )
                                : (profileImage != null && profileImage.isNotEmpty
                                ? Image.network(
                              profileImage,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                print('❌ Erreur chargement image: $error');
                                return Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      fontSize: 40,
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            )
                                : Center(
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )),
                          ),
                        ),
                      ),

                     

                      Positioned(
                        bottom: 0,
                        left: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit, size: 20, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (!_storagePermissionGranted)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Permission requise pour changer la photo',
                        style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      labelText: 'Nom d\'utilisateur',
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                      prefixIcon: Icon(Icons.person, color: Theme.of(context).textTheme.bodyMedium?.color),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Ce champ est requis';
                      if (value.length < 3) return 'Minimum 3 caractères';
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                      prefixIcon: Icon(Icons.email, color: Theme.of(context).textTheme.bodyMedium?.color),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Ce champ est requis';
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Email invalide';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _togglePasswordFields,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).cardColor,
                      foregroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      _showPasswordFields ? 'Masquer les champs mot de passe' : 'Modifier le mot de passe',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  if (_showPasswordFields) ...[
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _currentPasswordController,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Mot de passe actuel',
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                        prefixIcon: Icon(Icons.lock, color: Theme.of(context).textTheme.bodyMedium?.color),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (_showPasswordFields && (value == null || value.isEmpty)) {
                          return 'Ce champ est requis pour changer le mot de passe';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                   
                      validator: (value) {
                        if (_showPasswordFields && (value == null || value.isEmpty)) {
                          return 'Ce champ est requis';
                        }
                        if (value != null && value.isNotEmpty && value.length < 6) {
                          return 'Minimum 6 caractères';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _confirmPasswordController,
                      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirmer le mot de passe',
                        labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                        prefixIcon: Icon(Icons.lock_reset, color: Theme.of(context).textTheme.bodyMedium?.color),
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      validator: (value) {
                        if (_showPasswordFields && (value == null || value.isEmpty)) {
                          return 'Ce champ est requis';
                        }
                        if (value != null && value.isNotEmpty && value != _newPasswordController.text) {
                          return 'Les mots de passe ne correspondent pas';
                        }
                        return null;
                      },
                    ),
                  ],

                  if (_saveError.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _saveError,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                     
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
