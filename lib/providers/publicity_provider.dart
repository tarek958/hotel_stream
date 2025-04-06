import 'package:flutter/foundation.dart';
import '../models/publicity_video_model.dart';
import '../services/publicity_service.dart';

class PublicityProvider with ChangeNotifier {
  final PublicityService _publicityService = PublicityService();
  List<PublicityVideo> _videos = [];
  bool _isLoading = false;
  String? _error;
  int _currentVideoIndex = 0;
  bool _isInitialized = false;

  List<PublicityVideo> get videos => _videos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentVideoIndex => _currentVideoIndex;
  bool get isInitialized => _isInitialized;
  PublicityVideo? get currentVideo =>
      _videos.isNotEmpty ? _videos[_currentVideoIndex] : null;

  Future<void> loadVideos() async {
    if (_isInitialized) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _videos = await _publicityService.getPublicityVideos();
      _error = null;
    } catch (e) {
      _error = 'Failed to load videos';
      _videos = []; // Clear videos on error
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<String?> getCurrentVideoPath() async {
    if (_videos.isEmpty) return null;

    final video = _videos[_currentVideoIndex];
    try {
      return await _publicityService.downloadAndCacheVideo(video);
    } catch (e) {
      _error = 'Failed to load video';
      notifyListeners();
      return null;
    }
  }

  void nextVideo() {
    if (_videos.isEmpty) return;
    _currentVideoIndex = (_currentVideoIndex + 1) % _videos.length;
    notifyListeners();
  }

  Future<void> clearCache() async {
    await _publicityService.clearCache();
    _videos = [];
    _currentVideoIndex = 0;
    _isInitialized = false;
    notifyListeners();
  }
}
