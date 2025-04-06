import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_constants.dart';
import '../widgets/common/back_button.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/code_entry_widget.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/news_ticker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart' as gen;

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  final NetworkInfo _networkInfo = NetworkInfo();
  String? _ipAddress;
  String? _macAddress;
  String? _wifiPassword;
  bool _showIpAddress = false;
  bool _showMacAddress = false;
  bool _showWifiPassword = false;
  int _selectedIndex = 0;
  bool _isDialogOpen = false;
  final TextEditingController _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  final FocusNode _screenFocusNode = FocusNode();
  bool _isBackButtonSelected = false;

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
    // Request focus for the screen when it's created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _screenFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    print('InfoScreen: disposing resources');
    // Make sure all resources are properly disposed
    _codeController.dispose();
    _codeFocusNode.dispose();
    _screenFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      print('Key pressed in info screen: ${event.logicalKey}');
      print('Dialog open: $_isDialogOpen');
      print('Screen focused: ${_screenFocusNode.hasFocus}');

      if (event.logicalKey == LogicalKeyboardKey.goBack) {
        print('Back key pressed - disabled');
        if (_isDialogOpen) {
          // Only close dialog with back key
          print('Closing dialog');
          Navigator.pop(context);
          setState(() => _isDialogOpen = false);
        } else {
          // Back key is disabled for screen navigation
          print(
              'Back key is disabled - only back button works to return to home');
        }
        return KeyEventResult.handled;
      } else if (!_isDialogOpen) {
        print('Handling navigation key');
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          // When up arrow is pressed, select the back button
          setState(() {
            _isBackButtonSelected = true;
            _selectedIndex = -1; // Deselect cards
          });
          print('Up arrow pressed - back button selected');
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          // When down arrow is pressed, deselect back button and select cards
          if (_isBackButtonSelected) {
            setState(() {
              _isBackButtonSelected = false;
              _selectedIndex = 0; // Select first card
            });
            print('Down arrow pressed - first card selected');
            return KeyEventResult.handled;
          }
        } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          if (_isBackButtonSelected) {
            // Don't change selection when back button is selected
            return KeyEventResult.handled;
          }
          if (_selectedIndex > 0) {
            setState(() => _selectedIndex--);
            print('Moved left to index: $_selectedIndex');
          }
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          if (_isBackButtonSelected) {
            // Don't change selection when back button is selected
            return KeyEventResult.handled;
          }
          if (_selectedIndex < 4) {
            setState(() => _selectedIndex++);
            print('Moved right to index: $_selectedIndex');
          }
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.select ||
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (_isBackButtonSelected) {
            // Navigate home when back button is selected and enter is pressed
            print('Enter pressed on back button - navigating to home');
            Navigator.pushNamedAndRemoveUntil(
                context, '/home', (route) => false);
            return KeyEventResult.handled;
          }
          print('Select key pressed on index: $_selectedIndex');
          _handleCardTap(_selectedIndex);
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _handleCardTap(int index) {
    if (_isDialogOpen) {
      print('Dialog is open, ignoring card tap');
      return;
    }

    print('Handling card tap for index: $index');
    switch (index) {
      case 0: // Reception
        _launchPhoneCall('+15551234567');
        break;
      case 1: // IP Address
        _showAccessDialog(
          'Enter Access Code',
          'Enter code 9999 to view IP address',
          '9999',
          (success) => setState(() => _showIpAddress = success),
        );
        break;
      case 2: // MAC Address
        _showAccessDialog(
          'Enter Access Code',
          'Enter code 8888 to view MAC address',
          '8888',
          (success) => setState(() => _showMacAddress = success),
        );
        break;
      case 3: // WiFi Network
        _showAccessDialog(
          'Enter Access Code',
          'Enter code 7777 to view WiFi password',
          '7777',
          (success) => setState(() => _showWifiPassword = success),
        );
        break;
      case 4: // Room Service
        _launchPhoneCall('+15551234568');
        break;
    }
  }

  Future<void> _loadNetworkInfo() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      final wifiBSSID = await _networkInfo.getWifiBSSID();
      setState(() {
        _ipAddress = wifiIP ?? 'Not Available';
        _macAddress = wifiBSSID ?? 'Not Available';
        _wifiPassword = 'HotelStream2024'; // Default password
      });
    } catch (e) {
      print('Error loading network info: $e');
    }
  }

  void _showAccessDialog(
      String title, String message, String code, Function(bool) onSuccess) {
    print('Showing access dialog for: $title');
    setState(() => _isDialogOpen = true);
    _codeController.clear();

    // Request focus for the code input field after dialog is shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _codeFocusNode.requestFocus();
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => WillPopScope(
        onWillPop: () async {
          print('Dialog will pop');
          setState(() => _isDialogOpen = false);
          return true;
        },
        child: Focus(
          canRequestFocus: true,
          descendantsAreFocusable: true,
          autofocus: true,
          onKey: (FocusNode node, RawKeyEvent event) {
            print('Dialog key event: ${event.logicalKey}');
            if (event is RawKeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.goBack ||
                  event.logicalKey == LogicalKeyboardKey.escape) {
                print('Closing dialog from key handler');
                Navigator.pop(context);
                setState(() => _isDialogOpen = false);
                return KeyEventResult.handled;
              } else if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.select) {
                print('Handling enter/select in dialog');
                String value = _codeController.text;
                if (value == code) {
                  print('Code correct');
                  onSuccess(true);
                  Navigator.pop(context);
                  setState(() => _isDialogOpen = false);
                } else {
                  print('Code incorrect');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid code'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return KeyEventResult.handled;
              }
            }
            return KeyEventResult.ignored;
          },
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeController,
                  focusNode: _codeFocusNode,
                  autofocus: true,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 8,
                  ),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                  onSubmitted: (value) {
                    print('Code submitted: $value');
                    if (value == code) {
                      print('Code correct');
                      onSuccess(true);
                      Navigator.pop(context);
                      setState(() => _isDialogOpen = false);
                    } else {
                      print('Code incorrect');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Invalid code'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  print('Cancel button pressed');
                  Navigator.pop(context);
                  setState(() => _isDialogOpen = false);
                },
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _screenFocusNode,
      canRequestFocus: true,
      autofocus: true,
      onKeyEvent: (node, event) {
        print('Info screen key event: ${event.logicalKey}');
        print('Dialog open: $_isDialogOpen');
        print('Screen focused: ${_screenFocusNode.hasFocus}');

        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.goBack) {
            print('Back key pressed');
            if (_isDialogOpen) {
              print('Closing dialog');
              Navigator.pop(context);
              setState(() => _isDialogOpen = false);
            } else {
              // Back key is disabled for screen navigation
              print(
                  'Back key is disabled - only back button works to return to home');
            }
            return KeyEventResult.handled;
          } else if (!_isDialogOpen) {
            print('Handling navigation key');
            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              // When up arrow is pressed, select the back button
              setState(() {
                _isBackButtonSelected = true;
                _selectedIndex = -1; // Deselect cards
              });
              print('Up arrow pressed - back button selected');
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              // When down arrow is pressed, deselect back button and select cards
              if (_isBackButtonSelected) {
                setState(() {
                  _isBackButtonSelected = false;
                  _selectedIndex = 0; // Select first card
                });
                print('Down arrow pressed - first card selected');
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              if (_isBackButtonSelected) {
                // Don't change selection when back button is selected
                return KeyEventResult.handled;
              }
              if (_selectedIndex > 0) {
                setState(() => _selectedIndex--);
                print('Moved left to index: $_selectedIndex');
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              if (_isBackButtonSelected) {
                // Don't change selection when back button is selected
                return KeyEventResult.handled;
              }
              if (_selectedIndex < 4) {
                setState(() => _selectedIndex++);
                print('Moved right to index: $_selectedIndex');
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              if (_isBackButtonSelected) {
                // Navigate home when back button is selected and enter is pressed
                print('Enter pressed on back button - navigating to home');
                Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false);
                return KeyEventResult.handled;
              }
              print('Select/Enter pressed on index: $_selectedIndex');
              _handleCardTap(_selectedIndex);
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: WillPopScope(
        onWillPop: () async {
          if (_isDialogOpen) {
            Navigator.pop(context);
            setState(() => _isDialogOpen = false);
            return false;
          }

          print('Back navigation is disabled - only back button works');
          // Prevent default back navigation
          return false;
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Background gradient
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.background.withOpacity(0.8),
                      AppColors.background.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Focus(
                            canRequestFocus: false,
                            descendantsAreFocusable: false,
                            child: CustomBackButton(
                              onSelect: () {
                                print(
                                    'InfoScreen: back button pressed, navigating to home');
                                // Navigate to the home screen
                                if (mounted) {
                                  Navigator.pushNamedAndRemoveUntil(
                                      context, '/home', (route) => false);
                                }
                              },
                              isSelected: _isBackButtonSelected,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.hotel,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'One Resort',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Hotel Logo and Description
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.surface.withOpacity(0.1),
                            AppColors.surface.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            // Hotel Logo
                            Container(
                              width: 80,
                              height: 80,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Image.asset(
                                'assets/images/ic_new-playstore.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Stars
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                5,
                                (index) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Hotel Name
                            const Text(
                              'One Resort',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Description
                            const Text(
                              'Welcome to One Resort, your premier destination for luxury and comfort.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Info Cards Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              'Reception',
                              '+1 (555) 123-4567',
                              Icons.phone,
                              isSelected: _selectedIndex == 0,
                              onTap: () => _handleCardTap(0),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoCard(
                              'IP Address',
                              _showIpAddress
                                  ? _ipAddress ?? 'Not Available'
                                  : '*****',
                              Icons.wifi,
                              isSelected: _selectedIndex == 1,
                              onTap: () => _handleCardTap(1),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoCard(
                              'MAC Address',
                              _showMacAddress
                                  ? _macAddress ?? 'Not Available'
                                  : '*****',
                              Icons.devices,
                              isSelected: _selectedIndex == 2,
                              onTap: () => _handleCardTap(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoCard(
                              'WiFi Network',
                              _showWifiPassword
                                  ? _wifiPassword ?? 'Not Available'
                                  : '*****',
                              Icons.wifi_tethering,
                              isSelected: _selectedIndex == 3,
                              onTap: () => _handleCardTap(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildInfoCard(
                              'Room Service',
                              '24/7 Available',
                              Icons.room_service,
                              isSelected: _selectedIndex == 4,
                              onTap: () => _handleCardTap(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String content, IconData icon,
      {VoidCallback? onTap, bool isSelected = false}) {
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: GestureDetector(
        onTap: () {
          if (!_isDialogOpen) {
            onTap?.call();
          }
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : AppColors.surface.withOpacity(0.1),
                isSelected
                    ? AppColors.accent.withOpacity(0.2)
                    : AppColors.surface.withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.primary.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: isSelected ? 8 : 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.2)
                        : AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? AppColors.accent : AppColors.primary,
                    size: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.primary : Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? Colors.white : Colors.white70,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _launchPhoneCall(String phoneNumber) async {
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }
}
