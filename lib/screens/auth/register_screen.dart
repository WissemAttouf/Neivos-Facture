// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/particle_background.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}



    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.register(
        _usernameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _selectedGender!,
      );

      if (authProvider.isLoggedIn && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Inscription réussie! Bienvenue.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  
                    Expanded(
                      child: Text(
                        'NEIVOS FACTURE',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                  ParticleBackground(isDarkMode: themeProvider.isDarkMode),
                  SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            Text(
                              'Créer un compte',
                              style: GoogleFonts.inter(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rejoignez Neivos Facture dès aujourd\'hui',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),

                            // Champ Nom d'utilisateur
                            TextFormField(
                              controller: _usernameController,
                              decoration: _inputDecoration('Nom d\'utilisateur', Icons.person, context),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Le nom d\'utilisateur est requis';
                                if (value.length < 3) return 'Le nom doit contenir au moins 3 caractères';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Champ Email
                           

                            // Sélection du genre
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              decoration: _inputDecoration('Genre', Icons.people, context),
                              dropdownColor: Theme.of(context).cardColor,
                              style: GoogleFonts.inter(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontSize: 16,
                              ),
                              items: _genders.map((String gender) {
                                return DropdownMenuItem<String>(
                                  value: gender,
                                  child: Text(gender == 'homme' ? 'Homme' : 'Femme'),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() => _selectedGender = newValue);
                              },
                              validator: (value) {
                                if (value == null) return 'Veuillez sélectionner votre genre';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Champ Mot de passe (8 caractères + icône œil)
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: _inputDecoration(
                                'Mot de passe',
                                Icons.lock,
                                context,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Le mot de passe est requis';
                                if (value.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Champ Confirmer Mot de passe (icône œil)
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              decoration: _inputDecoration(
                                'Confirmer le mot de passe',
                                Icons.lock_outline,
                                context,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                                    color: Theme.of(context).textTheme.bodyMedium?.color,
                                  ),
                                  onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                ),
                              ),
                             hage de l'erreur
                            if (_error.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error,
                                        style: const TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),

                            // Bouton S'inscrire
                           ressIndicator(color: Colors.white),
                                )
                                    : Text(
                                  'S\'INSCRIRE',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimary,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Lien vers connexion
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Déjà un compte? ',
                                  style: GoogleFonts.inter(color: Theme.of(context).textTheme.bodyMedium?.color),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                                  child: Text(
                                    'Se connecter',
                                    style: GoogleFonts.inter(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Fonction de décoration identique à celle du LoginScreen
  InputDecoration _inputDecoration(String label, IconData icon, BuildContext context, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.inter(color: Theme.of(context).textTheme.bodyMedium?.color),
      prefixIcon: Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Theme.of(context).cardColor,
  }
}
