import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/weather_provider.dart';
import '../providers/theme_provider.dart';
import '../constants/app_constants.dart';
import '../widgets/tv_focusable.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart' as gen;
import 'dart:convert';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _weatherData;
  String? _error;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fetchWeatherData();
    RawKeyboard.instance.addListener(_handleNavigationKeyPress);

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    print('WeatherScreen: disposing resources');
    _controller.dispose();
    RawKeyboard.instance.removeListener(_handleNavigationKeyPress);
    super.dispose();
  }

  Future<void> _fetchWeatherData() async {
    try {
      final response = await NetworkAssetBundle(Uri.parse(
              'https://api.openweathermap.org/data/2.5/weather?lat=36.41&lon=10.66&appid=69e30561fe53310426dff165d05934bf'))
          .load('');
      final data = String.fromCharCodes(response.buffer.asUint8List());
      print('Weather API Response: $data'); // Debug log

      final decodedData = json.decode(data);
      print('Decoded Weather Data: $decodedData'); // Debug log

      setState(() {
        _weatherData = Map<String, dynamic>.from(decodedData);
        _isLoading = false;
        _controller.forward(); // Start the fade animation
      });
    } catch (e) {
      print('Error fetching weather data: $e'); // Debug log
      setState(() {
        _error = 'Failed to load weather data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  KeyEventResult _handleNavigationKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.goBack) {
        print('WeatherScreen: back key pressed - disabled');
        // Back key is disabled for screen navigation
        print(
            'Back key is disabled - only back button works to return to home');
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  String _getWeatherIcon(String iconCode) {
    return 'https://openweathermap.org/img/wn/$iconCode@2x.png';
  }

  String _formatTemperature(dynamic temp) {
    if (temp is int) {
      return '${(temp - 273.15).round()}°C';
    } else if (temp is double) {
      return '${(temp - 273.15).round()}°C';
    }
    return 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = gen.AppLocalizations.of(context)!;
    final weatherCode = _weatherData?['weather']?[0]?['id'] ?? 800;
    final isDay =
        _weatherData?['weather']?[0]?['icon']?.toString().endsWith('d') ?? true;

    print('Current Weather Data: $_weatherData'); // Debug log
    print('Weather Code: $weatherCode'); // Debug log
    print('Is Day: $isDay'); // Debug log

    return WillPopScope(
      onWillPop: () async {
        print('Back navigation is disabled - only back button works');
        // Prevent default back navigation
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Animated Sky Background
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _getSkyColor(weatherCode, isDay),
                        _getSkyColor(weatherCode, isDay).withOpacity(0.8),
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: CustomPaint(
                      painter: SkyPainter(
                        weatherCode: weatherCode,
                        isDay: isDay,
                        animation: _controller.value,
                      ),
                    ),
                  ),
                );
              },
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                    ),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Row(
                          children: [
                            TVFocusable(
                              id: 'back_button',
                              onSelect: () {
                                print(
                                    'WeatherScreen: back button pressed, navigating to home');
                                // Navigate to the home screen
                                Navigator.pushNamedAndRemoveUntil(
                                    context, '/home', (route) => false);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_back,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              l10n.weather,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Weather Content
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : _error != null
                            ? Center(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              )
                            : FadeTransition(
                                opacity: _fadeAnimation,
                                child: Row(
                                  children: [
                                    // Left Side - Main Weather Info
                                    Expanded(
                                      flex: 3,
                                      child: Container(
                                        margin: const EdgeInsets.all(12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white.withOpacity(0.1),
                                              Colors.white.withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.2),
                                            width: 1,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.black.withOpacity(0.2),
                                              blurRadius: 20,
                                              spreadRadius: 5,
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // Location
                                            Text(
                                              _weatherData?['name'] ??
                                                  'Location Unknown',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.7),
                                                fontSize: 24,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            // Weather Icon with Animation
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.1),
                                                shape: BoxShape.circle,
                                              ),
                                              child: _weatherData?['weather']
                                                          ?[0]?['icon'] !=
                                                      null
                                                  ? Image.network(
                                                      _getWeatherIcon(
                                                          _weatherData![
                                                                  'weather'][0]
                                                              ['icon']),
                                                      width: 100,
                                                      height: 100,
                                                      errorBuilder: (context,
                                                          error, stackTrace) {
                                                        print(
                                                            'Error loading weather icon: $error');
                                                        return const Icon(
                                                          Icons.wb_sunny,
                                                          size: 100,
                                                          color: Colors.white,
                                                        );
                                                      },
                                                    )
                                                  : const Icon(
                                                      Icons.wb_sunny,
                                                      size: 100,
                                                      color: Colors.white,
                                                    ),
                                            ),
                                            const SizedBox(height: 12),
                                            // Temperature
                                            Text(
                                              _weatherData?['main']?['temp'] !=
                                                      null
                                                  ? _formatTemperature(
                                                      _weatherData!['main']
                                                          ['temp'])
                                                  : 'N/A',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 64,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            // Description
                                            Text(
                                              _weatherData?['weather']?[0]
                                                          ?['description']
                                                      ?.toString()
                                                      .toUpperCase() ??
                                                  'WEATHER UNKNOWN',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.7),
                                                fontSize: 20,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Right Side - Weather Details
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                            right: 12, top: 12, bottom: 12),
                                        child: GridView.count(
                                          shrinkWrap: true,
                                          physics:
                                              const NeverScrollableScrollPhysics(),
                                          crossAxisCount: 2,
                                          mainAxisSpacing: 12,
                                          crossAxisSpacing: 12,
                                          childAspectRatio: 2.0,
                                          children: [
                                            _buildWeatherCard(
                                              'Feels Like',
                                              _weatherData?['main']
                                                          ?['feels_like'] !=
                                                      null
                                                  ? _formatTemperature(
                                                      _weatherData!['main']
                                                          ['feels_like'])
                                                  : 'N/A',
                                              Icons.thermostat,
                                            ),
                                            _buildWeatherCard(
                                              'Humidity',
                                              '${_weatherData?['main']?['humidity'] ?? 'N/A'}%',
                                              Icons.water_drop,
                                            ),
                                            _buildWeatherCard(
                                              'Wind Speed',
                                              '${_weatherData?['wind']?['speed'] ?? 'N/A'} m/s',
                                              Icons.air,
                                            ),
                                            _buildWeatherCard(
                                              'Pressure',
                                              '${_weatherData?['main']?['pressure'] ?? 'N/A'} hPa',
                                              Icons.speed,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSkyColor(int weatherCode, bool isDay) {
    if (weatherCode >= 200 && weatherCode < 300) {
      return const Color(0xFF2C3E50); // Thunderstorm
    } else if (weatherCode >= 300 && weatherCode < 400) {
      return const Color(0xFF34495E); // Drizzle
    } else if (weatherCode >= 500 && weatherCode < 600) {
      return const Color(0xFF2C3E50); // Rain
    } else if (weatherCode >= 600 && weatherCode < 700) {
      return const Color(0xFFECF0F1); // Snow
    } else if (weatherCode >= 700 && weatherCode < 800) {
      return const Color(0xFF95A5A6); // Atmosphere
    } else if (weatherCode == 800) {
      return isDay ? const Color(0xFF3498DB) : const Color(0xFF2C3E50); // Clear
    } else if (weatherCode > 800) {
      return const Color(0xFF7F8C8D); // Clouds
    }
    return const Color(0xFF3498DB); // Default
  }

  Widget _buildWeatherCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SkyPainter extends CustomPainter {
  final int weatherCode;
  final bool isDay;
  final double animation;

  SkyPainter({
    required this.weatherCode,
    required this.isDay,
    required this.animation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.1);

    if (weatherCode >= 200 && weatherCode < 300) {
      // Draw lightning
      final path = Path()
        ..moveTo(size.width * 0.3, size.height * 0.2)
        ..lineTo(size.width * 0.4, size.height * 0.3)
        ..lineTo(size.width * 0.35, size.height * 0.4)
        ..lineTo(size.width * 0.45, size.height * 0.5)
        ..lineTo(size.width * 0.4, size.height * 0.6)
        ..lineTo(size.width * 0.5, size.height * 0.7);
      canvas.drawPath(path, paint);
    } else if (weatherCode >= 500 && weatherCode < 600) {
      // Draw rain
      for (var i = 0; i < 20; i++) {
        final x = size.width * (0.2 + (i % 5) * 0.15);
        final y = size.height * (0.3 + (i ~/ 5) * 0.15 + animation);
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + 20),
          paint,
        );
      }
    } else if (weatherCode >= 600 && weatherCode < 700) {
      // Draw snow
      for (var i = 0; i < 30; i++) {
        final x = size.width * (0.1 + (i % 6) * 0.15);
        final y = size.height * (0.2 + (i ~/ 6) * 0.15 + animation);
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    } else if (weatherCode > 800) {
      // Draw clouds
      for (var i = 0; i < 5; i++) {
        final x = size.width * (0.2 + i * 0.15);
        final y = size.height * (0.3 + animation);
        canvas.drawCircle(Offset(x, y), 30, paint);
      }
    }
  }

  @override
  bool shouldRepaint(SkyPainter oldDelegate) {
    return oldDelegate.weatherCode != weatherCode ||
        oldDelegate.isDay != isDay ||
        oldDelegate.animation != animation;
  }
}
