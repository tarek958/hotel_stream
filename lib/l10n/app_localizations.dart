import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Hotel Stream',
      'welcome': 'Welcome',
      'channels': 'TV Channels',
      'selectChannel': 'Select a channel to start watching',
      'live': 'LIVE',
      'category': 'Category',
      'all': 'All',
      'entertainment': 'Entertainment',
      'news': 'News',
      'general': 'General',
      'regional': 'Regional',
      'business': 'Business',
      'national': 'National',
      'religious': 'Religious',
      'sports': 'Sports',
      'culture': 'Culture',
      'languageSelect': 'Select Language',
      'english': 'English',
      'french': 'French',
      'arabic': 'Arabic',
    },
    'fr': {
      'appTitle': 'Hotel Stream',
      'welcome': 'Bienvenue',
      'channels': 'Chaînes TV',
      'selectChannel': 'Sélectionnez une chaîne pour commencer à regarder',
      'live': 'EN DIRECT',
      'category': 'Catégorie',
      'all': 'Tout',
      'entertainment': 'Divertissement',
      'news': 'Actualités',
      'general': 'Général',
      'regional': 'Régional',
      'business': 'Affaires',
      'national': 'National',
      'religious': 'Religieux',
      'sports': 'Sports',
      'culture': 'Culture',
      'languageSelect': 'Choisir la langue',
      'english': 'Anglais',
      'french': 'Français',
      'arabic': 'Arabe',
    },
    'ar': {
      'appTitle': 'هوتيل ستريم',
      'welcome': 'مرحباً',
      'channels': 'القنوات التلفزيونية',
      'selectChannel': 'اختر قناة لبدء المشاهدة',
      'live': 'مباشر',
      'category': 'الفئة',
      'all': 'الكل',
      'entertainment': 'ترفيه',
      'news': 'أخبار',
      'general': 'عام',
      'regional': 'محلي',
      'business': 'أعمال',
      'national': 'وطني',
      'religious': 'ديني',
      'sports': 'رياضة',
      'culture': 'ثقافة',
      'languageSelect': 'اختر اللغة',
      'english': 'الإنجليزية',
      'french': 'الفرنسية',
      'arabic': 'العربية',
    },
  };

  String get appTitle => _localizedValues[locale.languageCode]!['appTitle']!;
  String get welcome => _localizedValues[locale.languageCode]!['welcome']!;
  String get channels => _localizedValues[locale.languageCode]!['channels']!;
  String get selectChannel => _localizedValues[locale.languageCode]!['selectChannel']!;
  String get live => _localizedValues[locale.languageCode]!['live']!;
  String get category => _localizedValues[locale.languageCode]!['category']!;
  String get all => _localizedValues[locale.languageCode]!['all']!;
  String get entertainment => _localizedValues[locale.languageCode]!['entertainment']!;
  String get news => _localizedValues[locale.languageCode]!['news']!;
  String get general => _localizedValues[locale.languageCode]!['general']!;
  String get regional => _localizedValues[locale.languageCode]!['regional']!;
  String get business => _localizedValues[locale.languageCode]!['business']!;
  String get national => _localizedValues[locale.languageCode]!['national']!;
  String get religious => _localizedValues[locale.languageCode]!['religious']!;
  String get sports => _localizedValues[locale.languageCode]!['sports']!;
  String get culture => _localizedValues[locale.languageCode]!['culture']!;
  String get languageSelect => _localizedValues[locale.languageCode]!['languageSelect']!;
  String get english => _localizedValues[locale.languageCode]!['english']!;
  String get french => _localizedValues[locale.languageCode]!['french']!;
  String get arabic => _localizedValues[locale.languageCode]!['arabic']!;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'fr', 'ar'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
