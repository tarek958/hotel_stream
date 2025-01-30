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
  bool _isOpen = false;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  int _selectedIndex = -1;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _selectedIndex = -1;
  }

  void _handleKeyEvent(RawKeyEvent event) {
    if (!_isOpen) return;

    if (event is RawKeyDownEvent) {
      final languages = LanguageProvider.supportedLocales.entries.toList();
      switch (event.logicalKey.keyLabel) {
        case 'Arrow Down':
          setState(() {
            if (_selectedIndex < languages.length - 1) {
              _selectedIndex++;
            }
          });
          break;
        case 'Arrow Up':
          setState(() {
            if (_selectedIndex > 0) {
              _selectedIndex--;
            } else {
              // If at the top, close dropdown
              _isOpen = false;
              _removeOverlay();
            }
          });
          break;
        case 'Enter':
          if (_selectedIndex >= 0 && _selectedIndex < languages.length) {
            final entry = languages[_selectedIndex];
            Provider.of<LanguageProvider>(context, listen: false)
                .setLocale(entry.value);
            setState(() {
              _isOpen = false;
              _removeOverlay();
            });
          }
          break;
      }
    }
  }

  void _showOverlay(BuildContext context) {
    _removeOverlay();
    _selectedIndex = 0; // Select first option when opening

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          final languages = LanguageProvider.supportedLocales.entries.toList();
          return Positioned(
            width: 200,
            child: CompositedTransformFollower(
              link: _layerLink,
              targetAnchor: Alignment.bottomCenter,
              followerAnchor: Alignment.topCenter,
              offset: const Offset(0, -8),
              child: Material(
                color: Colors.transparent,
                child: Focus(
                  autofocus: true,
                  canRequestFocus: true,
                  onKeyEvent: (node, event) {
                    if (!_isOpen) return KeyEventResult.ignored;

                    if (event is KeyDownEvent) {
                      final languages =
                          LanguageProvider.supportedLocales.entries.toList();
                      switch (event.logicalKey) {
                        case LogicalKeyboardKey.arrowDown:
                          setState(() {
                            if (_selectedIndex < languages.length - 1) {
                              _selectedIndex++;
                            }
                          });
                          return KeyEventResult.handled;
                        case LogicalKeyboardKey.arrowUp:
                          setState(() {
                            if (_selectedIndex > 0) {
                              _selectedIndex--;
                            } else {
                              // If at the top, close dropdown
                              _isOpen = false;
                              _removeOverlay();
                            }
                          });
                          return KeyEventResult.handled;
                        case LogicalKeyboardKey.enter:
                          if (_selectedIndex >= 0 &&
                              _selectedIndex < languages.length) {
                            final entry = languages[_selectedIndex];
                            Provider.of<LanguageProvider>(context,
                                    listen: false)
                                .setLocale(entry.value);
                            setState(() {
                              _isOpen = false;
                              _removeOverlay();
                            });
                          }
                          return KeyEventResult.handled;
                        default:
                          return KeyEventResult.ignored;
                      }
                    }
                    return KeyEventResult.ignored;
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.2),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children:
                              languages.asMap().entries.map((indexedEntry) {
                            final entry = indexedEntry.value;
                            final index = indexedEntry.key;
                            final isSelected =
                                entry.value == languageProvider.currentLocale;
                            final isFocused = index == _selectedIndex;

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                gradient: (isSelected || isFocused)
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.primary.withOpacity(0.3),
                                          AppColors.accent.withOpacity(0.3),
                                        ],
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    _getLanguageFlag(entry.value.languageCode),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      style: TextStyle(
                                        color: (isSelected || isFocused)
                                            ? AppColors.primary
                                            : AppColors.text,
                                        fontSize: 16,
                                        fontWeight: (isSelected || isFocused)
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
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
    );

    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return CompositedTransformTarget(
          link: _layerLink,
          child: Focus(
            onKeyEvent: (node, event) {
              if (_isOpen && event is KeyDownEvent) {
                final languages =
                    LanguageProvider.supportedLocales.entries.toList();
                switch (event.logicalKey) {
                  case LogicalKeyboardKey.arrowDown:
                    setState(() {
                      if (_selectedIndex < languages.length - 1) {
                        _selectedIndex++;
                      }
                    });
                    return KeyEventResult.handled;
                  case LogicalKeyboardKey.arrowUp:
                    setState(() {
                      if (_selectedIndex > 0) {
                        _selectedIndex--;
                      } else {
                        _isOpen = false;
                        _removeOverlay();
                      }
                    });
                    return KeyEventResult.handled;
                  case LogicalKeyboardKey.enter:
                    if (_selectedIndex >= 0 &&
                        _selectedIndex < languages.length) {
                      final entry = languages[_selectedIndex];
                      Provider.of<LanguageProvider>(context, listen: false)
                          .setLocale(entry.value);
                      setState(() {
                        _isOpen = false;
                        _removeOverlay();
                      });
                    }
                    return KeyEventResult.handled;
                  default:
                    return KeyEventResult.ignored;
                }
              }
              return KeyEventResult.ignored;
            },
            child: TVFocusable(
              id: 'language_selector',
              focusColor: AppColors.primary,
              onSelect: () {
                setState(() {
                  _isOpen = !_isOpen;
                  if (_isOpen) {
                    _showOverlay(context);
                  } else {
                    _removeOverlay();
                  }
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isPortrait ? 8 : 12,
                      vertical: 8,
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
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isOpen
                                ? Icons.arrow_drop_up
                                : Icons.arrow_drop_down,
                            color: AppColors.text,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
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
