import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/intro_screen.dart';
import 'screens/offline_screen.dart';
import 'screens/home_screen.dart';
import 'screens/channels_screen.dart';
import 'screens/language_screen.dart';
import 'screens/weather_screen.dart';
import 'screens/info_screen.dart';
import 'providers/language_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/hotel_provider.dart';
import 'providers/theme_provider.dart';
import 'constants/app_constants.dart';
import 'l10n/app_localizations.dart';
import 'providers/publicity_provider.dart';
import 'services/tv_focus_service.dart';
import 'providers/weather_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart' as gen;

void main() {
  // Add error handling to prevent crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Log the error but don't crash the app
    print('ERROR: ${details.exception}');
    print('STACK: ${details.stack}');
  };

  // Ensure proper binding initialization
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => HotelProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => PublicityProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'One Resort',
            locale: languageProvider.currentLocale,
            supportedLocales: gen.AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              gen.AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              primarySwatch: Colors.blue,
              visualDensity: VisualDensity.adaptivePlatformDensity,
            ),
            onGenerateRoute: (settings) {
              switch (settings.name) {
                case '/':
                  return MaterialPageRoute(
                    builder: (context) => Consumer<HotelProvider>(
                      builder: (context, hotelProvider, child) {
                        if (hotelProvider.isOffline) {
                          return const OfflineScreen();
                        }
                        return const IntroScreen();
                      },
                    ),
                  );
                case '/home':
                  return MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  );
                case '/channels':
                  return MaterialPageRoute(
                    builder: (context) => const ChannelsScreen(),
                  );
                case '/language':
                  return MaterialPageRoute(
                    builder: (context) => const LanguageScreen(),
                  );
                case '/weather':
                  return MaterialPageRoute(
                    builder: (context) => const WeatherScreen(),
                  );
                case '/info':
                  return MaterialPageRoute(
                    builder: (context) => const InfoScreen(),
                  );
                default:
                  return MaterialPageRoute(
                    builder: (context) => const HomeScreen(),
                  );
              }
            },
          );
        },
      ),
    );
  }
}
