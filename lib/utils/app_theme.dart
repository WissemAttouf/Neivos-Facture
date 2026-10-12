import 'package:flutter/material.dart';

class AppTheme {
  // Couleurs principales (conservées)
  static const Color primaryColor = Color(0xFF388BFD);
  static const Color secondaryColor = Color(0xFFA371F7);
  static const Color errorColor = Color(0xFFE53935);
  static const Color successColor = Color(0xFF43A047);
  static const Color warningColor = Color(0xFFFFA000);

  // Constantes manquantes ajoutées
  static const Color accentBlue = Color(0xFF388BFD);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE0E0E0);
  static const Color textLight = Color(0xFF212121);

  // Couleurs mode clair
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightDivider = Color(0xFFEEEEEE);

  // Couleurs mode sombre - optimisées pour une meilleure lisibilité
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF2D2D2D);
  static const Color darkTextPrimary = Color(0xFFF5F5F5);
  static const Color darkTextSecondary = Color(0xFFB0B0B0);
  static const Color darkBorder = Color(0xFF404040);
  static const Color darkDivider = Color(0xFF333333);

  // Thème clair
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: lightBackground,
    cardColor: lightCard,
    dividerColor: lightDivider,
    fontFamily: 'Inter',

    appBarTheme: const AppBarTheme(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: lightTextPrimary, fontSize: 28, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: lightTextPrimary, fontSize: 24, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: lightTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: lightTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: lightTextPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: lightTextPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: lightTextSecondary, fontSize: 14),
      labelLarge: TextStyle(color: lightTextPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightSurface,
      labelStyle: const TextStyle(color: lightTextSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: lightTextSecondary, fontSize: 14),
      errorStyle: const TextStyle(color: errorColor, fontSize: 12),
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
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    iconTheme: const IconThemeData(
      color: lightTextPrimary,
      size: 24,
    ),

    // CORRECTION ICI : Utilisation de CardThemeData directement
    cardTheme: const CardThemeData(
      color: lightCard,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: lightTextPrimary,
      textColor: lightTextPrimary,
    ),

    dividerTheme: const DividerThemeData(
      color: lightDivider,
      thickness: 1,
      space: 20,
    ),

    dialogTheme: const DialogThemeData(
      backgroundColor: lightCard,
      titleTextStyle: TextStyle(
        color: lightTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: TextStyle(
        color: lightTextSecondary,
        fontSize: 14,
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: lightCard,
      modalBackgroundColor: lightCard,
    ),
  );

  // Thème sombre
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    cardColor: darkCard,
    dividerColor: darkDivider,
    fontFamily: 'Inter',

    appBarTheme: const AppBarTheme(
      backgroundColor: darkSurface,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: darkTextPrimary,
      ),
      iconTheme: IconThemeData(color: darkTextPrimary),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(color: darkTextPrimary, fontSize: 28, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: darkTextPrimary, fontSize: 24, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: darkTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: darkTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: darkTextPrimary, fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: darkTextPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: darkTextSecondary, fontSize: 14),
      labelLarge: TextStyle(color: darkTextPrimary, fontSize: 14, fontWeight: FontWeight.w500),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      labelStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: darkTextSecondary, fontSize: 14),
      errorStyle: const TextStyle(color: errorColor, fontSize: 12),
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
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    iconTheme: const IconThemeData(
      color: darkTextPrimary,
      size: 24,
    ),

    // CORRECTION ICI : Utilisation de CardThemeData directement
    cardTheme: const CardThemeData(
      color: darkCard,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: darkTextPrimary,
      textColor: darkTextPrimary,
    ),

    dividerTheme: const DividerThemeData(
      color: darkDivider,
      thickness: 1,
      space: 20,
    ),

    dialogTheme: const DialogThemeData(
      backgroundColor: darkCard,
      titleTextStyle: TextStyle(
        color: darkTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: TextStyle(
        color: darkTextSecondary,
        fontSize: 14,
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: darkCard,
      modalBackgroundColor: darkCard,
    ),
  );

  // Méthodes utilitaires
  static Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextPrimary
        : lightTextPrimary;
  }

  static Color getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkTextSecondary
        : lightTextSecondary;
  }

  static Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkCard
        : lightCard;
  }

  static Color getInputFillColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkSurface
        : lightSurface;
  }

  static Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? darkBorder
        : lightBorder;
  }
}
