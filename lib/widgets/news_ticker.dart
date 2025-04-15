import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/app_constants.dart';

class NewsTicker extends StatefulWidget {
  const NewsTicker({super.key});

  @override
  State<NewsTicker> createState() => _NewsTickerState();
}

class _NewsTickerState extends State<NewsTicker> {
  List<Map<String, dynamic>> _newsItems = [];
  int _currentIndex = 0;
  bool _isVisible = false;
  Timer? _newsTimer;
  Timer? _scrollTimer;
  Timer? _fetchTimer;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _fetchNews();
    
    // Fetch news every minute to keep it updated
    _fetchTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        _fetchNews();
      }
    });
  }

  @override
  void dispose() {
    _newsTimer?.cancel();
    _scrollTimer?.cancel();
    _fetchTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchNews() async {
    try {
      print('Fetching news...');
      final response = await http.get(Uri.parse('http://192.168.40.3/news.json'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Raw response data: $data');
        
        if (data is List) {
          final List<Map<String, dynamic>> newsData = data.map((item) {
            if (item is Map<String, dynamic>) {
              // Validate required fields
              if (item['content'] != null && item['id'] != null) {
                return item;
              }
            }
            print('Invalid news item format: $item');
            return null;
          }).whereType<Map<String, dynamic>>().toList();

          print('Parsed news items: ${newsData.length}');
          
          if (newsData.isNotEmpty) {
            setState(() {
              _newsItems = newsData;
              _isVisible = true;
              _currentIndex = 0;
            });
            print('News items loaded: ${_newsItems.length}');
            _startNewsRotation();
          } else {
            print('No valid news items found in the response');
          }
        } else {
          print('Invalid response format: expected a List but got ${data.runtimeType}');
        }
      } else {
        print('Error fetching news: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching news: $e');
    }
  }

  void _startNewsRotation() {
    if (_newsItems.isEmpty) {
      print('No news items to rotate');
      return;
    }

    print('Starting news rotation with ${_newsItems.length} items');
    // Start the continuous scrolling for the first news item
    _startScrolling();

    // Set up timer to rotate through news items every 10 seconds
    _newsTimer?.cancel();
    _newsTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        print('Timer triggered, preparing to rotate news');
        // Cancel any ongoing scrolling
        _scrollTimer?.cancel();
        
        final nextIndex = (_currentIndex + 1) % _newsItems.length;
        print('Rotating to next news item: $nextIndex of ${_newsItems.length}');
        
        setState(() {
          _currentIndex = nextIndex;
          // Reset scroll position immediately in setState
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });

        // Start scrolling after the state has been updated and widget rebuilt
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _startScrolling();
          }
        });
      }
    });
  }

  void _startScrolling() {
    if (_newsItems.isEmpty) return;

    final currentNews = _newsItems[_currentIndex]['content'] as String;
    print('Starting to scroll news item $_currentIndex: ${currentNews.substring(0, min(20, currentNews.length))}...');

    if (currentNews.length > 50) {
      _scrollTimer?.cancel();
      
      Future<void> scrollToEnd() async {
        if (!mounted) return;
        
        try {
          if (_scrollController.hasClients) {
            // Calculate scroll extent after layout
            await Future.delayed(const Duration(milliseconds: 50));
            if (!mounted || !_scrollController.hasClients) return;

            final maxExtent = _scrollController.position.maxScrollExtent;
            if (maxExtent <= 0) {
              print('No need to scroll - text fits in view');
              return;
            }

            print('Scrolling to maxExtent: $maxExtent');
            await _scrollController.animateTo(
              maxExtent,
              duration: Duration(seconds: currentNews.length ~/ 10),
              curve: Curves.linear,
            );
            
            if (mounted && _scrollController.hasClients) {
              print('Reached end, resetting to start');
              _scrollController.jumpTo(0);
              // Small delay before starting next scroll
              await Future.delayed(const Duration(milliseconds: 500));
              if (mounted) {
                scrollToEnd();
              }
            }
          } else {
            print('ScrollController has no clients');
          }
        } catch (e) {
          print('Error during scrolling: $e');
          // If there's an error, try to restart scrolling after a short delay
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 500), scrollToEnd);
          }
        }
      }

      // Wait for the widget to be built and have proper dimensions
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          scrollToEnd();
        }
      });
    } else {
      print('Text too short to scroll');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _newsItems.isEmpty) return const SizedBox.shrink();

    final currentNews = _newsItems[_currentIndex]['content'] as String;

    return ErrorBoundary(
      child: AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            border: Border(
              top: BorderSide(
                color: AppColors.primary.withOpacity(0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/ic_new-playstore.png',
                      height: 20,
                      width: 20,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'BREAKING NEWS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    // Reset scroll if we hit the end
                    if (notification is ScrollEndNotification) {
                      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent) {
                        _scrollController.jumpTo(0);
                      }
                    }
                    return true;
                  },
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 50), // Add space for smoother looping
                      child: Text(
                        currentNews,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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
    );
  }
}

class ErrorBoundary extends StatelessWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      print('Error in NewsTicker: ${details.exception}');
      return const SizedBox.shrink();
    };
    return child;
  }
}
