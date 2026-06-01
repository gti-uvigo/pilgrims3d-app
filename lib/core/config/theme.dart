// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Configuración de temas de la aplicación
class AppTheme {
  // Colores principales - Tema Rural/Natural
  static const Color primaryGreen = Color(0xFF365037); // Verde oscuro elegante
  static const Color secondaryGreen = Color(0xFF5A6B57); // Verde oliva oscuro
  static const Color accentBrown = Color(0xFF7B6B5A); // Marrón elegante
  static const Color lightBrown = Color(0xFFB0A494); // Marrón claro
  static const Color darkGray = Color(0xFF3E3E3E); // Gris oscuro
  static const Color lightBackground = Color(0xFFF5F3EF); // Fondo claro neutro
  static const Color cardBackground = Color(0xFFF0ECE6); // Fondo de tarjetas
  static const Color lightAccent = Color(0xFFE7FAE0); // Verde oliva claro

  /// Tema claro de la aplicación
  static ThemeData get lightTheme {
    return ThemeData(
      // Colores principales
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: lightBackground,
      secondaryHeaderColor: lightAccent,
      cardColor: Colors.white,

      // Color Scheme
      colorScheme: ColorScheme.light(
        primary: primaryGreen,
        secondary: secondaryGreen,
        tertiary: accentBrown,
        surface: const Color(0xFFEBD1AB),
        onPrimary: const Color(0xFFDDE2D4),
        onSecondary: Colors.white,
        onSurface: darkGray,
      ),

      // Iconos
      iconTheme: const IconThemeData(color: darkGray, size: 24),

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFEFE8E3),
        foregroundColor: darkGray,
        elevation: 2,
        centerTitle: false,
        iconTheme: IconThemeData(color: darkGray),
        titleTextStyle: TextStyle(
          color: darkGray,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryGreen;
          }
          return secondaryGreen;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryGreen.withOpacity(0.5);
          }
          return secondaryGreen.withOpacity(0.3);
        }),
        overlayColor: WidgetStateProperty.all(primaryGreen.withOpacity(0.3)),
        splashRadius: 20,
      ),

      // Botones
      buttonTheme: const ButtonThemeData(
        buttonColor: primaryGreen,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentBrown,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentBrown,
          side: const BorderSide(color: lightBrown),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: primaryGreen, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: secondaryGreen, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.red, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        labelStyle: const TextStyle(color: primaryGreen),
        hintStyle: const TextStyle(color: Colors.black45),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: Colors.white,
        shadowColor: Colors.black.withOpacity(0.1),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),

      // Divider
      dividerColor: Colors.black26,
      dividerTheme: const DividerThemeData(thickness: 1, space: 1),

      // Text Theme
      textTheme: const TextTheme(
        // Títulos grandes
        displayLarge: TextStyle(
          color: darkGray,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        displayMedium: TextStyle(
          color: accentBrown,
          fontWeight: FontWeight.w600,
          fontSize: 28,
        ),
        displaySmall: TextStyle(
          color: darkGray,
          fontWeight: FontWeight.w600,
          fontSize: 24,
        ),

        // Headlines
        headlineLarge: TextStyle(
          color: darkGray,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
        headlineMedium: TextStyle(
          color: primaryGreen,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        headlineSmall: TextStyle(
          color: darkGray,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),

        // Títulos
        titleLarge: TextStyle(
          color: darkGray,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
        titleMedium: TextStyle(
          color: primaryGreen,
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          color: secondaryGreen,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),

        // Body
        bodyLarge: TextStyle(color: darkGray, fontSize: 16),
        bodyMedium: TextStyle(color: darkGray, fontSize: 14),
        bodySmall: TextStyle(color: darkGray, fontSize: 12),

        // Labels
        labelLarge: TextStyle(
          color: darkGray,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        labelMedium: TextStyle(
          color: darkGray,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          color: darkGray,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey,
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // Progress Indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryGreen,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkGray,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: lightAccent,
        selectedColor: primaryGreen,
        labelStyle: const TextStyle(color: darkGray),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  /// Tema oscuro de la aplicación
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: const Color(0xFF121212),

      colorScheme: const ColorScheme.dark(
        primary: primaryGreen,
        secondary: secondaryGreen,
        tertiary: accentBrown,
        surface: Color(0xFF1E1E1E),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1E1E1E),
        elevation: 2,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        shadowColor: Colors.black.withOpacity(0.3),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

/// Notifier para el tema de la aplicación
class ThemeNotifier extends ValueNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.light);

  /// Alternar entre tema claro y oscuro
  void toggleTheme() {
    value = value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  }

  /// Establecer tema específico
  void setTheme(ThemeMode mode) {
    value = mode;
  }

  /// Verificar si está en modo oscuro
  bool get isDarkMode => value == ThemeMode.dark;
}
