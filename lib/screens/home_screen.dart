import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import '../constants/app_constants.dart';
import '../providers/hotel_provider.dart';
import 'channels_screen.dart';
import 'package:intl/intl.dart';
import '../providers/publicity_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import '../widgets/language_selector.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/news_ticker.dart';
import '../l10n/app_localizations.dart';
import '../providers/connectivity_provider.dart';
import 'info_screen.dart';
import 'weather_screen.dart';
import 'language_screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart' as gen;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _isDisposed = false;
  String _currentTime = '';
  String _currentDate = '';
  int _welcomeIndex = 0;
  Timer? _welcomeTimer;
  bool _isNavbarFocused = false;
  int _selectedIndex = 0;
  late Timer _timer;
  late String _currentDateTime;

  final List<String> _welcomeMessages = [
    'Welcome to our Hotel', // English
    'Bienvenue à notre Hôtel', // French
    'مرحبا بكم في فندقنا', // Arabic
    'Bienvenidos a nuestro Hotel', // Spanish
    'Willkommen in unserem Hotel', // German
    'Benvenuti nel nostro Hotel', // Italian
    'Добро пожаловать в наш отель', // Russian
    'Bem-vindo ao nosso Hotel', // Portuguese
    '欢迎来到我们的酒店', // Chinese (Simplified)
    'ホテルへようこそ', // Japanese
    '호텔에 오신 것을 환영합니다', // Korean
    'ยินดีต้อนรับสู่โรงแรมของเรา', // Thai
    'Selamat datang di Hotel kami', // Indonesian
    'Welkom in ons Hotel', // Dutch
    'Välkommen till vårt hotell', // Swedish
    'Tervetuloa hotelliimme', // Finnish
    'Velkommen til vårt hotell', // Norwegian
    'Velkommen til vores hotel', // Danish
    'Καλώς ήρθατε στο ξενοδοχείο μας', // Greek
    'Hotelimize hoş geldiniz', // Turkish
    'Vítejte v našem hotelu', // Czech
    'Witamy w naszym hotelu', // Polish
    'Üdvözöljük szállodánkban', // Hungarian
    'Bine ați venit la hotelul nostru', // Romanian
    'Vitajte v našom hoteli', // Slovak
    'Dobrodošli v naš hotel', // Slovenian
    'Tere tulemast meie hotelli', // Estonian
    'Laipni lūdzam mūsu viesnīcā', // Latvian
    'Sveiki atvykę į mūsų viešbutį', // Lithuanian
  ];

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _updateDateTime();
    _startWelcomeAnimation();

    // Update time every second
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateDateTime();
    });

    // Initialize hotel info and publicity videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<HotelProvider>().loadHotelInfo('your_hotel_id');
          // Delay video initialization to ensure UI is ready
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _initializeVideo();
            }
          });
        } catch (e) {
          print('Error in initState: $e');
        }
      }
    });

    // Set initial focus to navbar and select Channels button
    setState(() {
      _isNavbarFocused = true;
      _selectedIndex = 0;
    });
  }

  void _updateDateTime() {
    final now = DateTime.now();
    final dateFormat = DateFormat('EEEE, MMMM d, y');
    final timeFormat = DateFormat('HH:mm:ss');
    setState(() {
      _currentDateTime = '${dateFormat.format(now)} ${timeFormat.format(now)}';
    });
  }

  void _startWelcomeAnimation() {
    _welcomeTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        setState(() {
          _welcomeIndex = (_welcomeIndex + 1) % _welcomeMessages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _cleanupControllers();
    _isDisposed = true;
    _welcomeTimer?.cancel();
    _timer.cancel();
    super.dispose();
  }

  void _cleanupControllers() {
    print('Cleaning up video controllers');

    // First pause any ongoing playback
    if (_videoController != null && _videoController!.value.isPlaying) {
      _videoController!.pause();
    }

    // Remove listeners before disposal to prevent callback errors
    if (_videoController != null) {
      try {
        _videoController!.removeListener(_onVideoProgress);
      } catch (e) {
        print('Error removing video controller listener: $e');
      }
    }

    // Dispose Chewie controller first
    if (_chewieController != null) {
      try {
        _chewieController!.dispose();
      } catch (e) {
        print('Error disposing Chewie controller: $e');
      }
      _chewieController = null;
    }

    // Then dispose video controller
    if (_videoController != null) {
      try {
        _videoController!.dispose();
      } catch (e) {
        print('Error disposing video controller: $e');
      }
      _videoController = null;
    }

    // Ensure state is updated
    if (mounted) {
      setState(() {
        // Controllers are now null, UI will reflect this
      });
    }
  }

  Future<void> _initializeVideo() async {
    // Check if the widget is still mounted before doing anything
    if (_isDisposed || !mounted) return;

    try {
      // First, clean up any existing controllers
      _cleanupControllers();

      // Try to load videos from PublicityProvider
      final publicityProvider =
          Provider.of<PublicityProvider>(context, listen: false);

      // Wrap publicityProvider calls in mounted checks
      if (!mounted) return;

      print('Loading publicity videos...');
      await publicityProvider.loadVideos();

      // Check if widget is still mounted after async operation
      if (!mounted || _isDisposed) return;

      print(
          'Publicity videos loaded: ${publicityProvider.videos.length} videos');
      publicityProvider.videos.forEach((video) {
        print('Video available: ${video.id} - URL: ${video.videoUrl}');
      });

      // Check if we have videos
      final currentVideo = publicityProvider.currentVideo;
      if (currentVideo != null && currentVideo.videoUrl.isNotEmpty) {
        // Use the video URL from PublicityProvider
        print('Using publicity video: ${currentVideo.videoUrl}');
        // Careful with setState calls after async operations
        if (mounted) {
          _initializeVideoWithUrl(currentVideo.videoUrl);
        }
      } else {
        // Show error state if no videos available
        print('No publicity videos available');
        if (mounted) {
          setState(() {
            // Update UI to show no videos available
          });
        }
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (!_isDisposed && mounted) {
        _retryVideoInitialization();
      }
    }
  }

  Future<void> _initializeVideoWithUrl(String videoUrl) async {
    if (_isDisposed || !mounted) return;

    try {
      print('Creating video controller for URL: $videoUrl');

      // For MP4 files, don't use streaming options
      final isMP4 = videoUrl.toLowerCase().endsWith('.mp4');

      _videoController = VideoPlayerController.network(
        videoUrl,
        httpHeaders: const {
          'User-Agent': 'HotelStream/1.0',
        },
        videoPlayerOptions: isMP4
            ? null
            : VideoPlayerOptions(
                mixWithOthers: true,
                allowBackgroundPlayback: true,
              ),
      );

      // Add error listener with mounted check
      _videoController!.addListener(() {
        if (_videoController?.value.hasError == true &&
            mounted &&
            !_isDisposed) {
          print(
              'Video player error: ${_videoController!.value.errorDescription}');
          _retryVideoInitialization();
        }
      });

      print('Initializing video player...');
      // Set a timeout for initialization
      bool initCompleted = false;
      Timer? timeoutTimer;

      timeoutTimer = Timer(const Duration(seconds: 10), () {
        if (!initCompleted && mounted && !_isDisposed) {
          print('Video initialization timeout');
          _videoController?.dispose();
          _videoController = null;
          _retryVideoInitialization();
        }
      });

      await _videoController!.initialize();
      initCompleted = true;
      timeoutTimer?.cancel();

      // Check mounted state again after async operation
      if (_isDisposed || !mounted) {
        _videoController?.dispose();
        return;
      }

      await _videoController!.setLooping(true);

      print(
          'Video initialized with duration: ${_videoController!.value.duration}');

      if (_isDisposed || !mounted) {
        _videoController?.dispose();
        return;
      }

      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: true,
          aspectRatio: 16 / 9,
          showControls: false,
          showOptions: false,
          allowFullScreen: false,
          allowMuting: false,
          allowPlaybackSpeedChanging: false,
          errorBuilder: (context, errorMessage) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 42),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $errorMessage',
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _retryVideoInitialization,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          },
        );

        // Listen for video completion with mounted check
        _videoController!.addListener(_onVideoProgress);
      });

      // Start playing
      print('Starting video playback');
      if (mounted && !_isDisposed) {
        await _videoController!.play();
      }
    } catch (e) {
      print('Error initializing video with URL $videoUrl: $e');
      if (!_isDisposed && mounted) {
        _retryVideoInitialization();
      }
    }
  }

  void _onVideoProgress() {
    if (_videoController == null || _isDisposed || !mounted) return;

    // Check for errors
    if (_videoController!.value.hasError) {
      print('Video error: ${_videoController!.value.errorDescription}');
      _retryVideoInitialization();
      return;
    }

    // Check if video has ended
    if (_videoController!.value.position >= _videoController!.value.duration) {
      try {
        // Get next video from PublicityProvider
        final publicityProvider =
            Provider.of<PublicityProvider>(context, listen: false);
        if (publicityProvider.videos.isNotEmpty) {
          // Move to next video in the playlist
          publicityProvider.nextVideo();
          final currentVideo = publicityProvider.currentVideo;
          if (currentVideo != null &&
              currentVideo.videoUrl.isNotEmpty &&
              mounted) {
            print('Moving to next publicity video: ${currentVideo.videoUrl}');

            // Initialize with the next publicity video
            _initializeVideoWithUrl(currentVideo.videoUrl);
          } else if (mounted && !_isDisposed) {
            // If no valid videos in provider, just restart the current one
            _videoController!.seekTo(Duration.zero);
            _videoController!.play();
          }
        } else if (mounted && !_isDisposed) {
          // If no videos in provider, just restart the current one
          _videoController!.seekTo(Duration.zero);
          _videoController!.play();
        }
      } catch (e) {
        print('Error during video progress handling: $e');
        // If error occurs, safely restart current video
        if (mounted && !_isDisposed && _videoController != null) {
          _videoController!.seekTo(Duration.zero);
          _videoController!.play();
        }
      }
    }
  }

  void pauseVideo() {
    _videoController?.pause();
  }

  void resumeVideo() {
    _videoController?.play();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      print('Home screen key event: ${event.logicalKey}');
      print('Navbar focused: $_isNavbarFocused');
      print('Selected index: $_selectedIndex');

      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (!_isNavbarFocused) {
          setState(() {
            _isNavbarFocused = true;
            _selectedIndex = 0;
          });
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_isNavbarFocused) {
          setState(() {
            _isNavbarFocused = false;
            _selectedIndex = -1;
          });
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_isNavbarFocused && _selectedIndex > 0) {
          setState(() {
            _selectedIndex = (_selectedIndex - 1).clamp(0, 3);
          });
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_isNavbarFocused && _selectedIndex < 3) {
          setState(() {
            _selectedIndex = (_selectedIndex + 1).clamp(0, 3);
          });
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (_isNavbarFocused && _selectedIndex >= 0) {
          _handleNavItemTap(_selectedIndex);
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.goBack) {
        if (_isNavbarFocused) {
          setState(() {
            _isNavbarFocused = false;
            _selectedIndex = -1;
          });
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _reinitializeVideoOnReturn() {
    // A short delay ensures that returning navigation is complete
    // before initializing the video (avoids resource conflicts)
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && _videoController == null && _chewieController == null) {
          _initializeVideo();
        }
      });
    }
  }

  void _handleNavItemTap(int index) {
    if (!mounted) return;

    switch (index) {
      case 0: // Channels
        // Stop video and clean up controllers before navigation
        _cleanupControllers();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChannelsScreen()),
        ).then((_) => _reinitializeVideoOnReturn());
        break;
      case 1: // Info
        // Stop video and clean up controllers before navigation
        _cleanupControllers();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const InfoScreen()),
        ).then((_) => _reinitializeVideoOnReturn());
        break;
      case 2: // Weather
        // Stop video and clean up controllers before navigation
        _cleanupControllers();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const WeatherScreen()),
        ).then((_) => _reinitializeVideoOnReturn());
        break;
      case 3: // Language
        // Stop video and clean up controllers before navigation
        _cleanupControllers();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LanguageScreen()),
        ).then((_) => _reinitializeVideoOnReturn());
        break;
    }
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _isNavbarFocused && _selectedIndex == index;
    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      child: GestureDetector(
        onTap: () => _handleNavItemTap(index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withOpacity(0.3)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: isSelected ? 2 : 0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.text.withOpacity(0.7),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.text.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _retryVideoInitialization() {
    if (_isDisposed || !mounted) return;

    // Wait for 2 seconds before retrying
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isDisposed && mounted) {
        _initializeVideo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = gen.AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Focus(
      autofocus: true,
      onKey: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Video Background or Gradient Background
            Consumer<PublicityProvider>(
              builder: (context, publicityProvider, child) {
                final currentVideo = publicityProvider.currentVideo;

                if (_chewieController != null) {
                  return Stack(
                    children: [
                      // Video player
                      Positioned.fill(
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Chewie(
                            controller: _chewieController!,
                          ),
                        ),
                      ),

                      // Video info overlay (only visible if it's a publicity video)
                      if (currentVideo != null &&
                          publicityProvider.isInitialized)
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.black.withOpacity(0.7),
                            ),
                            child: Text(
                              'Playing video: ${currentVideo.id}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }

                // Loading or error state
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surface,
                        AppColors.surface.withOpacity(0.8),
                        AppColors.primary.withOpacity(0.1),
                      ],
                    ),
                  ),
                  child: Center(
                    child: publicityProvider.isLoading
                        ? CircularProgressIndicator(color: AppColors.primary)
                        : const Text('Loading video...',
                            style: TextStyle(color: Colors.white)),
                  ),
                );
              },
            ),

            // Gradient overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Navigation Bar
                SafeArea(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Logo and Hotel Name
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withOpacity(0.5),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/ic_new-playstore.png',
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  ShaderMask(
                                    shaderCallback: (bounds) => LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.accent,
                                      ],
                                    ).createShader(bounds),
                                    child: const Text(
                                      'ONE RESORT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              // Welcome Message and DateTime
                              Expanded(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Welcome Message
                                    Expanded(
                                      child: Center(
                                        child: AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 800),
                                          transitionBuilder: (Widget child,
                                              Animation<double> animation) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: const Offset(0.0, 0.2),
                                                  end: Offset.zero,
                                                ).animate(animation),
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: Text(
                                            _welcomeMessages[_welcomeIndex],
                                            key: ValueKey<int>(_welcomeIndex),
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(0.9),
                                              fontSize: 22,
                                              fontWeight: FontWeight.w500,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Date and Time
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: AppColors.primary
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _currentDateTime
                                                .split(' ')
                                                .last, // Time part
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(0.9),
                                              fontSize: 18,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            _currentDateTime
                                                .split(' ')
                                                .sublist(0, 3)
                                                .join(' '), // Date part
                                            style: TextStyle(
                                              color:
                                                  Colors.white.withOpacity(0.7),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom Navigation Bar
                SafeArea(
                  bottom: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, -2),
                        ),
                      ],
                      border: Border(
                        top: BorderSide(
                          color: AppColors.primary.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildNavItem(0, Icons.tv, l10n.channels),
                        _buildNavItem(1, Icons.info_outline, l10n.info),
                        _buildNavItem(2, Icons.wb_sunny, l10n.weather),
                        _buildNavItem(3, Icons.language, l10n.language),
                      ],
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
}
