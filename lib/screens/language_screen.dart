import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../constants/app_constants.dart';
import '../widgets/tv_focusable.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart' as gen;
import '../providers/hotel_provider.dart';

class Language {
  final String name;
  final String flag;
  final Locale locale;

  Language({
    required this.name,
    required this.flag,
    required this.locale,
  });
}

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool _isNavbarFocused = false;
  int _selectedNavbarItem = 0;
  int _selectedLanguageIndex = 0;
  bool _isBackButtonSelected = false;
  List<Language> _languages = [
    Language(
      name: 'English',
      flag: '🇺🇸',
      locale: const Locale('en'),
    ),
    Language(
      name: 'Français',
      flag: '🇫🇷',
      locale: const Locale('fr'),
    ),
    Language(
      name: 'العربية',
      flag: '🇸🇦',
      locale: const Locale('ar'),
    ),
    Language(
      name: 'Español',
      flag: '🇪🇸',
      locale: const Locale('es'),
    ),
    Language(
      name: 'Deutsch',
      flag: '🇩🇪',
      locale: const Locale('de'),
    ),
    Language(
      name: 'Italiano',
      flag: '🇮🇹',
      locale: const Locale('it'),
    ),
    Language(
      name: 'Русский',
      flag: '🇷🇺',
      locale: const Locale('ru'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    RawKeyboard.instance.addListener(_handleNavigationKeyPress);
    // Initialize the current language index
    final currentLocale = context.read<LanguageProvider>().currentLocale;
    _selectedLanguageIndex =
        _languages.indexWhere((lang) => lang.locale == currentLocale);
  }

  @override
  void dispose() {
    print('LanguageScreen: disposing resources');
    RawKeyboard.instance.removeListener(_handleNavigationKeyPress);
    super.dispose();
  }

  KeyEventResult _handleNavigationKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _isBackButtonSelected = true;
          _selectedLanguageIndex = -1;
        });
        print('Up arrow pressed - back button selected');
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_isBackButtonSelected) {
          setState(() {
            _isBackButtonSelected = false;
            _selectedLanguageIndex = 0;
          });
          print('Down arrow pressed - first language selected');
          return KeyEventResult.handled;
        }
        setState(() {
          _selectedLanguageIndex =
              (_selectedLanguageIndex + 4).clamp(0, _languages.length - 1);
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_isBackButtonSelected) {
          return KeyEventResult.handled;
        }
        setState(() {
          _selectedLanguageIndex =
              (_selectedLanguageIndex - 1).clamp(0, _languages.length - 1);
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_isBackButtonSelected) {
          return KeyEventResult.handled;
        }
        setState(() {
          _selectedLanguageIndex =
              (_selectedLanguageIndex + 1).clamp(0, _languages.length - 1);
        });
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (_isBackButtonSelected) {
          print('Enter pressed on back button - navigating to home');
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          return KeyEventResult.handled;
        }
        if (_selectedLanguageIndex >= 0 &&
            _selectedLanguageIndex < _languages.length) {
          _onLanguageSelected(_languages[_selectedLanguageIndex]);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.goBack) {
        print('LanguageScreen: back key pressed - disabled');
        // Back key is disabled for screen navigation
        print(
            'Back key is disabled - only back button works to return to home');
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  String _getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇬🇧';
      case 'fr':
        return '🇫🇷';
      case 'ar':
        return '🇹🇳';
      case 'de':
        return '🇩🇪';
      case 'ru':
        return '🇷🇺';
      case 'it':
        return '🇮🇹';
      case 'es':
        return '🇪🇸';
      default:
        return '🌐';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = gen.AppLocalizations.of(context)!;
    final hotelProvider = Provider.of<HotelProvider>(context);
    final isOffline = hotelProvider.isOffline;
    final error = hotelProvider.error;

    return WillPopScope(
      onWillPop: () async {
        print('Back navigation is disabled - only back button works');
        // Prevent default back navigation
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.surface,
                    AppColors.surface.withOpacity(0.8),
                    AppColors.primary.withOpacity(0.05),
                  ],
                ),
              ),
            ),

            // Main content
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // App bar with glass effect
                ClipRRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.5),
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                      ),
                      child: SafeArea(
                        child: Row(
                          children: [
                            // Back button with glass effect
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _isBackButtonSelected
                                        ? AppColors.primary.withOpacity(0.3)
                                        : _isNavbarFocused &&
                                                _selectedNavbarItem == 0
                                            ? AppColors.primary.withOpacity(0.3)
                                            : AppColors.primary
                                                .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _isBackButtonSelected
                                          ? AppColors.primary
                                          : _isNavbarFocused &&
                                                  _selectedNavbarItem == 0
                                              ? AppColors.primary
                                              : AppColors.primary
                                                  .withOpacity(0.1),
                                      width: _isBackButtonSelected ||
                                              (_isNavbarFocused &&
                                                  _selectedNavbarItem == 0)
                                          ? 2
                                          : 1,
                                    ),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.arrow_back,
                                      color: _isBackButtonSelected
                                          ? AppColors.primary
                                          : _isNavbarFocused &&
                                                  _selectedNavbarItem == 0
                                              ? AppColors.primary
                                              : AppColors.primary
                                                  .withOpacity(0.7),
                                    ),
                                    onPressed: () {
                                      print(
                                          'LanguageScreen: back button pressed, navigating to home');
                                      // Navigate to the home screen
                                      Navigator.pushNamedAndRemoveUntil(
                                          context, '/home', (route) => false);
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            // Title
                            Text(
                              l10n.selectLanguage,
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: Focus(
                    focusNode: FocusNode(),
                    onKey: (node, event) => _handleNavigationKeyPress(event),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _languages.length,
                      itemBuilder: (context, index) {
                        final language = _languages[index];
                        final isSelected = index == _selectedLanguageIndex;

                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedLanguageIndex = index;
                            });
                            _onLanguageSelected(language);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.accent,
                                      ],
                                    )
                                  : null,
                              color: isSelected
                                  ? null
                                  : AppColors.surface.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.primary.withOpacity(0.1),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Language flag
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.surface.withOpacity(0.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      language.flag,
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.text,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Language name
                                Text(
                                  language.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.text,
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onLanguageSelected(Language language) async {
    try {
      print('Changing language to: ${language.name}');
      await context.read<LanguageProvider>().setLocale(language.locale);
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      print('Error changing language: $e');
    }
  }
}
