import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  static const String _localeKey = 'selected_locale';
  static const String _lastChangeKey = 'last_language_change';
  static const Duration _resetDuration = Duration(days: 7);

  static const Map<String, Locale> supportedLocales = {
    'English': const Locale('en'),
    'Français': const Locale('fr'),
    'العربية': const Locale('ar'),
    'Deutsch': const Locale('de'),
    'Русский': const Locale('ru'),
    'Italiano': const Locale('it'),
    'Español': const Locale('es'),
  };

  Locale _currentLocale = const Locale('en');
  late SharedPreferences _prefs;
  bool _isInitialized = false;

  LanguageProvider() {
    _initialize();
  }

  Locale get currentLocale => _currentLocale;
  bool get isInitialized => _isInitialized;

  Future<void> _initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSavedLanguage();
    } catch (e) {
      _currentLocale = const Locale('en');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadSavedLanguage() async {
    try {
      // Check if we need to reset to English
      final lastChangeStr = _prefs.getString(_lastChangeKey);
      if (lastChangeStr != null) {
        final lastChange = DateTime.parse(lastChangeStr);
        final now = DateTime.now();
        if (now.difference(lastChange) >= _resetDuration) {
          await setLocale(const Locale('en'));
          return;
        }
      }

      // Load saved locale
      final savedLocaleStr = _prefs.getString(_localeKey);
      if (savedLocaleStr != null) {
        final locale = Locale(savedLocaleStr);
        if (supportedLocales.values
            .any((l) => l.languageCode == locale.languageCode)) {
          _currentLocale = locale;
        } else {
          await setLocale(const Locale('en'));
        }
      } else {
        await setLocale(const Locale('en'));
      }
    } catch (e) {
      _currentLocale = const Locale('en');
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_currentLocale == locale) return;

    try {
      // Verify the locale is supported
      if (!supportedLocales.values
          .any((l) => l.languageCode == locale.languageCode)) {
        throw Exception('Unsupported locale: ${locale.languageCode}');
      }

      _currentLocale = locale;
      await _prefs.setString(_localeKey, locale.languageCode);
      await _prefs.setString(_lastChangeKey, DateTime.now().toIso8601String());
      notifyListeners();
    } catch (e) {
      // If there's an error, revert to English
      _currentLocale = const Locale('en');
      await _prefs.setString(_localeKey, 'en');
      notifyListeners();
      rethrow;
    }
  }

  // Helper method to check if language needs to be reset
  Future<bool> shouldResetLanguage() async {
    final lastChangeStr = _prefs.getString(_lastChangeKey);
    if (lastChangeStr != null) {
      final lastChange = DateTime.parse(lastChangeStr);
      final now = DateTime.now();
      return now.difference(lastChange) >= _resetDuration;
    }
    return false;
  }

  // Helper method to get remaining days before reset
  int getRemainingDays() {
    final lastChangeStr = _prefs.getString(_lastChangeKey);
    if (lastChangeStr != null) {
      final lastChange = DateTime.parse(lastChangeStr);
      final now = DateTime.now();
      final remaining = _resetDuration - now.difference(lastChange);
      return remaining.inDays;
    }
    return 0;
  }
}
