import 'dart:async';
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
  String? _currentNews;
  bool _isVisible = false;
  Timer? _timer;
  final ScrollController _scrollController = ScrollController();
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchNews() async {
    try {
      final response =
          await http.get(Uri.parse('http://196.203.12.163:2509/news.json'));
      if (response.statusCode == 200) {
        final List<dynamic> newsData = json.decode(response.body);
        if (newsData.isNotEmpty) {
          setState(() {
            _currentNews = newsData[0]['content'] as String;
            _isVisible = true;
          });
          _startScrolling();

          // Hide after 10 seconds
          _timer = Timer(const Duration(seconds: 10), () {
            if (mounted) {
              setState(() {
                _isVisible = false;
              });
            }
          });
        }
      }
    } catch (e) {
      print('Error fetching news: $e');
    }
  }

  void _startScrolling() {
    if (_currentNews == null) return;

    if (_currentNews!.length > 50) {
      setState(() {
        _isScrolling = true;
      });
      _scrollController
          .animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(seconds: _currentNews!.length ~/ 10),
        curve: Curves.linear,
      )
          .then((_) {
        setState(() {
          _isScrolling = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible || _currentNews == null) return const SizedBox.shrink();

    return AnimatedPositioned(
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
              child: const Text(
                'BREAKING NEWS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Text(
                  _currentNews!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
