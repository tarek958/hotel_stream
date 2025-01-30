import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../constants/app_constants.dart';
import '../widgets/language_selector.dart';
import '../widgets/tv_focusable.dart';
import '../l10n/app_localizations.dart';
import '../providers/hotel_provider.dart';
import '../providers/connectivity_provider.dart';
import '../models/channel_model.dart';
import '../services/tv_focus_service.dart';
import '../providers/language_provider.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen>
    with SingleTickerProviderStateMixin {
  Channel? _selectedChannel;
  String _selectedCategory = 'All';
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _error;
  bool _isFullScreen = false;
  bool _isDisposed = false;
  bool _showChannelList = false;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  List<Channel> _filteredChannels = [];
  bool _isCategoryFocused = false;
  bool _isLanguageFocused = false;

  void _showConnectionError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Connection error. Please check your internet connection.',
                style: TextStyle(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                context.read<HotelProvider>().loadChannelsAndCategories();
              },
              child: const Text(
                'RETRY',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    ));

    // Initialize focus handling
    _initializeFocus();

    // Load channels when screen initializes
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    try {
      await hotelProvider.loadChannelsAndCategories();
      if (hotelProvider.error == 'server_error' && mounted) {
        _showConnectionError(context);
      }
    } catch (e) {
      if (mounted) {
        _showConnectionError(context);
      }
    }
    if (mounted) {
      setState(() {
        _selectedCategory = 'All';
        _filteredChannels = hotelProvider.channels;
      });
    }
  }

  List<Channel> _getFilteredChannels() {
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    if (_selectedCategory == 'All') {
      return hotelProvider.channels;
    }
    // Find the category ID for the selected category name
    final selectedCategoryId = hotelProvider.categories
        .firstWhere((cat) => cat.name == _selectedCategory)
        .id;
    return hotelProvider.channels
        .where((channel) => channel.categ == selectedCategoryId)
        .toList();
  }

  void _filterChannels() {
    if (!mounted) return;
    setState(() {
      _filteredChannels = _getFilteredChannels();
      // Re-initialize focus for the new filtered channels
      _initializeFocusForChannels();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _filterChannels();
    });
  }

  void _initializeFocusForChannels() {
    final service = TVFocusService();
    // Unregister old channel focus nodes
    for (final channel in _filteredChannels) {
      service.unregisterFocusable('channel_${channel.id}');
    }
    // Register new channel focus nodes
    for (final channel in _filteredChannels) {
      final focusNode = service.registerFocusable('channel_${channel.id}');
      focusNode.addListener(() {
        if (focusNode.hasFocus && (_isCategoryFocused || _isLanguageFocused)) {
          setState(() {
            _isCategoryFocused = false;
            _isLanguageFocused = false;
          });
        }
      });
    }
  }

  void _initializeFocus() {
    final service = TVFocusService();

    // Add focus listeners to language items
    final languageProvider =
        Provider.of<LanguageProvider>(context, listen: false);
    for (final locale in LanguageProvider.supportedLocales.values) {
      final focusNode =
          service.registerFocusable('language_${locale.languageCode}');
      focusNode.addListener(() {
        if (focusNode.hasFocus && !_isLanguageFocused) {
          setState(() {
            _isLanguageFocused = true;
            _isCategoryFocused = false;
          });
        }
      });
    }

    // Add focus listeners to category items
    final categories = <String>[
      'All',
      ...Provider.of<HotelProvider>(context, listen: false)
          .categories
          .map((cat) => cat.name)
    ];
    for (final category in categories) {
      final focusNode = service.registerFocusable('category_$category');
      focusNode.addListener(() {
        if (focusNode.hasFocus && !_isCategoryFocused) {
          setState(() {
            _isCategoryFocused = true;
            _isLanguageFocused = false;
          });
        }
      });
    }

    // Initialize channel focus nodes
    _initializeFocusForChannels();
  }

  @override
  void dispose() {
    if (_chewieController != null) {
      _chewieController!.removeListener(_handleFullscreenChange);
    }
    _slideController.dispose();
    _cleanupControllers();
    _isDisposed = true;
    super.dispose();
  }

  void _toggleChannelList() {
    if (!_isDisposed) {
      setState(() {
        _showChannelList = !_showChannelList;
      });
      if (_showChannelList) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    }
  }

  void _cleanupControllers() {
    if (!_isDisposed) {
      if (_videoController != null) {
        _videoController!.dispose();
        _videoController = null;
      }
      if (_chewieController != null) {
        _chewieController!.dispose();
        _chewieController = null;
      }
    }
  }

  void _selectChannel(Channel channel) {
    if (_selectedChannel == channel) {
      // If the same channel is clicked again, go to fullscreen
      if (_chewieController != null && _error == null && !_isDisposed) {
        setState(() {
          _isFullScreen = true;
        });
        _chewieController!.enterFullScreen();
      }
      return;
    }

    setState(() {
      _selectedChannel = channel;
      _error = null;
    });

    final streamUrl = channel.streamUrl;
    if (streamUrl != null && streamUrl.isNotEmpty) {
      _cleanupControllers();
      try {
        _initializePlayer(streamUrl);
      } catch (e) {
        if (!_isDisposed) {
          setState(() {
            _error = AppLocalizations.of(context)!.channelOffline;
          });
        }
      }
    }
  }

  void _initializePlayer(String videoUrl) {
    if (_isDisposed) return;

    // Check network connectivity first
    final connectivityProvider =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (!connectivityProvider.isOnline) {
      setState(() {
        _error = AppLocalizations.of(context)!.noInternetConnection;
      });
      return;
    }

    try {
      // Create and initialize the video player controller
      _videoController = VideoPlayerController.network(
        videoUrl,
        httpHeaders: const {
          'User-Agent': 'HotelStream/1.0',
        },
      );

      _videoController!.initialize().then((_) {
        if (_isDisposed) {
          _videoController?.dispose();
          return;
        }

        setState(() {
          _chewieController = ChewieController(
            videoPlayerController: _videoController!,
            autoPlay: true,
            looping: true,
            aspectRatio: 16 / 9,
            errorBuilder: (context, errorMessage) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.primary,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? AppLocalizations.of(context)!.channelOffline,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _retryPlayback,
                      icon: const Icon(Icons.refresh),
                      label: Text(AppLocalizations.of(context)!.retry),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            fullScreenByDefault: _isFullScreen,
            allowFullScreen: true,
            allowMuting: true,
            showOptions: false,
            showControlsOnInitialize: false,
            customControls: const MaterialDesktopControls(),
            deviceOrientationsAfterFullScreen: const [
              DeviceOrientation.portraitUp
            ],
            deviceOrientationsOnEnterFullScreen: const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ],
          );

          // Listen to fullscreen changes
          _chewieController!.addListener(_handleFullscreenChange);
        });
      }).catchError((error) {
        if (_isDisposed) return;

        setState(() {
          _error = _getErrorMessage(error);
        });
      });
    } catch (e) {
      if (_isDisposed) return;

      setState(() {
        _error = _getErrorMessage(e);
      });
    }
  }

  void _handleFullscreenChange() {
    if (!_isDisposed && _chewieController != null) {
      final isFullScreen = _chewieController!.isFullScreen;
      if (isFullScreen != _isFullScreen) {
        setState(() {
          _isFullScreen = isFullScreen;
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('UnknownHostException')) {
      return AppLocalizations.of(context)!.noInternetConnection;
    } else if (error.toString().contains('404')) {
      return AppLocalizations.of(context)!.channelNotFound;
    } else if (error.toString().contains('403')) {
      return AppLocalizations.of(context)!.accessDenied;
    }
    return AppLocalizations.of(context)!.channelOffline;
  }

  void _retryPlayback() {
    if (_isDisposed) return;

    if (_selectedChannel != null) {
      final streamUrl = _selectedChannel!.streamUrl;
      if (streamUrl != null && streamUrl.isNotEmpty) {
        _cleanupControllers();
        _initializePlayer(streamUrl);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hotelProvider = Provider.of<HotelProvider>(context);
    final isOffline = hotelProvider.isOffline;
    final error = hotelProvider.error;
    final isLargeScreen = MediaQuery.of(context).size.width > 900;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final useHorizontalLayout = isLargeScreen || isLandscape;

    return Scaffold(
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
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.arrow_back),
                                  color: AppColors.primary,
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Title with gradient
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.accent,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              AppLocalizations.of(context)!.channels,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Category filter
                          Expanded(
                            child: _buildCategoryFilter(),
                          ),
                          // Language selector
                          const SizedBox(width: 16),
                          const LanguageSelector(),
                          const SizedBox(width: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Content
              Expanded(
                child: useHorizontalLayout
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Channels list
                          Container(
                            width: 400,
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: AppColors.primary.withOpacity(0.1),
                                ),
                              ),
                            ),
                            child: _buildChannelsList(),
                          ),
                          // Video player
                          Expanded(
                            child: _buildVideoPlayerSection(true),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildVideoPlayerSection(false),
                          Expanded(
                            child: _buildChannelsList(),
                          ),
                        ],
                      ),
              ),
            ],
          ),

          // Error notification banner
          if (error != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: error == 'server_error'
                          ? Colors.red.withOpacity(0.9)
                          : Colors.orange.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          error == 'server_error'
                              ? Icons.error_outline
                              : Icons.warning_amber_rounded,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                error == 'server_error'
                                    ? 'Server Error'
                                    : error == 'offline_no_cache'
                                        ? 'You are offline'
                                        : 'Connection Error',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                error == 'server_error'
                                    ? 'Unable to connect to the server'
                                    : error == 'offline_no_cache'
                                        ? 'Please check your internet connection'
                                        : 'Unable to load channel data',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () =>
                              hotelProvider.loadChannelsAndCategories(),
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          label: const Text(
                            'Retry',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final hotelProvider = Provider.of<HotelProvider>(context);
    final categories = [
      'All',
      ...hotelProvider.categories.map((cat) => cat.name)
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((categoryName) {
          final isSelected = _selectedCategory == categoryName;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TVFocusable(
              id: 'category_$categoryName',
              focusColor: AppColors.primary,
              onSelect: () => _onCategorySelected(categoryName),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.3),
                            AppColors.accent.withOpacity(0.3),
                          ],
                        )
                      : null,
                  color: isSelected ? null : AppColors.surface.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.5)
                        : AppColors.primary.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  categoryName,
                  style: TextStyle(
                    color: isSelected ? AppColors.primary : AppColors.text,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChannelsList() {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Consumer<HotelProvider>(
      builder: (context, hotelProvider, child) {
        if (hotelProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (hotelProvider.error != null) {
          return Center(
            child: Text(
              hotelProvider.error!,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
              ),
            ),
          );
        }

        if (_filteredChannels.isEmpty) {
          return Center(
            child: Text(
              AppLocalizations.of(context)!.noChannels,
              style: TextStyle(
                color: AppColors.text,
                fontSize: 16,
              ),
            ),
          );
        }

        if (isLandscape) {
          // Grid view for landscape mode
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _filteredChannels.length,
            itemBuilder: (context, index) {
              final channel = _filteredChannels[index];
              final isSelected = _selectedChannel?.id == channel.id;

              return TVFocusable(
                id: 'channel_${channel.id}',
                focusColor: AppColors.primary,
                onSelect: () => _selectChannel(channel),
                autofocus:
                    index == 0 && !_isCategoryFocused && !_isLanguageFocused,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isSelected
                              ? [
                                  AppColors.primary.withOpacity(0.3),
                                  AppColors.accent.withOpacity(0.3),
                                ]
                              : [
                                  AppColors.surface.withOpacity(0.3),
                                  AppColors.surface.withOpacity(0.1),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.5)
                              : AppColors.primary.withOpacity(0.1),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Channel Logo
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.1),
                                  ),
                                ),
                                child: ClipOval(
                                  child: channel.logoUrl != null &&
                                          channel.logoUrl.isNotEmpty
                                      ? Image.network(
                                          channel.logoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  _buildDefaultChannelIcon(),
                                        )
                                      : _buildDefaultChannelIcon(),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Channel Name
                            Expanded(
                              flex: 1,
                              child: Text(
                                channel.name,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.text,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Bottom row with category and live status
                            SizedBox(
                              height: 24,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (channel.isLive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.circle,
                                            color: Colors.white,
                                            size: 6,
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'LIVE',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (channel.isLive) const SizedBox(width: 6),
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            AppColors.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        channel.category,
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
              );
            },
          );
        }

        // List view for portrait mode
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _filteredChannels.length,
          itemBuilder: (context, index) {
            final channel = _filteredChannels[index];
            final isSelected = _selectedChannel?.id == channel.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TVFocusable(
                id: 'channel_${channel.id}',
                focusColor: AppColors.primary,
                onSelect: () => _selectChannel(channel),
                autofocus:
                    index == 0 && !_isCategoryFocused && !_isLanguageFocused,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.3),
                                  AppColors.accent.withOpacity(0.3),
                                ],
                              )
                            : null,
                        color: isSelected
                            ? null
                            : AppColors.surface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary.withOpacity(0.5)
                              : AppColors.primary.withOpacity(0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: ClipOval(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.1),
                                ),
                              ),
                              child: channel.logoUrl != null &&
                                      channel.logoUrl.isNotEmpty
                                  ? Image.network(
                                      channel.logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              _buildDefaultChannelIcon(),
                                    )
                                  : _buildDefaultChannelIcon(),
                            ),
                          ),
                          title: Text(
                            channel.name,
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.text
                                  : AppColors.text.withOpacity(0.9),
                              fontSize: 18,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              letterSpacing: 0.5,
                            ),
                          ),
                          subtitle: Text(
                            channel.category,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          trailing: channel.isLive
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        Icons.circle,
                                        color: Colors.white,
                                        size: 8,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'LIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDefaultChannelIcon() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.tv,
        color: AppColors.primary.withOpacity(0.7),
        size: 30,
      ),
    );
  }

  Widget _buildVideoPlayerSection(bool isLandscape) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_selectedChannel != null && _chewieController != null)
              GestureDetector(
                onDoubleTap: () {
                  if (_error == null &&
                      !_isDisposed &&
                      _chewieController != null) {
                    if (_isFullScreen) {
                      _chewieController!.exitFullScreen();
                    } else {
                      _chewieController!.enterFullScreen();
                    }
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Stack(
                        children: [
                          Chewie(controller: _chewieController!),
                          if (_error == null && !_isFullScreen)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.touch_app,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Double-tap for fullscreen',
                                      style: TextStyle(
                                        color: AppColors.text,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else if (_error != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.primary,
                            size: 42,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _retryPlayback,
                            icon: const Icon(Icons.refresh),
                            label: Text(AppLocalizations.of(context)!.retry),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.1),
                    ),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.tv_off,
                            color: AppColors.primary.withOpacity(0.5),
                            size: 60,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)!.selectChannel,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (_selectedChannel != null) ...[
              const SizedBox(height: 20),
              // Channel info with glass effect
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedChannel!.name,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                ),
                              ),
                              child: Text(
                                _selectedChannel!.category,
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _selectedChannel!.description,
                          style: TextStyle(
                            color: AppColors.text.withOpacity(0.8),
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
