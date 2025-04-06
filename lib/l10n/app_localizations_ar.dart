import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'بث الفندق';

  @override
  String get welcome => 'مرحباً';

  @override
  String get channels => 'القنوات التلفزيونية';

  @override
  String get selectChannel => 'اختر قناة لبدء المشاهدة';

  @override
  String get live => 'مباشر';

  @override
  String get category => 'الفئة';

  @override
  String get all => 'الكل';

  @override
  String get entertainment => 'ترفيه';

  @override
  String get news => 'أخبار';

  @override
  String get general => 'عام';

  @override
  String get regional => 'محلي';

  @override
  String get business => 'أعمال';

  @override
  String get national => 'وطني';

  @override
  String get religious => 'ديني';

  @override
  String get sports => 'رياضة';

  @override
  String get culture => 'ثقافة';

  @override
  String get languageSelect => 'اختر اللغة';

  @override
  String get english => 'الإنجليزية';

  @override
  String get french => 'الفرنسية';

  @override
  String get arabic => 'العربية';

  @override
  String get channelOffline => 'القناة غير متصلة حالياً';

  @override
  String get noChannels => 'لا توجد قنوات متاحة';

  @override
  String get noInternetConnection =>
      'لا يوجد اتصال بالإنترنت. يرجى التحقق من إعدادات الشبكة';

  @override
  String get channelNotFound => 'القناة غير موجودة أو لم تعد متاحة';

  @override
  String get accessDenied => 'الوصول إلى هذه القناة مقيد';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get welcomeMessage => 'Welcome to One Resort';

  @override
  String get info => 'Info';

  @override
  String get weather => 'Weather';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get current => 'Current';

  @override
  String languageResetMessage(Object days) {
    return 'Language will reset to English in $days days';
  }

  @override
  String get back => 'Back';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get fullscreen => 'Fullscreen';

  @override
  String get exitFullscreen => 'Exit Fullscreen';

  @override
  String get channelList => 'Channel List';

  @override
  String get dateTime => 'Date & Time';

  @override
  String get location => 'Location';

  @override
  String get temperature => 'Temperature';

  @override
  String get humidity => 'Humidity';

  @override
  String get windSpeed => 'Wind Speed';

  @override
  String get feelsLike => 'Feels Like';

  @override
  String get description => 'Description';

  @override
  String get noWeatherData => 'No weather data available';
}
