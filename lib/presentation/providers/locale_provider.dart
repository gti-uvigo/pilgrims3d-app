import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pilgrims_3d/services/translations/translations.dart';

class LocaleProvider with ChangeNotifier {
  static const String _languageKey = 'selected_language_code';

  String _currentLangId = kEnglishId;
  Locale _locale = const Locale('en');
  bool _isInitialized = false;

  Locale get locale => _locale;
  String get currentLangId => _currentLangId;
  String get currentIso => idToIsoMap[_currentLangId] ?? 'en';

  LocaleProvider() {
    _initLocale();
  }

  Future<void> _initLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_languageKey);

    if (savedId != null && translations.containsKey(savedId)) {
      _applyLangId(savedId, persist: false, notify: false);
      _isInitialized = true;
      return;
    }

    final deviceLocales = WidgetsBinding.instance.platformDispatcher.locales;
    final deviceIso = deviceLocales.isNotEmpty ? deviceLocales.first.languageCode.toLowerCase() : 'en';

    final mappedId = isoToIdMap[deviceIso] ?? kEnglishId;
    _applyLangId(mappedId, persist: false, notify: false);
    _isInitialized = true;
  }

  Future<void> setLocaleById(String langId) async {
    if (!translations.containsKey(langId)) {
      langId = kEnglishId;
    }
    // Solo actualizar si hay cambio
    if (_currentLangId != langId) {
      _applyLangId(langId);
    }
  }

  Future<void> setLocaleByIso(String isoCode) async {
    final langId = isoToIdMap[isoCode.toLowerCase()] ?? kEnglishId;
    if (_currentLangId != langId) {
      _applyLangId(langId);
    }
  }

  void _applyLangId(String langId, {bool persist = true, bool notify = true}) async {
    _currentLangId = langId;
    final iso = idToIsoMap[langId] ?? 'en';
    _locale = Locale(iso);
    
    // Solo notificar si está inicializado y se solicita notificación
    if (_isInitialized && notify) {
      notifyListeners();
    }
    
    if (persist) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, langId);
    }
  }

  String translate(String key, {Map<String, String>? args}) {
    final map = translations[_currentLangId] ?? translations[kEnglishId]!;
    String text = map[key] ?? translations[kEnglishId]![key] ?? key;
    args?.forEach((placeholder, value) {
      text = text.replaceAll('{$placeholder}', value);
    });
    return text;
  }

  Future<String> getLangCode() async {
    return _currentLangId;
  }
}
