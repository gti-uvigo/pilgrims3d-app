import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el estado del tema de la aplicación (claro/oscuro).
class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => _themeMode;
  bool _isInitialized = false;

  ThemeProvider() {
    _loadTheme();
  }

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('theme') ?? 'light';
    _themeMode = theme == 'dark' ? ThemeMode.dark : ThemeMode.light;
    
    // Solo notificar si no es la primera carga (optimización)
    if (_isInitialized) {
      notifyListeners();
    }
    _isInitialized = true;
  }

  Future<void> toggleTheme(bool isDark) async {
    final newMode = isDark ? ThemeMode.dark : ThemeMode.light;
    
    // Solo actualizar si hay cambio
    if (_themeMode != newMode) {
      _themeMode = newMode;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme', isDark ? 'dark' : 'light');
      notifyListeners();
    }
  }
}
