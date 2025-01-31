import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../constants/app_constants.dart';
import 'dart:ui';
import '../widgets/tv_focusable.dart';

class LanguageSelector extends StatefulWidget {
  const LanguageSelector({super.key});

  @override
  State<LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<LanguageSelector> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final theme = Theme.of(context);

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return TVFocusable(
          id: 'language_selector',
          onSelect: () => _showLanguageDialog(context, languageProvider),
          child: GestureDetector(
            onTap: () => _showLanguageDialog(context, languageProvider),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.2),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isPortrait ? 12 : 16,
                vertical: 12,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getLanguageFlag(
                        languageProvider.currentLocale.languageCode),
                    style: const TextStyle(fontSize: 24),
                  ),
                  if (!isPortrait) ...[
                    const SizedBox(width: 8),
                    Text(
                      _getLanguageName(
                          languageProvider.currentLocale.languageCode),
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.text,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showLanguageDialog(BuildContext context, LanguageProvider languageProvider) async {
    final selectedLocale = await showDialog<Locale>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surface.withOpacity(0.7),
                      AppColors.surface.withOpacity(0.5),
                      AppColors.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with glass effect
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withOpacity(0.1),
                                AppColors.accent.withOpacity(0.1),
                              ],
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                            ),
                          ),
                          child: ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.accent,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              'Select Language',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Language options
                    Container(
                      width: 400,
                      height: 300,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: LanguageProvider.supportedLocales.length,
                        itemBuilder: (context, index) {
                          final entry = LanguageProvider.supportedLocales.entries.elementAt(index);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: TVFocusable(
                              id: 'language_option_$index',
                              autofocus: index == _selectedIndex,
                              onSelect: () {
                                Navigator.of(context).pop(entry.value);
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).pop(entry.value);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              AppColors.surface.withOpacity(0.3),
                                              AppColors.surface.withOpacity(0.1),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppColors.primary.withOpacity(0.1),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary.withOpacity(0.1),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.primary.withOpacity(0.2),
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  _getLanguageFlag(entry.key),
                                                  style: const TextStyle(fontSize: 24),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _getLanguageName(entry.key),
                                                    style: TextStyle(
                                                      color: AppColors.text,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    entry.key.toUpperCase(),
                                                    style: TextStyle(
                                                      color: AppColors.textSecondary,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(
                                              Icons.chevron_right,
                                              color: AppColors.primary.withOpacity(0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (selectedLocale != null) {
      Provider.of<LanguageProvider>(context, listen: false).setLocale(selectedLocale);
    }
  }

  String _getLanguageFlag(String languageCode) {
    switch (languageCode) {
      case 'en':
        return '🇬🇧';
      case 'fr':
        return '🇫🇷';
      case 'ar':
        return '🇹🇳';
      default:
        return '🌐';
    }
  }

  String _getLanguageName(String languageCode) {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'fr':
        return 'Français';
      case 'ar':
        return 'العربية';
      case 'es':
        return 'Español';
      case 'de':
        return 'Deutsch';
      case 'it':
        return 'Italiano';
      case 'pt':
        return 'Português';
      case 'ru':
        return 'Русский';
      case 'zh':
        return '中文';
      case 'ja':
        return '日本語';
      case 'ko':
        return '한국어';
      case 'hi':
        return 'हिन्दी';
      default:
        return languageCode.toUpperCase();
    }
  }
}