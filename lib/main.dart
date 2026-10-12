import 'package:flutter/material.dart';
import 'package:neivos_facture/screens/chat/chat_screen.dart';
import 'package:neivos_facture/screens/help/help_screen.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/document_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/admin_provider.dart';
import 'services/api_service.dart';
import 'services/ocr_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/scan/scan_screen.dart';
import 'screens/validation/data_validation_screen.dart';
import 'screens/documents/documents_list_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        Provider(create: (_) => ApiService(baseUrl: '10.123.109.205:8086')),
        Provider(create: (context) => OCRService(apiService: context.read<ApiService>())),
        ChangeNotifierProvider(
          create: (context) => DocumentProvider(
            apiService: context.read<ApiService>(),
          ),
        ),
      ],
      child: const OCRScannerApp(),
    ),
  );
}

class OCRScannerApp extends StatefulWidget {
  const OCRScannerApp({super.key});

  @override
  State<OCRScannerApp> createState() => _OCRScannerAppState();
}

class _OCRScannerAppState extends State<OCRScannerApp> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  'Chargement de l\'application...',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return MaterialApp(
              title: 'Neivos Facture',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: themeProvider.themeMode,

              // ✅ Redirection selon le rôle de l'utilisateur
              home: authProvider.isLoggedIn
                  ? (authProvider.isAdmin
                  ? const AdminDashboardScreen()
                  : const HomeScreen())
                  : const LoginScreen(),

              routes: {
                '/login': (context) => const LoginScreen(),
                '/register': (context) => const RegisterScreen(),
                '/home': (context) => const HomeScreen(),
                '/admin': (context) => const AdminDashboardScreen(),
                '/scan': (context) => const ScanScreen(),
                '/documents': (context) => const DocumentsListScreen(),
                '/profile': (context) => const ProfileScreen(),
                '/settings': (context) => const SettingsScreen(),
                '/help': (context) => const HelpScreen(),
                '/chat': (context) => const ChatScreen(),
              },

              onGenerateRoute: (settings) {
                if (settings.name == '/validation') {
                  final args = settings.arguments as Map<String, dynamic>;
                  return MaterialPageRoute(
                    builder: (_) => DataValidationScreen.fromParams(
                      extractedData: args['extractedData'] ?? {},
                      confidence: args['confidence'] ?? 0.0,
                      rawText: args['rawText'] ?? '',
                      imagePath: args['imagePath'] ?? '',
                      imageBase64: args['imageBase64'] ?? '',
                    ),
                  );
                }
                return null;
              },

              onUnknownRoute: (settings) {
                return MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Erreur')),
                    body: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red),
                          SizedBox(height: 20),
                          Text('Page non trouvée', style: TextStyle(fontSize: 18)),
                          SizedBox(height: 10),
                          Text('La route demandée n\'existe pas'),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

