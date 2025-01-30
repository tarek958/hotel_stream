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

  final List<String> _welcomeMessages = [
    'Welcome to our Hotel',
    'Bienvenue à notre Hôtel',
    'مرحبا بكم في فندقنا',
  ];

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _updateDateTime();
    _startWelcomeAnimation();
    _initializeVideo();

    // Update time every second
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateDateTime();
    });

    // Initialize hotel info
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<HotelProvider>().loadHotelInfo('your_hotel_id');
      }
    });
  }

  void _updateDateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm:ss').format(DateTime.now());
        _currentDate = DateFormat('EEEE, d MMMM y').format(DateTime.now());
      });
    }
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
    super.dispose();
  }

  void _cleanupControllers() {
    _videoController?.dispose();
    _chewieController?.dispose();
    _videoController = null;
    _chewieController = null;
  }

  Future<void> _initializeVideo() async {
    if (_isDisposed) return;

    final publicityProvider =
        Provider.of<PublicityProvider>(context, listen: false);
    try {
      await publicityProvider.loadVideos();
      if (mounted && publicityProvider.videos.isNotEmpty) {
        await _setupVideoPlayer();
      }
    } catch (e) {
      // Silently handle error, UI will show appropriate state
    }
  }

  Future<void> _setupVideoPlayer() async {
    if (_isDisposed) return;

    final publicityProvider =
        Provider.of<PublicityProvider>(context, listen: false);
    final videoPath = await publicityProvider.getCurrentVideoPath();

    if (videoPath == null) return;

    _cleanupControllers();

    try {
      _videoController = VideoPlayerController.file(File(videoPath));
      await _videoController!.initialize();

      if (_isDisposed) {
        _videoController?.dispose();
        return;
      }

      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController!,
          autoPlay: true,
          looping: publicityProvider.videos.length == 1,
          aspectRatio: 16 / 9,
          showControls: false,
          showOptions: false,
        );

        // Listen for video completion
        _videoController!.addListener(_onVideoProgress);
      });
    } catch (e) {
      if (!_isDisposed) {
        setState(() {
          _cleanupControllers();
        });
      }
    }
  }

  void _onVideoProgress() {
    if (_videoController == null || _isDisposed) return;

    // Check if video has ended
    if (_videoController!.value.position >= _videoController!.value.duration) {
      final publicityProvider =
          Provider.of<PublicityProvider>(context, listen: false);

      if (publicityProvider.videos.length > 1) {
        // Move to next video if there are multiple videos
        publicityProvider.nextVideo();
        _setupVideoPlayer();
      }
    }
  }

  void pauseVideo() {
    _videoController?.pause();
  }

  void resumeVideo() {
    _videoController?.play();
  }

  void _navigateToChannels() {
    pauseVideo();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChannelsScreen(),
      ),
    ).then((_) {
      resumeVideo();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Background or Gradient Background
          Consumer<PublicityProvider>(
            builder: (context, publicityProvider, child) {
              if (_chewieController != null) {
                return Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Chewie(
                      controller: _chewieController!,
                    ),
                  ),
                );
              }

              // Fallback gradient background when no video is available
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
                                        color:
                                            AppColors.primary.withOpacity(0.5),
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

                            // Welcome Message
                            Expanded(
                              child: Center(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 800),
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
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 22,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Channels Button
                            Material(
                              color: Colors.transparent,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(30),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary.withOpacity(0.7),
                                          AppColors.accent.withOpacity(0.7),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.2),
                                      ),
                                    ),
                                    child: InkWell(
                                      onTap: _navigateToChannels,
                                      borderRadius: BorderRadius.circular(30),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 16,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.tv,
                                              color:
                                                  Colors.white.withOpacity(0.9),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Channels',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.9),
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom date and time section (only in landscape)
              if (isLandscape)
                SafeArea(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 24),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.3),
                                AppColors.accent.withOpacity(0.3),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.2),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.1),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Time
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _currentTime,
                                      style: TextStyle(
                                        color: AppColors.text,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 2,
                                        fontFamily: 'Digital',
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 20),

                              // Date
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _currentDate,
                                      style: TextStyle(
                                        color: AppColors.text,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 20),

                              // Temperature (you can add actual temperature data later)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.thermostat,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '24°C', // You can make this dynamic later
                                      style: TextStyle(
                                        color: AppColors.text,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w500,
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
            ],
          ),
        ],
      ),
    );
  }
}
