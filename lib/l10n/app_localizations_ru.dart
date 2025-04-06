import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'One Resort';

  @override
  String get welcome => 'Добро пожаловать';

  @override
  String get channels => 'Каналы';

  @override
  String get selectChannel => 'Выберите канал для просмотра';

  @override
  String get live => 'ПРЯМОЙ ЭФИР';

  @override
  String get category => 'Категория';

  @override
  String get all => 'Все';

  @override
  String get entertainment => 'Развлечения';

  @override
  String get news => 'Новости';

  @override
  String get general => 'Общие';

  @override
  String get regional => 'Региональные';

  @override
  String get business => 'Бизнес';

  @override
  String get national => 'Национальные';

  @override
  String get religious => 'Религиозные';

  @override
  String get sports => 'Спорт';

  @override
  String get culture => 'Культура';

  @override
  String get languageSelect => 'Выбор языка';

  @override
  String get english => 'Английский';

  @override
  String get french => 'Французский';

  @override
  String get arabic => 'Арабский';

  @override
  String get channelOffline => 'Канал в данный момент не доступен';

  @override
  String get noChannels => 'Нет доступных каналов';

  @override
  String get noInternetConnection =>
      'Нет подключения к интернету. Пожалуйста, проверьте настройки сети';

  @override
  String get channelNotFound => 'Канал не найден или больше не доступен';

  @override
  String get accessDenied => 'Доступ к этому каналу ограничен';

  @override
  String get retry => 'Повторить';

  @override
  String get welcomeMessage => 'Добро пожаловать в One Resort';

  @override
  String get info => 'Информация';

  @override
  String get weather => 'Погода';

  @override
  String get language => 'Язык';

  @override
  String get selectLanguage => 'Выберите язык';

  @override
  String get current => 'Текущий';

  @override
  String languageResetMessage(Object days) {
    return 'Язык будет сброшен на английский через $days дней';
  }

  @override
  String get back => 'Назад';

  @override
  String get loading => 'Загрузка...';

  @override
  String get error => 'Ошибка';

  @override
  String get fullscreen => 'Полный экран';

  @override
  String get exitFullscreen => 'Выйти из полноэкранного режима';

  @override
  String get channelList => 'Список каналов';

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
