import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../utils/app_theme.dart';
import '../../widgets/particle_background.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _bugReportFormKey = GlobalKey<FormState>();
  final TextEditingController _bugSubjectController = TextEditingController();
  final TextEditingController _bugDescriptionController = TextEditingController();
  bool _isSendingBugReport = false;

  @override
  void dispose() {
    _bugSubjectController.dispose();
    _bugDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Impossible d\'ouvrir le lien: $urlString', Colors.red);
    }
  }

  // ✅ MÉTHODE CORRIGÉE - Envoyer le rapport à votre serveur
  Future<void> _sendBugReport() async {
 
        _bugDescriptionController.clear();
      } else {
        throw Exception(responseBody['message'] ?? 'Erreur serveur (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Erreur envoi rapport: $e');
      _showSnackBar('Erreur: ${e.toString().replaceAll("Exception: ", "")}', Colors.red);
    } finally {
      setState(() => _isSendingBugReport = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final isLoggedIn = authProvider.user != null;
    final textColor = AppTheme.getTextColor(context);
    final secondaryTextColor = AppTheme.getSecondaryTextColor(context);

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
              const Icon(Icons.receipt, size: 30, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Text(
              'NEIVOS FACTURE',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.white,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
     
                    ),
                    _buildExpansionTile(
                      title: 'L\'OCR fonctionne-t-il hors ligne ?',
                      content: 'Pour le moment, l\'OCR nécessite une connexion internet '
                          'pour analyser les documents. Les documents scannés sont '
                          'stockés localement et synchronisés avec le cloud.',
                      context: context,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section Support Technique
                _buildSectionCard(
                  title: 'Support Technique',
                  icon: Icons.support_agent,
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.email, color: AppTheme.primaryColor, size: 20),
                      ),
                      title: Text(
                        'Email de support',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'support@neivos.com',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      onTap: () => _launchURL('mailto:support@neivos.com'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.language, color: AppTheme.secondaryColor, size: 20),
                      ),
                      title: Text(
                        'Site web',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'www.neivos.com/help',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      onTap: () => _launchURL('https://neivos-group.com/'),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Section Signaler un problème
                _buildSectionCard(
                  title: 'Signaler un problème',
                  icon: Icons.bug_report,
                  children: [
                    if (!isLoggedIn)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.warningColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.warning, color: AppTheme.warningColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Connectez-vous pour envoyer un rapport complet',
                                style: TextStyle(color: AppTheme.warningColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Form(
                      key: _bugReportFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _bugSubjectController,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Sujet',
                              hintText: 'Décrivez brièvement le problème',
                              labelStyle: TextStyle(color: secondaryTextColor),
                              hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.6)),
                              prefixIcon: Icon(Icons.title, color: secondaryTextColor),
                              filled: true,
                              fillColor: AppTheme.getInputFillColor(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                            ),
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Veuillez saisir un sujet'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _bugDescriptionController,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              labelText: 'Description',
                              hintText: 'Décrivez le problème en détail...',
                              labelStyle: TextStyle(color: secondaryTextColor),
                              hintStyle: TextStyle(color: secondaryTextColor.withOpacity(0.6)),
                              prefixIcon: Icon(Icons.description, color: secondaryTextColor),
                              filled: true,
                              fillColor: AppTheme.getInputFillColor(context),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                            ),
                            maxLines: 4,
                            validator: (value) => value?.isEmpty ?? true
                                ? 'Veuillez décrire le problème'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: _isSendingBugReport
                                ? Container(
                              height: 50,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                              ),
                            )
                                : ElevatedButton(
                              onPressed: isLoggedIn
                                  ? _sendBugReport
                                  : () => _showSnackBar('Veuillez vous connecter', Colors.orange),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isLoggedIn ? AppTheme.primaryColor : Colors.grey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                isLoggedIn ? 'Envoyer le rapport' : 'Connectez-vous pour signaler',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              
                        'Téléphone',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '+216 29 685 388',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      onTap: () => _launchURL('tel:+21629685388'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chat, color: Colors.blue, size: 20),
                      ),
                      title: Text(
                        'Chat en direct',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        'Discutez avec notre équipe',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                      onTap: () => Navigator.pushNamed(context, '/chat'),
                    ),
                  ],
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
    final textColor = AppTheme.getTextColor(context);

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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDarkMode ? Colors.grey[800] : Colors.grey[200],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          colorScheme: ColorScheme.dark(
            primary: AppTheme.primaryColor,
            surface: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          ),
        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
