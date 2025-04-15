import 'dart:ui';
import 'dart:async';
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
import '../models/channel_response.dart'; // Use the correct import for Bouquet
import '../services/tv_focus_service.dart';
import '../providers/language_provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart' as gen;

// For VideoFormat
enum VideoFormat { dash, hls, ss, other }

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
  bool _isChannelsLoading = true;
  bool _isNavbarFocused = false;
  int _selectedNavbarItem = 0;
  final ScrollController _channelListScrollController = ScrollController();
  DateTime? _lastBackPressTime;
  DateTime? _lastChannelListHideTime; // Track when channel list was last hidden
  bool _isHeaderVisible = true;

  // Add overlay state variables
  OverlayEntry? _channelNameOverlay;
  Timer? _overlayTimer;

  // Buffering management
  bool _isBuffering = false;
  DateTime? _bufferingStartTime;
  Timer? _bufferingTimer;

  void _showChannelNameOverlay(Channel channel) {
    _hideChannelNameOverlay();

    _channelNameOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: 20,
        left: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  channel.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_channelNameOverlay!);

    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 2), _hideChannelNameOverlay);
  }

  void _hideChannelNameOverlay() {
    _channelNameOverlay?.remove();
    _channelNameOverlay = null;
    _overlayTimer?.cancel();
    _overlayTimer = null;
  }

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

    // Schedule loading channels AFTER the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadChannelsAndInitializeFocus();
    });
  }

  Future<void> _loadChannelsAndInitializeFocus() async {
    setState(() {
      _isChannelsLoading = true;
    });

    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    try {
      await hotelProvider.loadChannelsAndCategories();

      if (!mounted) return;

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
          if (focusNode.hasFocus && mounted) {
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
        _isChannelsLoading = false;

        // Auto-select the first channel if we have channels
        if (_filteredChannels.isNotEmpty) {
          _selectedChannelIndex = 0;
          _selectedChannel = _filteredChannels[0];
        }
      });

      // Initialize focus for the channels after setting the state
      _initializeFocusForChannels();

      // Ensure the channels list gets focus after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Direct focus to the first channel
        if (_filteredChannels.isNotEmpty && _channelsFocusNode != null) {
          _channelsFocusNode.requestFocus();

          // Make sure the first channel is properly selectable
          setState(() {
            _isNavbarFocused = false;
            _isCategoryFocused = false;
            _isLanguageFocused = false;
          });

          // Check if we need to initialize the player with the first channel
          if (_selectedChannel != null && _videoController == null) {
            _initializePlayer();
          }
        }
      });
    } catch (e) {
      print('Error loading channels: $e');
      if (mounted) {
        setState(() {
          _isChannelsLoading = false;
        });
        _showConnectionError(context);
      }
    }
  }

  List<Channel> _getFilteredChannels() {
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    if (hotelProvider.channels.isEmpty) {
      print('Warning: Channel list is empty');
      return [];
    }

    if (_selectedCategory == 'All') {
      return hotelProvider.channels;
    }

    // Find the bouquet ID for the selected category name
    try {
      // Check if the category exists in the bouquets
      final categoryExists = hotelProvider.bouquets
          .any((bouquet) => bouquet.name == _selectedCategory);

      if (!categoryExists) {
        print('Warning: Selected category not found: $_selectedCategory');
        return hotelProvider.channels;
      }

      final selectedBouquetId = hotelProvider.bouquets
          .firstWhere((bouquet) => bouquet.name == _selectedCategory)
          .id;

      return hotelProvider.channels
          .where((channel) => channel.categ == selectedBouquetId)
          .toList();
    } catch (e) {
      print('Error filtering by category: $e');
      return hotelProvider.channels;
    }
  }

  void _filterChannels() {
    if (!mounted || _isChannelsLoading) return;

    try {
      setState(() {
        _filteredChannels = _getFilteredChannels();
        // Re-initialize focus for the new filtered channels
        _initializeFocusForChannels();
      });
    } catch (e) {
      print('Error filtering channels: $e');
    }
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
    
    // Clean up buffering timer
    _bufferingTimer?.cancel();
    
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
        'DEBUG [_onChannelSelected] Channel: ${channel.name}, Current: ${_selectedChannel?.name}');
    print(
        'DEBUG [_onChannelSelected] FullScreen: $_isFullScreen, ChannelList: $_showChannelList');

    // Request focus for the channels list to prevent focus loss
    _channelsFocusNode.requestFocus();

    if (_selectedChannel?.id == channel.id) {
      // If the same channel is selected, only toggle channel list in fullscreen mode
      if (_isFullScreen) {
        print(
            'DEBUG [_onChannelSelected] Same channel in fullscreen, toggling channel list');
        if (_showChannelList) {
          _hideChannelList();
        } else {
          // Utiliser jumpTo au lieu de animateTo pour un centrage immédiat
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted &&
                _channelListScrollController.hasClients &&
                _selectedChannelIndex >= 0) {
              _directCenterChannel();
            }
          });
        }
        return;
      } else {
        // If not in fullscreen mode, enter fullscreen mode
        print(
            'DEBUG [_onChannelSelected] Same channel in non-fullscreen, entering fullscreen');
        _toggleFullScreen(value: true);
      }

      // Force a refresh of the channel state to ensure it can be selected again immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Just ensure the channel is properly marked as selected
            final currentIndex =
                _filteredChannels.indexWhere((c) => c.id == channel.id);
            if (currentIndex >= 0) {
              _selectedChannelIndex = currentIndex;
            }
          });

          // Utiliser jumpTo au lieu de animateTo pour un centrage immédiat
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted &&
                _channelListScrollController.hasClients &&
                _selectedChannelIndex >= 0) {
              _directCenterChannel();
            }
          });
        }
      });
    } else {
      // Switch to new channel
      print(
          'DEBUG [_onChannelSelected] Switching to new channel: ${channel.name}');
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
        httpHeaders: {
          'User-Agent': 'HotelStream/1.0',
          // Set headers that help with caching
          'Connection': 'keep-alive',
        },
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      // Initialize video player
      await _videoController!.initialize();

      // Set up buffering monitoring
      _videoController!.addListener(_onVideoControllerUpdate);

      // Pre-buffer by seeking to beginning and waiting
      await _videoController!.seekTo(Duration.zero);

      // Short delay to allow initial buffering
      await Future.delayed(const Duration(milliseconds: 500));

      // Set preferred volume and speed
      await _videoController!.setVolume(1.0);
      await _videoController!.setPlaybackSpeed(1.0);

      // Use the video's native resolution
      final videoWidth = _videoController!.value.size.width;
      final videoHeight = _videoController!.value.size.height;
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

  void _onVideoControllerUpdate() {
    if (_videoController == null || _isDisposed) return;

    // Detect buffering state changes
    final bool isCurrentlyBuffering = _videoController!.value.isBuffering;

    if (isCurrentlyBuffering != _isBuffering) {
      setState(() => _isBuffering = isCurrentlyBuffering);

      if (isCurrentlyBuffering) {
        // Start buffering
        _bufferingStartTime = DateTime.now();

        // Start timer to check for long buffering
        _bufferingTimer?.cancel();
        _bufferingTimer = Timer(const Duration(seconds: 3), () {
          if (_isBuffering && mounted) {
            // If still buffering after 3 seconds, try to recover
            _tryRecoverFromLongBuffering();
          }
        });
      } else {
        // Buffering ended
        _bufferingStartTime = null;
        _bufferingTimer?.cancel();
      }
    }
  }

  void _tryRecoverFromLongBuffering() {
    if (_videoController == null || !_isBuffering || !mounted) return;

    print('Long buffering detected, trying to recover playback');

    // Try seeking slightly forward to bypass buffering issue
    final Duration currentPosition = _videoController!.value.position;
    final Duration seekTarget =
        currentPosition + const Duration(milliseconds: 500);

    _videoController!.seekTo(seekTarget).then((_) {
      // Force play after seeking
      _videoController!.play();
    });
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
      print(
          'DEBUG [_handleFullscreenKeyPress] Key: ${event.logicalKey}, FullScreen: $_isFullScreen, ChannelList: $_showChannelList');

      // Handle all key events within the channel screen
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (_isFullScreen) {
          print(
              'DEBUG [_handleFullscreenKeyPress] OK/Select pressed in fullscreen');
          print(
              'DEBUG [_handleFullscreenKeyPress] Current channel list: $_showChannelList');

          // Force show channel list immediately
          if (!_showChannelList) {
            print('DEBUG [_handleFullscreenKeyPress] Opening channel list');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _showChannelList = true;
                  _slideController.value = 1.0;

                  // Make sure we find the current channel in the filtered list
                  final currentIndex = _filteredChannels
                      .indexWhere((c) => c.id == _selectedChannel?.id);
                  if (currentIndex >= 0) {
                    _selectedChannelIndex = currentIndex;
                  }
                });

                // Utiliser jumpTo au lieu de animateTo pour un centrage immédiat
                Future.delayed(Duration(milliseconds: 100), () {
                  if (mounted &&
                      _channelListScrollController.hasClients &&
                      _selectedChannelIndex >= 0) {
                    _directCenterChannel();
                  }
                });
              }
            });
            return KeyEventResult.handled;
          } else {
            setState(() {
              // When channel list is showing, select the focused channel and hide the list
              _onChannelSelected(_filteredChannels[_selectedChannelIndex]);
              _showChannelList = false;
              _slideController.value = 0.0;
            });
          }

          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
          _showChannelList) {
        setState(() => _selectedChannelIndex =
            (_selectedChannelIndex - 1).clamp(0, _filteredChannels.length - 1));
        _directCenterChannel();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
          _showChannelList) {
        setState(() => _selectedChannelIndex =
            (_selectedChannelIndex + 1).clamp(0, _filteredChannels.length - 1));
        _directCenterChannel();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.goBack) {
        print(
            'DEBUG [_handleFullscreenKeyPress] GoBack/Escape key pressed, FullScreen: $_isFullScreen, ChannelList: $_showChannelList');

        if (_isFullScreen) {
          print(
              'DEBUG [_handleFullscreenKeyPress] In fullscreen mode, handling back key');

          if (_showChannelList) {
            print('DEBUG [_handleFullscreenKeyPress] Hiding channel list');
            _hideChannelList();
          } else {
            // Only exit fullscreen mode when channel list is not showing
            // and we didn't just hide the channel list
            final now = DateTime.now();
            final recentlyHidChannelList = _lastChannelListHideTime != null &&
                now.difference(_lastChannelListHideTime!).inMilliseconds < 500;

            if (recentlyHidChannelList) {
              print(
                  'DEBUG [_handleFullscreenKeyPress] Recently hid channel list, ignoring back button');
            } else {
              print(
                  'DEBUG [_handleFullscreenKeyPress] Channel list is NOT showing, exiting fullscreen mode');
              _toggleFullScreen(value: false);
            }
          }

          // Very important! Explicitly handle this key and prevent further processing
          print(
              'DEBUG [_handleFullscreenKeyPress] Marking goBack key as HANDLED');
          return KeyEventResult.handled;
        }
        // Let parent handlers manage non-fullscreen goBack
        print(
            'DEBUG [_handleFullscreenKeyPress] Not in fullscreen, ignoring key');
        return KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        if (_isFullScreen) {
          print('DEBUG [_handleFullscreenKeyPress] Toggling channel list');
          _toggleChannelList();
          return KeyEventResult.handled;
        }
      } else if (!_showChannelList) {
        // Handle up/down navigation when channel list is not visible
        if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          if (_selectedChannelIndex > 0) {
            setState(() {
              _selectedChannelIndex--;
            });
            final nextChannel = _filteredChannels[_selectedChannelIndex];
            // Show the channel name overlay
            _showChannelNameOverlay(nextChannel);
            // Select the channel immediately
            _onChannelSelected(nextChannel);
            return KeyEventResult.handled;
          }
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          if (_selectedChannelIndex < _filteredChannels.length - 1) {
            setState(() {
              _selectedChannelIndex++;
            });
            final nextChannel = _filteredChannels[_selectedChannelIndex];
            // Show the channel name overlay
            _showChannelNameOverlay(nextChannel);
            // Select the channel immediately
            _onChannelSelected(nextChannel);
            return KeyEventResult.handled;
          }
        }
      }
    }

    return KeyEventResult.ignored;
  }

  // Méthode directe pour centrer un élément dans la liste des chaînes
  void _directCenterChannel() {
    if (!_channelListScrollController.hasClients || _selectedChannelIndex < 0) {
      return;
    }

    try {
      // Hauteur fixe pour chaque élément de la liste
      const itemHeight = 82.0; // Hauteur totale avec les marges

      // Hauteur visible de la liste des chaînes
      final listHeight =
          _channelListScrollController.position.viewportDimension;
      final halfListHeight = listHeight / 2;

      // Position de l'élément dans la liste
      final itemPosition = _selectedChannelIndex * itemHeight;

      // Calcul de l'offset pour centrer l'élément
      final targetOffset = itemPosition - halfListHeight + (itemHeight / 2);

      // Limiter l'offset dans les limites de la liste
      final maxScroll = _channelListScrollController.position.maxScrollExtent;
      final clampedOffset = targetOffset.clamp(0.0, maxScroll);

      // Utiliser jumpTo au lieu de animateTo pour un centrage immédiat
      _channelListScrollController.jumpTo(clampedOffset);

      print(
          'DEBUG [_directCenterChannel] Centered channel $_selectedChannelIndex at offset $clampedOffset');
    } catch (e) {
      print('ERROR [_directCenterChannel] Failed to center: $e');
    }
  }

  void _ensureItemVisible(int index) {
    if (!_channelListScrollController.hasClients) return;

    final itemHeight = 80.0; // Approximate height of each list item
    final viewportHeight =
        _channelListScrollController.position.viewportDimension;
    final targetOffset =
        (index * itemHeight) - (viewportHeight / 2) + (itemHeight / 2);

    // Ensure we don't scroll past the top or bottom
    final clampedOffset = targetOffset.clamp(
        0.0, _channelListScrollController.position.maxScrollExtent);

    // Animate to the target position
    _channelListScrollController.animateTo(
      clampedOffset,
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

    // Ensure fullscreen key handlers have priority by using a separate focus node
    FocusNode fullscreenFocusNode =
        FocusNode(debugLabel: 'fullscreen_master_focus');
    if (_isFullScreen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (fullscreenFocusNode.canRequestFocus) {
          fullscreenFocusNode.requestFocus();
        }
      });
    }

    return WillPopScope(
      onWillPop: () async {
        print(
            'DEBUG [WillPopScope] Intercepting back navigation, FullScreen: $_isFullScreen, ChannelList: $_showChannelList');

        // Check if we just hid the channel list (within the last 500ms)
        final now = DateTime.now();
        final recentlyHidChannelList = _lastChannelListHideTime != null &&
            now.difference(_lastChannelListHideTime!).inMilliseconds < 500;

        if (recentlyHidChannelList) {
          print(
              'DEBUG [WillPopScope] Recently hid channel list, ignoring back button');
          return false; // Prevent further back button handling
        }

        if (_isFullScreen) {
          print('DEBUG [WillPopScope] In fullscreen mode');
          if (_showChannelList) {
            // If channel list is showing, hide it
            print('DEBUG [WillPopScope] Channel list is showing, hiding it');
            _hideChannelList();
            return false; // Prevent default back behavior
          } else {
            // Only exit fullscreen mode when channel list is not showing
            // and we didn't just hide the channel list
            final now = DateTime.now();
            final recentlyHidChannelList = _lastChannelListHideTime != null &&
                now.difference(_lastChannelListHideTime!).inMilliseconds < 500;

            if (recentlyHidChannelList) {
              print(
                  'DEBUG [WillPopScope] Recently hid channel list, ignoring back button');
            } else {
              print(
                  'DEBUG [WillPopScope] Channel list is NOT showing, exiting fullscreen mode');
              _toggleFullScreen(value: false);
            }
            return false; // Prevent default back behavior
          }
        } else {
          // In non-fullscreen mode, implement double back press to exit
          print(
              'DEBUG [WillPopScope] Not in fullscreen mode, handling double back press logic');
          final now = DateTime.now();
          if (_lastBackPressTime == null ||
              now.difference(_lastBackPressTime!) >
                  const Duration(seconds: 2)) {
            // First back press or more than 2 seconds since last press
            _lastBackPressTime = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Press back again to return to home screen'),
                duration: Duration(seconds: 2),
              ),
            );
            return false; // Don't exit yet
          }

          print(
              'DEBUG [WillPopScope] Second back press, navigating to home page');
          // Navigate to home page on second back press
          Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
          return false; // Prevent default back navigation
        }
      },
      child: Focus(
        focusNode: _isFullScreen ? fullscreenFocusNode : null,
        // In fullscreen mode, handle keys directly with our fullscreen handler
        onKey: _isFullScreen
            ? (FocusNode node, RawKeyEvent event) =>
                _handleFullscreenKeyPress(event)
            : (node, event) {
                print(
                    'DEBUG [RootFocus] Key: ${event.logicalKey}, FullScreen: $_isFullScreen, ChannelList: $_showChannelList');

                // Only handle key down events
                if (!(event is RawKeyDownEvent)) return KeyEventResult.ignored;

                // When in fullscreen video mode, delegate to fullscreen handler first
                if (_isFullScreen) {
                  print(
                      'DEBUG [RootFocus] In fullscreen mode, checking special back button handling');

                  // Special handling for back button in fullscreen mode
                  if (event.logicalKey == LogicalKeyboardKey.goBack ||
                      event.logicalKey == LogicalKeyboardKey.escape) {
                    print(
                        'DEBUG [RootFocus] Back/Escape key in fullscreen mode');
                    if (_showChannelList) {
                      // If channel list is showing, hide it
                      print(
                          'DEBUG [RootFocus] Channel list is showing, hiding it');
                      _hideChannelList();
                      print('DEBUG [RootFocus] Marking back key as HANDLED');
                      return KeyEventResult.handled;
                    } else {
                      // Only exit fullscreen mode when channel list is not showing
                      // and we didn't just hide the channel list
                      final now = DateTime.now();
                      final recentlyHidChannelList =
                          _lastChannelListHideTime != null &&
                              now
                                      .difference(_lastChannelListHideTime!)
                                      .inMilliseconds <
                                  500;

                      if (recentlyHidChannelList) {
                        print(
                            'DEBUG [RootFocus] Recently hid channel list, ignoring back button');
                      } else {
                        print(
                            'DEBUG [RootFocus] Channel list is NOT showing, exiting fullscreen mode');
                        _toggleFullScreen(value: false);
                      }
                      print('DEBUG [RootFocus] Marking back key as HANDLED');
                      return KeyEventResult.handled;
                    }
                  }

                  print('DEBUG [RootFocus] Delegating to fullscreen handler');
                  final result = _handleFullscreenKeyPress(event);
                  if (result == KeyEventResult.handled) {
                    print(
                        'DEBUG [RootFocus] Fullscreen handler processed the key');
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
                              _selectedCategoryIndex <
                                  _categoryFocusNodes.length &&
                              _selectedCategoryIndex < categories.length) {
                            // Unfocus all other category nodes first
                            for (int i = 0;
                                i < _categoryFocusNodes.length;
                                i++) {
                              if (i != _selectedCategoryIndex &&
                                  _categoryFocusNodes[i].hasFocus) {
                                _categoryFocusNodes[i].unfocus();
                              }
                            }

                            // Now focus on the correct category
                            _selectedCategory =
                                categories[_selectedCategoryIndex];
                            _categoryFocusNodes[_selectedCategoryIndex]
                                .requestFocus();
                            _filterChannels();
                          }
                        }
                      });
                      return KeyEventResult.handled;
                    }
                  } else if (event.logicalKey ==
                      LogicalKeyboardKey.arrowRight) {
                    // Move right in navbar
                    final maxItems = 1 + categories.length;
                    if (_selectedNavbarItem < maxItems - 1) {
                      setState(() {
                        _selectedNavbarItem++;

                        // Focus next category - safely check if we have enough nodes
                        _selectedCategoryIndex = _selectedNavbarItem - 1;
                        if (_categoryFocusNodes.isNotEmpty &&
                            _selectedCategoryIndex >= 0 &&
                            _selectedCategoryIndex <
                                _categoryFocusNodes.length &&
                            _selectedCategoryIndex < categories.length) {
                          // Unfocus all other category nodes first
                          for (int i = 0; i < _categoryFocusNodes.length; i++) {
                            if (i != _selectedCategoryIndex &&
                                _categoryFocusNodes[i].hasFocus) {
                              _categoryFocusNodes[i].unfocus();
                            }
                          }

                          // Now focus on the correct category
                          _selectedCategory =
                              categories[_selectedCategoryIndex];
                          _categoryFocusNodes[_selectedCategoryIndex]
                              .requestFocus();
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

                      // Unfocus all category nodes
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
                            width: MediaQuery.of(context).size.width *
                                0.4, // Changed from 0.3 to 0.4
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
                                                // Clean up controllers before navigating
                                                _cleanupControllers();
                                                Navigator.of(context)
                                                    .pushReplacementNamed('/');
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
                                                      Navigator.of(context)
                                                          .pushReplacementNamed(
                                                              '/');
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
                                    width:
                                        300, // Fixed width as per fullscreen list
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
    if (_isChannelsLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading channels...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Focus(
      focusNode: _channelsFocusNode,
      autofocus: !_isFullScreen,
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            if (_selectedChannelIndex == 0) {
              _navigateUpToCategories();
              return KeyEventResult.handled;
            } else {
              setState(() {
                _selectedChannelIndex--;
              });
              _directCenterChannel(); // Center immediately after selection
              return KeyEventResult.handled;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            setState(() {
              _selectedChannelIndex = (_selectedChannelIndex + 1)
                  .clamp(0, _filteredChannels.length - 1);
            });
            _directCenterChannel(); // Center immediately after selection
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.select ||
              event.logicalKey == LogicalKeyboardKey.enter) {
            if (_selectedChannelIndex >= 0 &&
                _selectedChannelIndex < _filteredChannels.length) {
              _onChannelSelected(_filteredChannels[_selectedChannelIndex]);
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Container(
        width: 300,
        color: Colors.black.withOpacity(0.85),
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification scrollInfo) {
                if (scrollInfo is ScrollUpdateNotification) {
                  setState(() {
                    _isHeaderVisible = scrollInfo.metrics.pixels <= 20;
                  });
                }
                return true;
              },
              child: ListView.builder(
                controller: _channelListScrollController,
                padding: const EdgeInsets.symmetric(vertical: 16),
                itemCount: _filteredChannels.length,
                itemExtent:
                    82.0, // Match the height used in _directCenterChannel
                itemBuilder: (context, index) {
                  final channel = _filteredChannels[index];
                  final isSelected = index == _selectedChannelIndex;
                  final isPlaying = _selectedChannel?.id == channel.id &&
                      _error == null &&
                      _chewieController != null;

                  // Center the selected item immediately when it becomes selected
                  if (isSelected && _channelListScrollController.hasClients) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _directCenterChannel();
                    });
                  }

                  return Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      gradient: isPlaying
                          ? LinearGradient(
                              colors: [
                                AppColors.primary.withOpacity(0.3),
                                AppColors.accent.withOpacity(0.3),
                              ],
                            )
                          : null,
                      color:
                          isPlaying ? null : AppColors.surface.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: ListTile(
                      leading: channel.logo.isNotEmpty
                          ? Image.network(
                              channel.logo,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildChannelAvatar(channel),
                            )
                          : _buildChannelAvatar(channel),
                      title: Text(
                        channel.name,
                        style: TextStyle(
                          color: isPlaying ? AppColors.primary : Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isPlaying
                          ? const Icon(Icons.play_arrow,
                              color: AppColors.accent)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedChannelIndex = index;
                        });
                        _directCenterChannel(); // Center immediately after tap
                        _onChannelSelected(channel);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelAvatar(Channel channel) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          channel.name.substring(0, min(2, channel.name.length)).toUpperCase(),
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
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
    return Container(
      color: Colors.black,
      width: double.infinity,
      height: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedChannel != null)
            Expanded(
              child: Focus(
                onKey: (node, event) {
                  if (event is RawKeyDownEvent) {
                    print(
                        'DEBUG [VideoFocus] Key: ${event.logicalKey}, FullScreen: $_isFullScreen, ChannelList: $_showChannelList');

                    if (event.logicalKey == LogicalKeyboardKey.select ||
                        event.logicalKey == LogicalKeyboardKey.enter) {
                      if (_error == null && !_isDisposed) {
                        if (_isFullScreen) {
                          // Handle OK button in fullscreen mode directly here instead of delegating
                          print(
                              'DEBUG [VideoFocus] OK button in fullscreen mode, handling directly');
                          setState(() {
                            if (_showChannelList) {
                              // When channel list is showing, select the focused channel and hide the list
                              _onChannelSelected(
                                  _filteredChannels[_selectedChannelIndex]);
                              _showChannelList = false;
                              _slideController.value = 0.0;
                            } else {
                              // Show channel list when OK button is pressed in fullscreen
                              _showChannelList = true;
                              _slideController.value = 1.0;

                              // Find index of current channel in the filtered list
                              final currentIndex = _filteredChannels.indexWhere(
                                  (c) => c.id == _selectedChannel?.id);
                              if (currentIndex >= 0) {
                                _selectedChannelIndex = currentIndex;
                              }

                              // Add a short delay to ensure the channel list is visible before scrolling
                              Future.delayed(Duration(milliseconds: 100), () {
                                if (mounted) {
                                  _centerSelectedChannel();
                                }
                              });
                            }
                          });
                          return KeyEventResult.handled;
                        } else {
                          print(
                              'DEBUG [VideoFocus] OK button in non-fullscreen mode, entering fullscreen');
                          _toggleFullScreen(value: true);
                          return KeyEventResult.handled;
                        }
                      }
                    } else if (event.logicalKey == LogicalKeyboardKey.escape ||
                        event.logicalKey == LogicalKeyboardKey.goBack) {
                      if (_isFullScreen) {
                        print(
                            'DEBUG [VideoFocus] Back/Escape key in fullscreen mode');
                        if (_showChannelList) {
                          print(
                              'DEBUG [VideoFocus] Channel list is showing, hiding it');
                          _hideChannelList();
                          print(
                              'DEBUG [VideoFocus] Marking back key as HANDLED');
                          return KeyEventResult.handled;
                        } else {
                          // Only exit fullscreen mode when channel list is not showing
                          // and we didn't just hide the channel list
                          final now = DateTime.now();
                          final recentlyHidChannelList =
                              _lastChannelListHideTime != null &&
                                  now
                                          .difference(_lastChannelListHideTime!)
                                          .inMilliseconds <
                                      500;

                          if (recentlyHidChannelList) {
                            print(
                                'DEBUG [VideoFocus] Recently hid channel list, ignoring back button');
                            return KeyEventResult.handled;
                          }

                          print(
                              'DEBUG [VideoFocus] Channel list is NOT showing, exiting fullscreen mode');
                          _toggleFullScreen(value: false);

                          // Center the selected channel in the list
                          _centerSelectedChannel();

                          print(
                              'DEBUG [VideoFocus] Marking back key as HANDLED');
                          return KeyEventResult.handled;
                        }
                      } else {
                        // In non-fullscreen mode, implement double back press logic
                        print(
                            'DEBUG [VideoFocus] Back key in non-fullscreen mode, handling double press');
                        final now = DateTime.now();
                        if (_lastBackPressTime == null ||
                            now.difference(_lastBackPressTime!) >
                                const Duration(seconds: 2)) {
                          // First back press or more than 2 seconds since last press
                          _lastBackPressTime = now;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Press back again to return to home screen'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return KeyEventResult.handled;
                        }

                        // Second back press within 2 seconds
                        print(
                            'DEBUG [VideoFocus] Second back press, navigating to home');
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/home', (route) => false);
                        return KeyEventResult.handled;
                      }
                    }
                  }
                  return KeyEventResult.ignored;
                },
                child: GestureDetector(
                  onDoubleTap: () {
                    print(
                        'DEBUG [DoubleTap] Double tap detected, FullScreen: $_isFullScreen, ChannelList: $_showChannelList');
                    if (_error == null && !_isDisposed) {
                      if (_isFullScreen) {
                        print(
                            'DEBUG [DoubleTap] Exiting fullscreen mode via double tap');
                        _toggleFullScreen(value: false);
                      } else {
                        print(
                            'DEBUG [DoubleTap] Entering fullscreen mode via double tap');
                        _toggleFullScreen(value: true);
                      }
                    }
                  },
                  child: Container(
                    color: Colors.black,
                    width: double.infinity,
                    height: double.infinity,
                    child: _buildVideoContent(),
                  ),
                ),
              ),
            )
          else if (_error != null)
            Expanded(child: _buildErrorState())
          else
            Expanded(child: _buildEmptyState()),

          // Channel info panel visible at the bottom only if not in fullscreen
          if (_selectedChannel != null && !_isFullScreen)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 120,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildChannelInfo(),
            ),
        ],
      ),
    );
  }

  // Helper method to center the selected channel in the list
  void _centerSelectedChannel() {
    if (!mounted) return;

    // Check if we have a valid scroll controller with clients
    if (!_channelListScrollController.hasClients) {
      print(
          'DEBUG [_centerSelectedChannel] ScrollController has no clients yet, retrying...');
      // Try again after a short delay
      Future.delayed(Duration(milliseconds: 150), () {
        if (mounted) {
          _centerSelectedChannel();
        }
      });
      return;
    }

    // Ensure valid index to prevent crashes
    if (_selectedChannelIndex < 0 ||
        _selectedChannelIndex >= _filteredChannels.length) {
      print(
          'DEBUG [_centerSelectedChannel] Invalid selected index: $_selectedChannelIndex');
      return;
    }

    try {
      // Fixed height for each list item
      const itemHeight = 82.0; // Total height including margins

      // Calculate the total height of the visible area
      final viewportHeight =
          _channelListScrollController.position.viewportDimension;
      final halfViewportHeight = viewportHeight / 2;

      // Calculate the target position
      final itemPosition = _selectedChannelIndex * itemHeight;
      final targetOffset = itemPosition - halfViewportHeight + (itemHeight / 2);

      // Get the maximum scroll extent
      final maxExtent = _channelListScrollController.position.maxScrollExtent;
      if (maxExtent < 0) {
        print('DEBUG [_centerSelectedChannel] Invalid maxExtent: $maxExtent');
        return; // Exit if we can't safely get the max extent
      }

      // Clamp the offset to valid range
      final double clampedOffset = targetOffset.clamp(0.0, maxExtent);

      // Scroll to the position
      _channelListScrollController.animateTo(
        clampedOffset,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );

      print(
          'DEBUG [_centerSelectedChannel] Scrolled to index $_selectedChannelIndex at offset $clampedOffset');
    } catch (e) {
      print('DEBUG [_centerSelectedChannel] Error during scrolling: $e');
      // Don't crash the app if scrolling fails
    }
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
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: Stack(
                  children: [
                    // Video player
                    Positioned.fill(
                      child: Chewie(controller: _chewieController!),
                    ),

                    // Buffering indicator
                    if (_isBuffering)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.5),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Buffering...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
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
    // Get the category name based on the category ID
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    String categoryName = "Unknown";

    try {
      final category = hotelProvider.bouquets.firstWhere(
        (bouquet) => bouquet.id == _selectedChannel!.categ,
      );
      categoryName = category.name;
    } catch (e) {
      // Default to "Unknown" if category not found
      print('Category not found for ID: ${_selectedChannel!.categ}');
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.all(20),
          // Constrain the height to prevent overflow
          constraints: BoxConstraints(
            maxHeight: 150, // Increased maximum height to prevent overflow
          ),
          decoration: BoxDecoration(
            color: AppColors.surface.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Use minimum space needed
            children: [
              // Channel info header (logo, name, category)
              Row(
                children: [
                  // Channel logo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _selectedChannel!.logo,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.tv, color: AppColors.primary),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Channel name
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
                  // Category badge
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
                      categoryName, // Using the actual category name instead of ID
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
              // Make the description scrollable with a fixed height constraint
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    _selectedChannel!.description,
                    style: TextStyle(
                      color: AppColors.text.withOpacity(0.8),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
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
                    color:
                        isSelected ? null : AppColors.surface.withOpacity(0.3),
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
    if (event is KeyDownEvent) {
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

    // Get all categories
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final categories = ['All', ...hotelProvider.bouquets.map((b) => b.name)];

    // Ensure we have focus nodes for all categories
    if (_categoryFocusNodes.length < categories.length) {
      print('Category focus nodes missing, rebuilding them');
      _resetCategoryFocusNodes();
    }

    // First, unfocus the channels
    _channelsFocusNode.unfocus();

    // Get the category index
    final categoryIndex = categories.indexOf(_selectedCategory);
    print('Current category: $_selectedCategory, index: $categoryIndex');

    // Actually trigger the category selection (not just focus)
    if (categoryIndex >= 0 && categoryIndex < categories.length) {
      // Explicitly call the selection logic that would happen when clicking
      _onCategorySelected(categories[categoryIndex]);
    }

    // Update state immediately
    setState(() {
      _isNavbarFocused = true;
      _isCategoryFocused = true;

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

        // Make sure to unfocus channels first
        if (_channelsFocusNode.hasFocus) {
          _channelsFocusNode.unfocus();
        }

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

  void _toggleFullScreen({bool? value}) {
    if (!mounted) return;

    bool newValue = value ?? !_isFullScreen;
    print('Toggling fullscreen mode to: $newValue');

    setState(() {
      _isFullScreen = newValue;
      // Only show channel list when exiting fullscreen mode, not when entering
      if (!_isFullScreen) {
        _showChannelList =
            true; // Show channel list automatically when exiting fullscreen

        // Reset channel selection state to ensure it can be reselected immediately
        if (_selectedChannel != null) {
          final currentIndex =
              _filteredChannels.indexWhere((c) => c.id == _selectedChannel!.id);
          if (currentIndex >= 0) {
            _selectedChannelIndex = currentIndex;
          }
        }

        // Make sure categories are properly reinitialized when exiting fullscreen
        _resetCategoryFocusNodes();

        // Add a short delay to allow UI to update before scrolling
        Future.delayed(Duration(milliseconds: 100), () {
          if (mounted &&
              _channelListScrollController.hasClients &&
              _selectedChannelIndex >= 0) {
            // Center the selected channel in the list
            _centerSelectedChannel();
          }
        });
      } else {
        // When entering fullscreen mode, ensure channel list is hidden
        _showChannelList = false;
        _slideController.value = 0.0;

        // Force rebuild of fullscreen components to ensure key handlers are properly registered
        Future.delayed(Duration(milliseconds: 50), () {
          if (mounted) {
            setState(() {
              // Just trigger a rebuild
            });
          }
        });
      }
    });

    // If entering fullscreen mode, first hide the status bar
    if (newValue) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      // If exiting fullscreen mode, restore the UI
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );
    }
  }

  // Nouvelle méthode pour réinitialiser correctement les nœuds de focus des catégories
  void _resetCategoryFocusNodes() {
    final hotelProvider = Provider.of<HotelProvider>(context, listen: false);
    final categories = ['All', ...hotelProvider.bouquets.map((b) => b.name)];

    // Recréer tous les nœuds de focus des catégories
    _categoryFocusNodes.clear();

    for (int i = 0; i < categories.length; i++) {
      final category = categories[i];
      final focusNode =
          _focusService.registerFocusable('category_${category.toLowerCase()}');

      // Configurer le listener pour chaque nœud de focus
      focusNode.addListener(() {
        if (focusNode.hasFocus && mounted) {
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

      _categoryFocusNodes.add(focusNode);
    }

    // Trouver l'index de la catégorie actuelle
    final currentCategoryIndex = categories.indexOf(_selectedCategory);
    if (currentCategoryIndex >= 0) {
      _selectedCategoryIndex = currentCategoryIndex;
      _selectedNavbarItem = currentCategoryIndex + 1;
    }
  }

  void _hideChannelList() {
    print(
        'DEBUG [_hideChannelList] Current channel list state: $_showChannelList');
    if (_showChannelList) {
      setState(() {
        _showChannelList = false;
        _slideController.value = 0.0;
        _lastChannelListHideTime =
            DateTime.now(); // Record the time when list was hidden
      });
    }
    print('DEBUG [_hideChannelList] After hiding: $_showChannelList');
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Handle TV remote control key events
    if (event is KeyDownEvent) {
      print('Key down event: ${event.logicalKey}');
      if (event.logicalKey == LogicalKeyboardKey.goBack ||
          event.logicalKey == LogicalKeyboardKey.browserBack ||
          event.logicalKey == LogicalKeyboardKey.escape) {
        // If channel list is showing, hide it first
        if (_showChannelList) {
          setState(() {
            _showChannelList = false;
            _slideController.reverse();
          });

          // Store the time when we hide the channel list
          _lastChannelListHideTime = DateTime.now();
          return KeyEventResult.handled;
        }

        // If we're in full screen mode, first exit that
        if (_isFullScreen) {
          _toggleFullScreen();
          return KeyEventResult.handled;
        }

        // Make sure to clean up video controllers before exiting
        _cleanupControllers();

        // Go back to the home screen
        Navigator.of(context).pushReplacementNamed('/');
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
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
