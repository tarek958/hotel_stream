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
      'channelOffline': 'Channel is currently offline',
      'noChannels': 'No channels available',
      'noInternetConnection': 'No internet connection. Please check your network settings.',
      'channelNotFound': 'Channel not found or no longer available',
      'accessDenied': 'Access to this channel is restricted',
      'retry': 'Retry'
    },
    'fr': {
      'appTitle': 'Diffusion Hôtel',
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
      'languageSelect': 'Sélectionner la langue',
      'english': 'Anglais',
      'french': 'Français',
      'arabic': 'Arabe',
      'channelOffline': 'La chaîne est actuellement hors ligne',
      'noChannels': 'Aucune chaîne disponible',
      'noInternetConnection': 'Pas de connexion Internet. Veuillez vérifier vos paramètres réseau',
      'channelNotFound': 'Chaîne introuvable ou non disponible',
      'accessDenied': "L'accès à cette chaîne est restreint",
      'retry': 'Réessayer'
    },
    'ar': {
      'appTitle': 'بث الفندق',
      'welcome': 'مرحباً',
      'channels': 'القنوات التلفزيونية',
      'selectChannel': 'اختر قناة لبدء المشاهدة',
      'live': 'مباشر',
      'category': 'الفئة',
      'all': 'الكل',
      'entertainment': 'الترفيه',
      'news': 'الأخبار',
      'general': 'عام',
      'regional': 'محلي',
      'business': 'الأعمال',
      'national': 'وطني',
      'religious': 'ديني',
      'sports': 'رياضة',
      'culture': 'ثقافة',
      'languageSelect': 'اختر اللغة',
      'english': 'الإنجليزية',
      'french': 'الفرنسية',
      'arabic': 'العربية',
      'channelOffline': 'القناة غير متصلة حالياً',
      'noChannels': 'لا توجد قنوات متاحة',
      'noInternetConnection': 'لا يوجد اتصال بالإنترنت. يرجى التحقق من إعدادات الشبكة',
      'channelNotFound': 'القناة غير موجودة أو لم تعد متاحة',
      'accessDenied': 'الوصول إلى هذه القناة مقيد',
      'retry': 'إعادة المحاولة'
    },
  };

  String get appTitle => _localizedValues[locale.languageCode]!['appTitle']!;
  String get welcome => _localizedValues[locale.languageCode]!['welcome']!;
  String get channels => Intl.message('Channels', name: 'channels');
  String get selectChannel => _localizedValues[locale.languageCode]!['selectChannel']!;
  String get live => Intl.message('LIVE', name: 'live');
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
  String get channelOffline => _localizedValues[locale.languageCode]!['channelOffline'] ?? 'Channel is currently offline';
  String get noChannels => _localizedValues[locale.languageCode]!['noChannels'] ?? 'No channels available';
  String get noInternetConnection => _localizedValues[locale.languageCode]!['noInternetConnection'] ?? 'No internet connection. Please check your network settings.';
  String get channelNotFound => _localizedValues[locale.languageCode]!['channelNotFound'] ?? 'Channel not found or no longer available';
  String get accessDenied => _localizedValues[locale.languageCode]!['accessDenied'] ?? 'Access to this channel is restricted';
  String get retry => _localizedValues[locale.languageCode]!['retry'] ?? 'Retry';
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
