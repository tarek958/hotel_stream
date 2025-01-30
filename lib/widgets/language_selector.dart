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
  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final theme = Theme.of(context);

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return GestureDetector(
          onTap: () async {
            final selectedLocale = await showDialog<Locale>(
              context: context,
              builder: (BuildContext context) {
                return Dialog(
                  backgroundColor: Colors.transparent,
                  insetPadding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.dialogBackgroundColor.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Select Language',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Divider(height: 1, color: Colors.grey),
                            SizedBox(
                              width: double.maxFinite,
                              height: 300,
                              child: ListView.builder(
                                itemCount: LanguageProvider.supportedLocales.length,
                                itemBuilder: (context, index) {
                                  final entry = LanguageProvider.supportedLocales.entries.elementAt(index);
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.of(context).pop(entry.value);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                        child: Row(
                                          children: [
                                            Text(
                                              _getLanguageFlag(entry.key),
                                              style: const TextStyle(fontSize: 24),
                                            ),
                                            const SizedBox(width: 16),
                                            Text(
                                              entry.key,
                                              style: theme.textTheme.titleMedium?.copyWith(
                                                color: theme.textTheme.bodyLarge?.color,
                                              ),
                                            ),
                                          ],
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
              Provider.of<LanguageProvider>(context, listen: false)
                  .setLocale(selectedLocale);
            }
          },
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
        );
      },
    );
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
      default:
        return 'Unknown';
    }
  }
}