import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../widgets/language_selector.dart';
import '../l10n/app_localizations.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  String _selectedCategory = 'All';
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  Map<String, dynamic>? _selectedChannel;

  final List<Map<String, dynamic>> channels = [
    {
      'name': 'Essaida TV',
      'category': 'Entertainment',
      'url': 'https://essaidatv.dextream.com/hls/stream/index.m3u8',
      'description': 'Tunisian entertainment channel featuring local content',
      'thumbnail': 'https://upload.wikimedia.org/wikipedia/commons/8/8e/Logo_essaida.png',
      'isLive': true,
    },
    {
      'name': 'JAWHARA TV',
      'category': 'Entertainment',
      'url': 'https://streaming.toutech.net/live/jtv/index.m3u8',
      'description': 'Live entertainment and cultural programming [720p]',
      'thumbnail': 'https://www.jawharafm.net/ar/static/fr/image/jpg/logo-jawhara.jpg',
      'isLive': true,
    },
    {
      'name': 'Mosaïque FM',
      'category': 'News',
      'url': 'https://webcam.mosaiquefm.net:1936/mosatv/studio/playlist.m3u8',
      'description': 'News and current affairs from Tunisia [480p]',
      'thumbnail': 'https://www.mosaiquefm.net/images/front2020/logoMosaique.png',
      'isLive': true,
    },
    {
      'name': 'Nessma',
      'category': 'General',
      'url': 'https://shls-live-ak.akamaized.net/out/v1/119ae95bbc91462093918a7c6ba11415/index.m3u8',
      'description': 'General entertainment and news channel [1080p]',
      'thumbnail': 'https://upload.wikimedia.org/wikipedia/commons/7/76/Logo_nessma.png',
      'isLive': true,
    },
    {
      'name': 'Sahel TV',
      'category': 'Regional',
      'url': 'http://142.44.214.231:1935/saheltv/myStream/playlist.m3u8',
      'description': 'Regional television channel from Tunisia [720p]',
      'thumbnail': 'https://saheltv.tn/wp-content/uploads/2018/01/saheltv_logo.png',
      'isLive': true,
    },
    {
      'name': 'Tunisie Immobilier TV',
      'category': 'Business',
      'url': 'https://5ac31d8a4c9af.streamlock.net/tunimmob/myStream/playlist.m3u8',
      'description': 'Real estate and property channel [720p]',
      'thumbnail': 'https://tunisieimmobiliertv.net/wp-content/uploads/2019/03/logo-tv.png',
      'isLive': true,
    },
    {
      'name': 'Watania 1',
      'category': 'National',
      'url': 'http://live.watania1.tn:1935/live/watanya1.stream/playlist.m3u8',
      'description': 'National public television channel [576p]',
      'thumbnail': 'https://upload.wikimedia.org/wikipedia/commons/6/65/Watania1.png',
      'isLive': true,
    },
    {
      'name': 'Watania 2',
      'category': 'National',
      'url': 'http://live.watania2.tn:1935/live/watanya2.stream/playlist.m3u8',
      'description': 'Second national public television channel [360p]',
      'thumbnail': 'https://upload.wikimedia.org/wikipedia/commons/7/72/Logo_Watania2.png',
      'isLive': true,
    },
    {
      'name': 'Zitouna TV',
      'category': 'Religious',
      'url': 'https://video1.getstreamhosting.com:1936/8320/8320/playlist.m3u8',
      'description': 'Religious and cultural programming [480p]',
      'thumbnail': 'https://upload.wikimedia.org/wikipedia/fr/2/2c/Logo_zitouna.jpg',
      'isLive': true,
    }
  ];

  List<Map<String, dynamic>> filteredChannels = [];

  @override
  void initState() {
    super.initState();
    filteredChannels = channels;
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  void _initializePlayer(String channelName) {
    if (_videoPlayerController != null) {
      _videoPlayerController!.dispose();
      _chewieController?.dispose();
    }

    final selectedChannel = channels.firstWhere((channel) => channel['name'] == channelName);
    _videoPlayerController = VideoPlayerController.network(
      selectedChannel['url'],
    )..initialize().then((_) {
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: true,
          looping: true,
          aspectRatio: 16 / 9,
          allowMuting: true,
          allowPlaybackSpeedChanging: false,
          placeholder: Container(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          ),
          materialProgressColors: ChewieProgressColors(
            playedColor: AppColors.primary,
            handleColor: AppColors.primary,
            backgroundColor: Colors.grey[800]!,
            bufferedColor: Colors.grey[600]!,
          ),
        );
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width > 900;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
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
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['All', ...channels.map((channel) => channel['category'] as String).toSet()];
    
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedCategory == category;
          
          String getLocalizedCategory(String category) {
            switch (category.toLowerCase()) {
              case 'all':
                return AppLocalizations.of(context)!.all;
              case 'entertainment':
                return AppLocalizations.of(context)!.entertainment;
              case 'news':
                return AppLocalizations.of(context)!.news;
              case 'general':
                return AppLocalizations.of(context)!.general;
              case 'regional':
                return AppLocalizations.of(context)!.regional;
              case 'business':
                return AppLocalizations.of(context)!.business;
              case 'national':
                return AppLocalizations.of(context)!.national;
              case 'religious':
                return AppLocalizations.of(context)!.religious;
              case 'sports':
                return AppLocalizations.of(context)!.sports;
              case 'culture':
                return AppLocalizations.of(context)!.culture;
              default:
                return category;
            }
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.7),
                              AppColors.accent.withOpacity(0.7),
                            ],
                          )
                        : null,
                    color: isSelected ? null : AppColors.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.2)
                          : AppColors.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedCategory = category;
                          if (_selectedCategory == 'All') {
                            filteredChannels = channels;
                          } else {
                            filteredChannels = channels
                                .where((channel) =>
                                    channel['category'] == _selectedCategory)
                                .toList();
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Text(
                          getLocalizedCategory(category),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : AppColors.text.withOpacity(0.7),
                            fontSize: 15,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            letterSpacing: 0.5,
                          ),
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
  }

  Widget _buildChannelsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredChannels.length,
      itemBuilder: (context, index) {
        final channel = filteredChannels[index];
        final isSelected = _selectedChannel == channel;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
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
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedChannel = channel;
                        _initializePlayer(channel['name']);
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Channel thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 80,
                              height: 60,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                              ),
                              child: Image.network(
                                channel['thumbnail'],
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.tv,
                                  color: AppColors.primary.withOpacity(0.7),
                                  size: 30,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Channel info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  channel['name'],
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.text
                                        : AppColors.text.withOpacity(0.9),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  channel['category'],
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Live indicator
                          if (channel['isLive'])
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.red.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    AppLocalizations.of(context)!.live,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
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
          ),
        );
      },
    );
  }

  Widget _buildVideoPlayerSection(bool isLandscape) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_chewieController != null && _selectedChannel != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Chewie(controller: _chewieController!),
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
                          size: 60,
                          color: AppColors.primary.withOpacity(0.5),
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
                          Text(
                            _selectedChannel!['name'],
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
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
                              _selectedChannel!['category'],
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
                        _selectedChannel!['description'],
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
    );
  }
}
