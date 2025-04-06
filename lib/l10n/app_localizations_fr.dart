import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Diffusion Hôtel';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get channels => 'Chaînes';

  @override
  String get selectChannel => 'Sélectionnez une chaîne pour commencer';

  @override
  String get live => 'EN DIRECT';

  @override
  String get category => 'Catégorie';

  @override
  String get all => 'Tout';

  @override
  String get entertainment => 'Divertissement';

  @override
  String get news => 'Actualités';

  @override
  String get general => 'Général';

  @override
  String get regional => 'Régional';

  @override
  String get business => 'Affaires';

  @override
  String get national => 'National';

  @override
  String get religious => 'Religieux';

  @override
  String get sports => 'Sports';

  @override
  String get culture => 'Culture';

  @override
  String get languageSelect => 'Sélectionner la langue';

  @override
  String get english => 'Anglais';

  @override
  String get french => 'Français';

  @override
  String get arabic => 'Arabe';

  @override
  String get channelOffline => 'La chaîne est actuellement hors ligne';

  @override
  String get noChannels => 'Aucune chaîne disponible';

  @override
  String get noInternetConnection =>
      'Pas de connexion Internet. Veuillez vérifier vos paramètres réseau';

  @override
  String get channelNotFound => 'Chaîne introuvable ou non disponible';

  @override
  String get accessDenied => 'L\'accès à cette chaîne est restreint';

  @override
  String get retry => 'Réessayer';

  @override
  String get welcomeMessage => 'Bienvenue à One Resort';

  @override
  String get info => 'Info';

  @override
  String get weather => 'Météo';

  @override
  String get language => 'Langue';

  @override
  String get selectLanguage => 'Sélectionner la langue';

  @override
  String get current => 'Actuel';

  @override
  String languageResetMessage(Object days) {
    return 'La langue sera réinitialisée en anglais dans $days jours';
  }

  @override
  String get back => 'Retour';

  @override
  String get loading => 'Chargement...';

  @override
  String get error => 'Erreur';

  @override
  String get fullscreen => 'Plein écran';

  @override
  String get exitFullscreen => 'Quitter le plein écran';

  @override
  String get channelList => 'Liste des chaînes';

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
