import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:math';
import '../constants/app_constants.dart';
import '../widgets/language_selector.dart';
import '../widgets/tv_focusable.dart';
import '../widgets/fullscreen_channel_list.dart';
import '../widgets/news_ticker.dart';
import '../l10n/app_localizations.dart';
import '../providers/hotel_provider.dart';
import '../providers/connectivity_provider.dart';
import '../models/channel_model.dart';
import '../services/tv_focus_service.dart';
import '../providers/language_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart' as gen;

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
  late final TVFocusService _focusService;
  late final FocusNode _backButtonFocusNode;
  late final FocusNode _channelsFocusNode;
  final List<FocusNode> _categoryFocusNodes = [];
  int _focusedCategoryIndex = 0;
  int _selectedChannelIndex = 0;
  int _selectedCategoryIndex = 0;
  bool _isCategoryFocused = false;
  bool _isLanguageFocused = false;
  bool _isLoading = false;
  bool _isNavbarFocused = false;
  int _selectedNavbarItem = 0;
  final ScrollController _channelListScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Initialize focus service
    _focusService = TVFocusService();

    // Initialize back button and channels focus nodes
    _backButtonFocusNode = _focusService.registerFocusable('back_button');
    _channelsFocusNode = _focusService.registerFocusable('channels_list');

    // Add focus listeners to detect focus changes
    _backButtonFocusNode.addListener(() {
      if (_backButtonFocusNode.hasFocus) {
        print('Back button gained focus');
        setState(() {
          _isNavbarFocused = true;
          _selectedNavbarItem = 0;
          // Unfocus any category nodes to prevent dual focus
          for (var node in _categoryFocusNodes) {
            if (node.hasFocus) node.unfocus();
          }
        });
      }
    });

    _channelsFocusNode.addListener(() {
      if (_channelsFocusNode.hasFocus) {
        print('Channels list gained focus');
        setState(() {
          _isNavbarFocused = false;
          // Unfocus all category nodes
          for (var node in _categoryFocusNodes) {
            if (node.hasFocus) node.unfocus();
          }
        });
      }
    });

    // Initialize slide animation for channel list
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 50), // Super fast animation, almost instant
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0), // Start from already visible position
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.linear, // Use linear for fastest transition
    ));

    // IMPORTANT: Load channels first to get categories
    _loadChannelsAndInitializeFocus();
  }

  Future<void> _loadChannelsAndInitializeFocus() async {
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    try {
      await hotelProvider.loadChannelsAndCategories();

      // Once channels are loaded, initialize the categories and focus nodes
      final categories = ['All', ...hotelProvider.bouquets.map((b) => b.name)];

      // Clear any existing focus nodes
      _categoryFocusNodes.clear();

      print('Initializing ${categories.length} category focus nodes');

      // Create focus nodes for each category
      for (int i = 0; i < categories.length; i++) {
        final category = categories[i];
        final focusNode = _focusService
            .registerFocusable('category_${category.toLowerCase()}');
        _categoryFocusNodes.add(focusNode);

        // Add listener for category focus
        focusNode.addListener(() {
          if (focusNode.hasFocus) {
            print('Category ${categories[i]} gained focus');
            setState(() {
              // Unfocus other category nodes
              for (int j = 0; j < _categoryFocusNodes.length; j++) {
                if (j != i && _categoryFocusNodes[j].hasFocus) {
                  _categoryFocusNodes[j].unfocus();
                }
              }

              _selectedCategoryIndex = i;
              _selectedCategory = categories[i];
              _isNavbarFocused = true;
              _selectedNavbarItem = i + 1; // Back button is at index 0

              // Filter channels based on selected category
              _filterChannels();
            });
          }
        });
      }

      // Now set the initially selected category and focus state
      setState(() {
        _selectedCategory = 'All';
        _selectedCategoryIndex = 0;
        _selectedNavbarItem = 1;
        _filteredChannels = hotelProvider.channels;
      });
    } catch (e) {
      print('Error loading channels: $e');
      if (mounted) {
        _showConnectionError(context);
      }
    }
  }

  List<Channel> _getFilteredChannels() {
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    if (_selectedCategory == 'All') {
      return hotelProvider.channels;
    }
    // Find the bouquet ID for the selected category name
    final selectedBouquetId = hotelProvider.bouquets
        .firstWhere((bouquet) => bouquet.name == _selectedCategory)
        .id;
    return hotelProvider.channels
        .where((channel) => channel.categ == selectedBouquetId)
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

    // Add focus listener for language selector
    final languageFocusNode = service.registerFocusable('language_selector');
    languageFocusNode.addListener(() {
      if (languageFocusNode.hasFocus) {
        setState(() {
          _isLanguageFocused = true;
          _isCategoryFocused = false;
          _isNavbarFocused = true;
          _selectedNavbarItem = 2 +
              Provider.of<HotelProvider>(context, listen: false)
                  .bouquets
                  .length -
              1;
        });
      }
    });

    // Add focus listeners to category items
    final categories = <String>[
      'All',
      ...Provider.of<HotelProvider>(context, listen: false)
          .bouquets
          .map((bouquet) => bouquet.name),
    ];
    for (final category in categories) {
      final focusNode = service.registerFocusable('category_$category');
      focusNode.addListener(() {
        if (focusNode.hasFocus) {
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
    // Unregister focus nodes
    _focusService.unregisterFocusable('channels_back_button');
    _focusService.unregisterFocusable('channels_list');
    for (var node in _categoryFocusNodes) {
      node.dispose();
    }

    // Don't reset orientation when leaving the screen
    if (_chewieController != null) {
      _chewieController!.removeListener(_handleFullscreenChange);
    }
    _slideController.dispose();
    _channelListScrollController.dispose();
    _cleanupControllers();
    _isDisposed = true;
    super.dispose();
  }

  void _toggleChannelList() {
    setState(() {
      _showChannelList = !_showChannelList;
      if (_showChannelList) {
        // Skip animation and just show the list immediately
        _slideController.value = 1.0; // Set to end value directly

        // Reset selection to current channel
        final currentIndex =
            _filteredChannels.indexWhere((c) => c.id == _selectedChannel?.id);
        _selectedChannelIndex = currentIndex >= 0 ? currentIndex : 0;
        _ensureItemVisible(_selectedChannelIndex);
      } else {
        // Skip animation when hiding list too
        _slideController.value = 0.0; // Set to start value directly
      }
    });
  }

  void _cleanupControllers() {
    _chewieController?.dispose();
    _chewieController = null;
    _videoController?.dispose();
    _videoController = null;
  }

  void _onChannelSelected(Channel channel) {
    print(
        'Channel selected: ${channel.name}, Current channel: ${_selectedChannel?.name}');
    print(
        'Fullscreen state: $_isFullScreen, Show channel list: $_showChannelList');

    // Request focus for the channels list to prevent focus loss
    _channelsFocusNode.requestFocus();

    if (_selectedChannel?.id == channel.id) {
      // If the same channel is selected, only toggle channel list in fullscreen mode
      if (_isFullScreen) {
        _toggleChannelList();
      } else {
        // If not in fullscreen mode, enter fullscreen mode
        setState(() {
          _isFullScreen = true;
          _showChannelList = false; // Don't show channel list automatically
        });
      }
    } else {
      // Switch to new channel
      setState(() {
        _selectedChannel = channel;
        _error = null;
        _isLoading = true;
        // Keep the current video playing until the new one is ready
        if (_chewieController != null) {
          _chewieController!.pause();
        }
      });

      // Clean up existing controllers before initializing new ones
      _cleanupControllers();

      // Initialize new player
      _initializePlayer().then((_) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _error = 'Failed to load video stream. Please try again.';
            _isLoading = false;
          });
        }
      });
    }
  }

  Future<void> _initializePlayer() async {
    if (_selectedChannel == null) return;

    try {
      _videoController = VideoPlayerController.network(
        _selectedChannel!.streamUrl,
        httpHeaders: const {
          'User-Agent': 'HotelStream/1.0',
        },
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await _videoController!.initialize();

      // Set preferred quality - forcing highest quality available
      await _videoController!.setVolume(1.0);
      await _videoController!.setPlaybackSpeed(1.0);

      // Make sure video is properly sized for high resolution
      final videoWidth = max(1280, _videoController!.value.size.width);
      final videoHeight = max(720, _videoController!.value.size.height);
      final aspectRatio = videoWidth / videoHeight;

      if (!mounted) return;

      _chewieController = ChewieController(
        videoPlayerController: _videoController!,
        autoPlay: true,
        isLive: true,
        allowPlaybackSpeedChanging: false,
        allowMuting: false,
        showControls: false,
        showOptions: false,
        allowFullScreen: false,
        aspectRatio: aspectRatio,
        deviceOrientationsAfterFullScreen: [DeviceOrientation.landscapeLeft],
        zoomAndPan: true,
        customControls: const SizedBox.shrink(),
        placeholder: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );

      if (mounted) {
        setState(() {
          _error = null;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error initializing player: $e');
      if (mounted) {
        setState(() {
          if (e.toString().contains('Failed to connect')) {
            _error =
                'Failed to connect to stream. Please check your connection.';
          } else {
            _error = 'Failed to load video stream. Please try again.';
          }
          _isLoading = false;
        });
      }
      rethrow;
    }
  }

  Future<bool> _checkConnectivity() async {
    final connectivityProvider =
        Provider.of<ConnectivityProvider>(context, listen: false);
    return connectivityProvider.isOnline;
  }

  void _handleFullscreenChange() {
    if (!_isDisposed && _chewieController != null) {
      final isFullScreen = _chewieController!.isFullScreen;
      if (isFullScreen != _isFullScreen) {
        setState(() {
          _isFullScreen = isFullScreen;
          if (_isFullScreen) {
            _showChannelList =
                true; // Show channel list automatically in fullscreen
          } else {
            _showChannelList =
                false; // Hide channel list when exiting fullscreen
          }
        });
      }
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error.toString().contains('UnknownHostException')) {
      return gen.AppLocalizations.of(context)!.noInternetConnection;
    } else if (error.toString().contains('404')) {
      return gen.AppLocalizations.of(context)!.channelNotFound;
    } else if (error.toString().contains('403')) {
      return gen.AppLocalizations.of(context)!.accessDenied;
    }
    return gen.AppLocalizations.of(context)!.channelOffline;
  }

  void _retryPlayback() {
    if (_selectedChannel == null) return;

    setState(() {
      _error = null;
      _isLoading = true;
    });

    _cleanupControllers();
    _initializePlayer();
  }

  KeyEventResult _handleFullscreenKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      print('Handling fullscreen key press: ${event.logicalKey}');
      // Handle all key events within the channel screen
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (_isFullScreen) {
          if (_showChannelList) {
            // When channel list is showing, select the focused channel and hide the list
            _onChannelSelected(_filteredChannels[_selectedChannelIndex]);
            _toggleChannelList();
          } else {
            // Show channel list when OK button is pressed in fullscreen
            _toggleChannelList();
          }
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          _showChannelList) {
        setState(() => _selectedChannelIndex =
            (_selectedChannelIndex - 1).clamp(0, _filteredChannels.length - 1));
        _ensureItemVisible(_selectedChannelIndex);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          _showChannelList) {
        setState(() => _selectedChannelIndex =
            (_selectedChannelIndex + 1).clamp(0, _filteredChannels.length - 1));
        _ensureItemVisible(_selectedChannelIndex);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        print('Goback key pressed in _handleFullscreenKeyPress');
        print(
            'Current state - Fullscreen: $_isFullScreen, ShowChannelList: $_showChannelList');

        if (_isFullScreen) {
          print(
              'In fullscreen mode, handling goback key inside _handleFullscreenKeyPress');
          if (_showChannelList) {
            print('Channel list is showing, toggling it off');
            _toggleChannelList();
          } else {
            print('Exiting fullscreen mode but STAYING on channels screen');
            setState(() {
              _isFullScreen = false;
              _showChannelList = false;
            });
          }

          // Very important! Explicitly handle this key and prevent further processing
          print('Explicitly marking goBack key as handled');
          return KeyEventResult.handled;
        }
        // Let parent handlers manage non-fullscreen goBack
        print('Not in fullscreen, passing to parent handler');
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        // Add a space key handler to toggle channel list
        if (_isFullScreen) {
          _toggleChannelList();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.info) {
        // Add an info key handler to toggle channel list
        if (_isFullScreen) {
          _toggleChannelList();
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _ensureItemVisible(int index) {
    if (!_channelListScrollController.hasClients) return;

    final itemHeight = 180.0; // Approximate height of each grid item
    final viewportHeight =
        _channelListScrollController.position.viewportDimension;
    final currentScrollOffset = _channelListScrollController.offset;

    // Calculate the position of the item
    final itemOffset = (index ~/ 4) * itemHeight; // 4 items per row
    final itemEndOffset = itemOffset + itemHeight;

    // Calculate the center position of the viewport
    final viewportCenter = currentScrollOffset + (viewportHeight / 2);
    final itemCenter = itemOffset + (itemHeight / 2);

    // Calculate the target scroll position to center the item
    var targetOffset = itemCenter - (viewportHeight / 2);

    // Ensure we don't scroll past the top or bottom
    targetOffset = targetOffset.clamp(
        0.0, _channelListScrollController.position.maxScrollExtent);

    // Add some padding for the top rows to ensure they're fully visible
    if (index < 4) {
      // First row
      targetOffset = 0.0;
    } else if (index < 8) {
      // Second row
      targetOffset = itemHeight * 0.5;
    } else if (index < 12) {
      // Third row
      targetOffset = itemHeight * 1.5;
    } else {
      // For all other rows, center the item in the viewport
      targetOffset = itemCenter - (viewportHeight / 2);
    }

    // Animate to the target position
    _channelListScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
    );
  }

  void _showConnectionError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          gen.AppLocalizations.of(context)!.noInternetConnection,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = gen.AppLocalizations.of(context)!;
    final hotelProvider = Provider.of<HotelProvider>(context);
    final isOffline = hotelProvider.isOffline;
    final error = hotelProvider.error;

    return WillPopScope(
      onWillPop: () async {
        print('WillPopScope: intercepting back navigation');
        if (_isFullScreen) {
          print('WillPopScope: in fullscreen mode, preventing default back');
          setState(() {
            _isFullScreen = false;
            _showChannelList = false;
          });
          return false; // Prevent default back behavior
        }
        print('WillPopScope: navigating to home page');
        // Navigate to home page instead of using default back behavior
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
        return false; // Prevent default back navigation
      },
      child: Focus(
        onKey: (node, event) {
          print('Root Focus onKey: ${event.logicalKey}');

          // Only handle key down events
          if (!(event is RawKeyDownEvent)) return KeyEventResult.ignored;

          // When in fullscreen video mode, delegate to fullscreen handler first
          if (_isFullScreen) {
            print(
                'Root handler: in fullscreen mode, delegating to fullscreen handler');
            final result = _handleFullscreenKeyPress(event);
            if (result == KeyEventResult.handled) {
              print('Root handler: fullscreen handler processed the key');
              return KeyEventResult.handled;
            }
          }

          // Root level navigation for navbar/categories
          if (_isNavbarFocused) {
            final categories = [
              'All',
              ...hotelProvider.bouquets.map((b) => b.name)
            ];
            print(
                'Root handler - navbar focused, handling key: ${event.logicalKey}');
            print(
                'Current category: $_selectedCategory, index: $_selectedCategoryIndex, Total categories: ${categories.length}, Focus nodes: ${_categoryFocusNodes.length}');

            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              // Move left in navbar
              if (_selectedNavbarItem > 0) {
                setState(() {
                  _selectedNavbarItem--;

                  if (_selectedNavbarItem == 0) {
                    // Focus back button
                    _backButtonFocusNode.requestFocus();
                    // Unfocus all category nodes
                    for (var node in _categoryFocusNodes) {
                      if (node.hasFocus) node.unfocus();
                    }
                  } else {
                    // Focus previous category - first safely check if we have enough nodes
                    _selectedCategoryIndex = _selectedNavbarItem - 1;
                    if (_categoryFocusNodes.isNotEmpty &&
                        _selectedCategoryIndex >= 0 &&
                        _selectedCategoryIndex < _categoryFocusNodes.length &&
                        _selectedCategoryIndex < categories.length) {
                      // Unfocus all other category nodes first
                      for (int i = 0; i < _categoryFocusNodes.length; i++) {
                        if (i != _selectedCategoryIndex &&
                            _categoryFocusNodes[i].hasFocus) {
                          _categoryFocusNodes[i].unfocus();
                        }
                      }

                      // Now focus on the correct category
                      _selectedCategory = categories[_selectedCategoryIndex];
                      _categoryFocusNodes[_selectedCategoryIndex]
                          .requestFocus();
                      _filterChannels();
                    }
                  }
                });
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              // Move right in navbar
              final maxItems = 1 + categories.length;
              if (_selectedNavbarItem < maxItems - 1) {
                setState(() {
                  _selectedNavbarItem++;

                  // Focus next category - safely check if we have enough nodes
                  _selectedCategoryIndex = _selectedNavbarItem - 1;
                  if (_categoryFocusNodes.isNotEmpty &&
                      _selectedCategoryIndex >= 0 &&
                      _selectedCategoryIndex < _categoryFocusNodes.length &&
                      _selectedCategoryIndex < categories.length) {
                    // Unfocus all other category nodes first
                    for (int i = 0; i < _categoryFocusNodes.length; i++) {
                      if (i != _selectedCategoryIndex &&
                          _categoryFocusNodes[i].hasFocus) {
                        _categoryFocusNodes[i].unfocus();
                      }
                    }

                    // Now focus on the correct category
                    _selectedCategory = categories[_selectedCategoryIndex];
                    _categoryFocusNodes[_selectedCategoryIndex].requestFocus();
                    _filterChannels();
                  }
                });
                return KeyEventResult.handled;
              }
            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              // Move from navbar to channels
              print('Root handler - Moving from navbar to channels');
              setState(() {
                _isNavbarFocused = false;

                // Unfocus all category nodes first
                for (var node in _categoryFocusNodes) {
                  if (node.hasFocus) node.unfocus();
                }

                // Then focus on the channels list
                _channelsFocusNode.requestFocus();
              });
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter) {
              // Handle selection in navbar
              if (_selectedNavbarItem == 0) {
                // Back button selected
                Navigator.pushNamedAndRemoveUntil(
                    context, '/home', (route) => false);
              } else {
                // Category selected - already handled by TVFocusable
              }
              return KeyEventResult.handled;
            }
          }

          return KeyEventResult.ignored;
        },
        child: Scaffold(
          backgroundColor: _isFullScreen ? Colors.black : AppColors.surface,
          body: Stack(
            children: [
              _isFullScreen
                  ? Stack(
                      children: [
                        // Fullscreen video
                        Positioned.fill(
                          child: Container(
                            color: Colors.black,
                            child: _buildVideoContent(),
                          ),
                        ),
                        // Channel list overlay
                        if (_showChannelList)
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 0,
                            width: MediaQuery.of(context).size.width * 0.3,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Material(
                                color: Colors.transparent,
                                child: ClipRRect(
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                        sigmaX: 10, sigmaY: 10),
                                    child: FullscreenChannelList(
                                      channels: _filteredChannels,
                                      selectedIndex: _selectedChannelIndex,
                                      onChannelSelected: (channel) {
                                        print(
                                            'Channel selected in fullscreen: ${channel.name}');
                                        _onChannelSelected(channel);
                                      },
                                      scrollController:
                                          _channelListScrollController,
                                      isVisible: _showChannelList,
                                      currentChannel: _selectedChannel,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Stack(
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
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface.withOpacity(0.5),
                                    border: Border(
                                      bottom: BorderSide(
                                        color:
                                            AppColors.primary.withOpacity(0.1),
                                      ),
                                    ),
                                  ),
                                  child: SafeArea(
                                    child: Row(
                                      children: [
                                        // Back button with glass effect
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                                sigmaX: 5, sigmaY: 5),
                                            child: TVFocusable(
                                              id: 'back_button',
                                              onSelect: () {
                                                print('Back button pressed');
                                                // Reset orientation before navigating back
                                                SystemChrome
                                                    .setPreferredOrientations([
                                                  DeviceOrientation
                                                      .landscapeLeft,
                                                  DeviceOrientation
                                                      .landscapeRight,
                                                ]);
                                                Navigator
                                                    .pushNamedAndRemoveUntil(
                                                        context,
                                                        '/home',
                                                        (route) => false);
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: _backButtonFocusNode
                                                          .hasFocus
                                                      ? AppColors.primary
                                                          .withOpacity(0.3)
                                                      : AppColors.primary
                                                          .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: _backButtonFocusNode
                                                            .hasFocus
                                                        ? AppColors.accent
                                                        : AppColors.primary
                                                            .withOpacity(0.1),
                                                    width: _backButtonFocusNode
                                                            .hasFocus
                                                        ? 2
                                                        : 1,
                                                  ),
                                                ),
                                                child: IconButton(
                                                  icon: Icon(
                                                    Icons.arrow_back,
                                                    color: _backButtonFocusNode
                                                            .hasFocus
                                                        ? Colors.white
                                                        : AppColors.primary
                                                            .withOpacity(0.7),
                                                    size: 20,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  onPressed: () {
                                                    print(
                                                        'Back button pressed');
                                                    if (_isFullScreen) {
                                                      setState(() {
                                                        _isFullScreen = false;
                                                        _showChannelList =
                                                            false;
                                                      });
                                                    } else {
                                                      _cleanupControllers();
                                                      SystemChrome
                                                          .setPreferredOrientations([
                                                        DeviceOrientation
                                                            .landscapeLeft,
                                                        DeviceOrientation
                                                            .landscapeRight,
                                                      ]);
                                                      Navigator
                                                          .pushNamedAndRemoveUntil(
                                                              context,
                                                              '/home',
                                                              (route) => false);
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        // Categories in navbar
                                        Expanded(
                                          child: SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: Row(
                                              children: [
                                                'All',
                                                ...hotelProvider.bouquets.map(
                                                    (bouquet) => bouquet.name),
                                              ].asMap().entries.map((entry) {
                                                final index = entry.key;
                                                final category = entry.value;
                                                final isSelected =
                                                    _selectedCategory ==
                                                        category;
                                                final isFocused =
                                                    _isNavbarFocused &&
                                                        _selectedNavbarItem ==
                                                            index + 1;

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          right: 8),
                                                  child: TVFocusable(
                                                    id: 'category_${category.toLowerCase()}',
                                                    onSelect: () {
                                                      setState(() {
                                                        _selectedCategoryIndex =
                                                            index;
                                                        _selectedCategory =
                                                            category;
                                                        _filterChannels();
                                                      });
                                                    },
                                                    child: Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 16,
                                                        vertical: 8,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        gradient: isSelected
                                                            ? LinearGradient(
                                                                colors: [
                                                                  AppColors
                                                                      .primary,
                                                                  AppColors
                                                                      .accent,
                                                                ],
                                                              )
                                                            : null,
                                                        color: isSelected
                                                            ? null
                                                            : AppColors.surface
                                                                .withOpacity(
                                                                    0.3),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                        border: Border.all(
                                                          color: isFocused
                                                              ? AppColors
                                                                  .primary
                                                              : isSelected
                                                                  ? AppColors
                                                                      .primary
                                                                  : AppColors
                                                                      .primary
                                                                      .withOpacity(
                                                                          0.1),
                                                          width:
                                                              isFocused ? 2 : 1,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        category,
                                                        style: TextStyle(
                                                          color: isSelected
                                                              ? Colors.white
                                                              : AppColors.text,
                                                          fontWeight: isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight
                                                                  .normal,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Content
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Channels section
                                  Container(
                                    width: MediaQuery.of(context).size.width *
                                        0.55,
                                    decoration: BoxDecoration(
                                      border: Border(
                                        right: BorderSide(
                                          color: AppColors.primary
                                              .withOpacity(0.1),
                                        ),
                                      ),
                                    ),
                                    child: _buildChannelsList(),
                                  ),
                                  // Video player
                                  Expanded(
                                    child: _buildVideoPlayerSection(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
              // News ticker overlay - show in both fullscreen and normal mode
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: NewsTicker(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelsList() {
    return Focus(
      focusNode: _channelsFocusNode,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          print('Channel list key event: ${event.logicalKey.keyLabel}');

          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (_selectedChannelIndex <= 3) {
              print('At top of channel grid, navigating to categories');
              _navigateUpToCategories();
              return KeyEventResult.handled;
            } else {
              // Otherwise navigate to previous row
              setState(() {
                _selectedChannelIndex = (_selectedChannelIndex - 4)
                    .clamp(0, _filteredChannels.length - 1);
                _ensureItemVisible(_selectedChannelIndex);
              });
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() {
              _selectedChannelIndex = (_selectedChannelIndex + 4)
                  .clamp(0, _filteredChannels.length - 1);
              _ensureItemVisible(_selectedChannelIndex);
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            setState(() {
              _selectedChannelIndex = (_selectedChannelIndex - 1)
                  .clamp(0, _filteredChannels.length - 1);
              _ensureItemVisible(_selectedChannelIndex);
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            setState(() {
              _selectedChannelIndex = (_selectedChannelIndex + 1)
                  .clamp(0, _filteredChannels.length - 1);
              _ensureItemVisible(_selectedChannelIndex);
            });
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            if (_selectedChannelIndex >= 0 &&
                _selectedChannelIndex < _filteredChannels.length) {
              _onChannelSelected(_filteredChannels[_selectedChannelIndex]);
              print('Selected channel at index: $_selectedChannelIndex');
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollEndNotification) {
            // After scrolling ends, ensure the selected item is visible
            _ensureItemVisible(_selectedChannelIndex);
          }
          return true;
        },
        child: GridView.builder(
          controller: _channelListScrollController,
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 0.8,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _filteredChannels.length,
          itemBuilder: (context, index) {
            final channel = _filteredChannels[index];
            final isSelected = index == _selectedChannelIndex;
            final isPlaying = _selectedChannel?.id == channel.id &&
                _error == null &&
                _chewieController != null;

            return TVFocusable(
              id: 'channel_${channel.id}',
              onSelect: () {
                setState(() {
                  _selectedChannelIndex = index;
                  _isNavbarFocused = false;
                });
                _ensureItemVisible(index);
                _onChannelSelected(channel);
              },
              child: Stack(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedChannelIndex = index;
                      });
                      _ensureItemVisible(index);
                      _onChannelSelected(channel);
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 160,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: isPlaying
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.3),
                                  AppColors.accent.withOpacity(0.3),
                                ],
                              )
                            : null,
                        color: isPlaying
                            ? null
                            : AppColors.surface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(24),
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
                          // Channel logo
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Image.network(
                                channel.logo,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.tv,
                                    color: AppColors.primary.withOpacity(0.5),
                                    size: 48,
                                  );
                                },
                              ),
                            ),
                          ),
                          // Channel name
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              channel.name,
                              style: TextStyle(
                                color: isPlaying
                                    ? AppColors.primary
                                    : AppColors.text,
                                fontWeight: isPlaying
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSelected)
                    Positioned(
                      left: -8,
                      top: 50,
                      child: Icon(
                        Icons.arrow_right,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  if (isPlaying)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFullScreenChannelList() {
    return AnimatedOpacity(
      opacity: _showChannelList ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: FullscreenChannelList(
        channels: _filteredChannels,
        selectedIndex: _selectedChannelIndex,
        onChannelSelected: _onChannelSelected,
        scrollController: _channelListScrollController,
        isVisible: _showChannelList,
        currentChannel: _selectedChannel,
      ),
    );
  }

  Widget _buildVideoPlayerSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedChannel != null)
            Focus(
              onKey: (node, event) {
                if (event is RawKeyDownEvent) {
                  print('Key pressed in video player: ${event.logicalKey}');
                  print('Fullscreen state: $_isFullScreen');
                  print('Channel list visible: $_showChannelList');

                  if (event.logicalKey == LogicalKeyboardKey.select ||
                      event.logicalKey == LogicalKeyboardKey.enter) {
                    if (_error == null && !_isDisposed) {
                      if (_isFullScreen) {
                        print('OK button pressed in fullscreen mode');
                        _toggleChannelList();
                      } else {
                        print('Entering fullscreen mode');
                        setState(() {
                          _isFullScreen = true;
                          _showChannelList =
                              false; // Don't show channel list automatically
                        });
                      }
                    }
                    return KeyEventResult.handled;
                  } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                    if (_isFullScreen) {
                      print('ESC pressed in fullscreen mode');
                      if (_showChannelList) {
                        _toggleChannelList();
                      } else {
                        setState(() {
                          _isFullScreen = false;
                          _showChannelList = false;
                        });
                      }
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: GestureDetector(
                onDoubleTap: () {
                  print('Double tap detected');
                  if (_error == null && !_isDisposed) {
                    setState(() {
                      if (_isFullScreen) {
                        print('Exiting fullscreen mode via double tap');
                        _isFullScreen = false;
                        _showChannelList = false;
                      } else {
                        print('Entering fullscreen mode via double tap');
                        _isFullScreen = true;
                        _showChannelList =
                            false; // Don't show channel list automatically
                      }
                    });
                  }
                },
                child: _isFullScreen
                    ? Stack(
                        children: [
                          // Fullscreen video
                          Positioned.fill(
                            child: Container(
                              color: Colors.black,
                              child: _buildVideoContent(),
                            ),
                          ),
                          // Channel list overlay
                          if (_showChannelList)
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: MediaQuery.of(context).size.width * 0.3,
                              child: SlideTransition(
                                position: _slideAnimation,
                                child: Material(
                                  color: Colors.transparent,
                                  child: ClipRRect(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(
                                          sigmaX: 10, sigmaY: 10),
                                      child: FullscreenChannelList(
                                        channels: _filteredChannels,
                                        selectedIndex: _selectedChannelIndex,
                                        onChannelSelected: (channel) {
                                          print(
                                              'Channel selected in fullscreen: ${channel.name}');
                                          _onChannelSelected(channel);
                                        },
                                        scrollController:
                                            _channelListScrollController,
                                        isVisible: _showChannelList,
                                        currentChannel: _selectedChannel,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : Stack(
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
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
                                child: _buildVideoContent(),
                              ),
                            ),
                          ),
                          if (!_isLoading &&
                              _error == null &&
                              _chewieController != null)
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
                                      Icons.fullscreen,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Press OK for fullscreen',
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
            )
          else if (_error != null)
            _buildErrorState()
          else
            _buildEmptyState(),
          if (_selectedChannel != null && !_isFullScreen) ...[
            const SizedBox(height: 20),
            _buildChannelInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    if (_isLoading) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Loading channel...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: AppColors.primary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retryPlayback,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
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
      );
    }

    if (_chewieController != null) {
      return Container(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: _isFullScreen
                ? MediaQuery.of(context).size.aspectRatio
                : 16 / 9,
            child: FittedBox(
              fit: BoxFit.fill,
              child: SizedBox(
                width: _isFullScreen
                    ? max(1920, _videoController!.value.size.width)
                    : max(1280, _videoController!.value.size.width),
                height: _isFullScreen
                    ? max(1080, _videoController!.value.size.height)
                    : max(720, _videoController!.value.size.height),
                child: Chewie(controller: _chewieController!),
              ),
            ),
          ),
        ),
      );
    }

    // Show loading state instead of empty container
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ClipRRect(
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
                  label: Text(gen.AppLocalizations.of(context)!.retry),
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
    );
  }

  Widget _buildEmptyState() {
    return ClipRRect(
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
                  gen.AppLocalizations.of(context)!.selectChannel,
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
    );
  }

  Widget _buildChannelInfo() {
    return ClipRRect(
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

  Widget _buildCategoryFilter() {
    final categories = [
      'All',
      ...Provider.of<HotelProvider>(context, listen: false)
          .bouquets
          .map((bouquet) => bouquet.name),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
            final isSelected = _selectedCategory == category;
            final isFocused = index == _focusedCategoryIndex;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TVFocusable(
                id: 'category_${category.toLowerCase()}',
                onSelect: () {
                  setState(() {
                    _selectedCategoryIndex = index;
                    _selectedCategory = category;
                    _filterChannels();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.accent,
                            ],
                          )
                        : null,
                    color: isFocused
                        ? AppColors.primary.withOpacity(0.3)
                        : (isSelected
                            ? null
                            : AppColors.surface.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFocused
                          ? AppColors.accent
                          : (isSelected
                              ? AppColors.primary
                              : AppColors.primary.withOpacity(0.1)),
                      width: isFocused || isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      color: isFocused || isSelected
                          ? Colors.white
                          : AppColors.text,
                      fontWeight: isFocused || isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  KeyEventResult _handleNavigationKeyPress(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
      final categories = ['All', ...hotelProvider.bouquets.map((b) => b.name)];

      print('Key pressed: ${event.logicalKey}');
      print(
          'Current focus - Back: ${_backButtonFocusNode.hasFocus}, Category: $_focusedCategoryIndex, Channels: ${_channelsFocusNode.hasFocus}');
      print('Current category: $_selectedCategory');

      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_channelsFocusNode.hasFocus) {
          // When pressing up from channels, go to the current category
          setState(() {
            // Find the index of the current category
            _focusedCategoryIndex = categories.indexOf(_selectedCategory);
            if (_focusedCategoryIndex == -1) {
              _focusedCategoryIndex =
                  0; // Default to 'All' if category not found
            }

            // Request focus on the category
            _categoryFocusNodes[_focusedCategoryIndex].requestFocus();
            print('Moving to category: ${categories[_focusedCategoryIndex]}');
          });
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_backButtonFocusNode.hasFocus ||
            _categoryFocusNodes.any((node) => node.hasFocus)) {
          setState(() {
            _channelsFocusNode.requestFocus();
            print('Moving to channels');
          });
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_categoryFocusNodes.any((node) => node.hasFocus)) {
          // Left arrow in categories should move focus left
          if (_focusedCategoryIndex > 0) {
            setState(() {
              _focusedCategoryIndex--;
              _categoryFocusNodes[_focusedCategoryIndex].requestFocus();
              _selectedCategory = categories[_focusedCategoryIndex];
              _filterChannels();
              print('Moving to category: ${categories[_focusedCategoryIndex]}');
            });
          } else {
            // At leftmost category, move to back button
            setState(() {
              _backButtonFocusNode.requestFocus();
              print('Moving to back button');
            });
          }
          return KeyEventResult.handled;
        } else if (_channelsFocusNode.hasFocus) {
          // Left arrow in channels should move to previous category
          if (_focusedCategoryIndex > 0) {
            setState(() {
              _focusedCategoryIndex--;
              _categoryFocusNodes[_focusedCategoryIndex].requestFocus();
              _selectedCategory = categories[_focusedCategoryIndex];
              _filterChannels();
              print(
                  'Moving to previous category: ${categories[_focusedCategoryIndex]}');
            });
          } else {
            // At 'All' category, move to back button
            setState(() {
              _backButtonFocusNode.requestFocus();
              print('Moving to back button');
            });
          }
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_backButtonFocusNode.hasFocus) {
          // Right from back button goes to 'All' category
          setState(() {
            _focusedCategoryIndex = 0;
            _categoryFocusNodes[0].requestFocus();
            _selectedCategory = categories[0];
            _filterChannels();
            print('Moving to All category');
          });
          return KeyEventResult.handled;
        } else if (_categoryFocusNodes.any((node) => node.hasFocus)) {
          // Right arrow in categories should move focus right
          if (_focusedCategoryIndex < categories.length - 1) {
            setState(() {
              _focusedCategoryIndex++;
              _categoryFocusNodes[_focusedCategoryIndex].requestFocus();
              _selectedCategory = categories[_focusedCategoryIndex];
              _filterChannels();
              print('Moving to category: ${categories[_focusedCategoryIndex]}');
            });
          }
          return KeyEventResult.handled;
        } else if (_channelsFocusNode.hasFocus) {
          // Right arrow in channels should move to next category
          if (_focusedCategoryIndex < categories.length - 1) {
            setState(() {
              _focusedCategoryIndex++;
              _categoryFocusNodes[_focusedCategoryIndex].requestFocus();
              _selectedCategory = categories[_focusedCategoryIndex];
              _filterChannels();
              print(
                  'Moving to next category: ${categories[_focusedCategoryIndex]}');
            });
          }
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (_backButtonFocusNode.hasFocus) {
          print('Back button selected');
          if (_isFullScreen) {
            setState(() {
              _isFullScreen = false;
              _showChannelList = false;
            });
          }
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          return KeyEventResult.handled;
        } else if (_categoryFocusNodes.any((node) => node.hasFocus)) {
          print('Category selected: ${categories[_focusedCategoryIndex]}');
          setState(() {
            _selectedCategory = categories[_focusedCategoryIndex];
            _filterChannels();
          });
          return KeyEventResult.handled;
        } else if (_channelsFocusNode.hasFocus) {
          if (_selectedChannelIndex >= 0 &&
              _selectedChannelIndex < _filteredChannels.length) {
            _onChannelSelected(_filteredChannels[_selectedChannelIndex]);
            print('Selected channel at index: $_selectedChannelIndex');
          }
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  void _navigateUpToCategories() {
    print('Navigating up from channels to categories');

    // First, unfocus the channels
    _channelsFocusNode.unfocus();

    // Get the category ID
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final categories = ['All', ...hotelProvider.bouquets.map((b) => b.name)];
    final categoryIndex = categories.indexOf(_selectedCategory);

    // Update state immediately
    setState(() {
      _isNavbarFocused = true;

      if (categoryIndex >= 0 && categoryIndex < _categoryFocusNodes.length) {
        _selectedCategoryIndex = categoryIndex;
        _selectedNavbarItem =
            categoryIndex + 1; // +1 because index 0 is back button
        print(
            'Setting up category: ${categories[categoryIndex]} at index $categoryIndex');
      } else {
        // Default to 'All' if current category not found
        _selectedCategoryIndex = 0;
        _selectedNavbarItem = 1; // Back to 'All' category
        print('Category not found, defaulting to All');
      }
    });

    // Give time for the state to update, then focus
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_selectedCategoryIndex >= 0 &&
          _selectedCategoryIndex < _categoryFocusNodes.length) {
        print('Focus changing to category at index $_selectedCategoryIndex');

        // Focus on the specific category node
        _categoryFocusNodes[_selectedCategoryIndex].requestFocus();

        // Also update the focused index for visual feedback
        setState(() {
          _focusedCategoryIndex = _selectedCategoryIndex;
        });
      }
    });
  }

  Widget _buildCategoriesSection() {
    final categories = [
      'All',
      ...Provider.of<HotelProvider>(context, listen: false)
          .bouquets
          .map((bouquet) => bouquet.name),
    ];

    return SizedBox(
      height: 50,
      child: Focus(
        onKey: (node, event) {
          // This handler will be called for any key event in the categories section
          // but we only need to handle keys when a category is focused
          if (event is RawKeyDownEvent && _isNavbarFocused) {
            print('Categories section key event: ${event.logicalKey}');

            // Let the root level handler deal with arrow keys for navigation
            return KeyEventResult.ignored;
          }
          return KeyEventResult.ignored;
        },
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = _selectedCategory == category;
            final isFocused = _categoryFocusNodes[index].hasFocus;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TVFocusable(
                id: 'category_${category.toLowerCase()}',
                isCategory: true, // Mark as category for special handling
                focusColor: AppColors.primary,
                focusNode: _categoryFocusNodes[index],
                onSelect: () {
                  print(
                      'Category selected via TVFocusable: $category (index: $index)');
                  setState(() {
                    _selectedCategory = category;
                    _selectedCategoryIndex = index;
                    _isNavbarFocused = true;
                    _selectedNavbarItem =
                        index + 1; // +1 because item 0 is back button
                    _filterChannels();
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isFocused
                            ? AppColors.primary.withOpacity(0.2)
                            : AppColors.surface),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isFocused || isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      width: isFocused ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isFocused ? AppColors.primary : AppColors.text),
                        fontWeight: isSelected || isFocused
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Helper method to find a focus node by its ID
  FocusNode? _findFocusNodeById(String id) {
    // Check category nodes first
    for (int i = 0; i < _categoryFocusNodes.length; i++) {
      final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
      final categories = ['All', ...hotelProvider.bouquets.map((b) => b.name)];
      if (i < categories.length) {
        final categoryId = 'category_${categories[i].toLowerCase()}';
        if (categoryId == id) {
          return _categoryFocusNodes[i];
        }
      }
    }

    // Check special focus nodes
    if (id == 'back_button') {
      return _backButtonFocusNode;
    } else if (id == 'channels_list') {
      return _channelsFocusNode;
    }

    return null;
  }

  // Get the ID of the category corresponding to the current selection
  String _getCategoryIdForCurrentSelection() {
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final categories = ['All', ...hotelProvider.bouquets.map((b) => b.name)];
    final categoryIndex = categories.indexOf(_selectedCategory);

    if (categoryIndex >= 0 && categoryIndex < categories.length) {
      return 'category_${categories[categoryIndex].toLowerCase()}';
    }

    // Default to 'All' category
    return 'category_all';
  }
}

class FullScreenChannelList extends StatelessWidget {
  final List<Channel> channels;
  final int selectedIndex;
  final Function(Channel) onChannelSelected;
  final ScrollController scrollController;
  final bool isVisible;
  final Channel? currentChannel;

  const FullScreenChannelList({
    super.key,
    required this.channels,
    required this.selectedIndex,
    required this.onChannelSelected,
    required this.scrollController,
    required this.isVisible,
    required this.currentChannel,
  });

  @override
  Widget build(BuildContext context) {
    print(
        'Building FullScreenChannelList with ${channels.length} channels, selected: $selectedIndex');
    return Container(
      color: Colors.black.withOpacity(0.85),
      child: SizedBox(
        height: MediaQuery.of(context).size.height *
            0.6, // Fixed height at 60% of screen
        child: ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: channels.length,
          itemBuilder: (context, index) {
            final channel = channels[index];
            final isSelected = index == selectedIndex;
            final isPlaying = channel.id == currentChannel?.id;
            print(
                'Building channel item: ${channel.name}, isSelected: $isSelected');

            // Calculate the position to center the selected item
            if (isSelected && scrollController.hasClients) {
              final itemHeight = 80.0; // Approximate height of each list item
              final viewportHeight =
                  scrollController.position.viewportDimension;
              final targetOffset = (index * itemHeight) -
                  (viewportHeight / 2) +
                  (itemHeight / 2);

              // Ensure we don't scroll past the top or bottom
              final clampedOffset = targetOffset.clamp(
                  0.0, scrollController.position.maxScrollExtent);

              // Animate to the target position
              scrollController.animateTo(
                clampedOffset,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
              );
            }

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: isPlaying
                    ? LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(0.3),
                          AppColors.accent.withOpacity(0.3),
                        ],
                      )
                    : null,
                color: isPlaying ? null : AppColors.surface.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.1),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ListTile(
                leading: Image.network(
                  channel.logo,
                  width: 40,
                  height: 40,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.tv, color: AppColors.primary),
                    );
                  },
                ),
                title: Text(
                  channel.name,
                  style: TextStyle(
                    color: isPlaying ? AppColors.primary : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isPlaying
                    ? const Icon(Icons.play_arrow, color: AppColors.accent)
                    : null,
                onTap: () {
                  print('Channel tapped: ${channel.name}');
                  onChannelSelected(channel);
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
