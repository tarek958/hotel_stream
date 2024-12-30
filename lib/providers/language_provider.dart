import 'package:flutter/material.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('en');

  Locale get currentLocale => _currentLocale;

  void setLocale(Locale locale) {
    _currentLocale = locale;
    notifyListeners();
  }

  static final Map<String, Locale> supportedLocales = {
    'English': const Locale('en'),
    'Français': const Locale('fr'),
    'العربية': const Locale('ar'),
  };
}
