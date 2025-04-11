import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import '../models/publicity_video_model.dart';
import '../services/publicity_service.dart';
import '../utils/connectivity_util.dart';

class PublicityProvider with ChangeNotifier {
  final PublicityService _publicityService = PublicityService();
  List<PublicityVideo> _videos = [];
  bool _isLoading = false;
  String? _error;
  int _currentVideoIndex = 0;
  bool _isInitialized = false;
  bool _isOffline = false;

  List<PublicityVideo> get videos => _videos;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;
  int get currentVideoIndex => _currentVideoIndex;
  bool get isInitialized => _isInitialized;
  PublicityVideo? get currentVideo =>
      _videos.isNotEmpty ? _videos[_currentVideoIndex] : null;

  // File path for local publicity data
  Future<String> get _localPublicityFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/publicity.json';
  }

  // Check if local publicity data exists and has videos
  Future<bool> hasLocalPublicityData() async {
    try {
      final localPath = await _localPublicityFilePath;
      final localFile = File(localPath);

      if (!localFile.existsSync()) {
        return false;
      }

      final content = await localFile.readAsString();
      final data = json.decode(content);

      // Check if the videos array has content
      return (data['videos'] as List).isNotEmpty;
    } catch (e) {
      print('Error checking local publicity data: $e');
      return false;
    }
  }

  // Initialize local file from assets template if needed
  Future<void> initializeLocalPublicityFile() async {
    try {
      final localPath = await _localPublicityFilePath;
      final localFile = File(localPath);

      if (!localFile.existsSync()) {
        // Create directory if needed
        final directory = await getApplicationDocumentsDirectory();
        await Directory(directory.path).create(recursive: true);

        // Copy empty template from assets
        final assetData =
            await rootBundle.loadString('assets/json/publicity.json');
        await localFile.writeAsString(assetData);
        print('Created local publicity file from assets template');
      }
    } catch (e) {
      print('Error initializing local publicity file: $e');
    }
  }

  // Load publicity videos from local storage
  Future<bool> loadVideosFromLocalStorage() async {
    try {
      print('Loading publicity videos from local storage');
      await initializeLocalPublicityFile();

      final localPath = await _localPublicityFilePath;
      final localFile = File(localPath);

      if (localFile.existsSync()) {
        final content = await localFile.readAsString();
        final data = json.decode(content);

        if ((data['videos'] as List).isNotEmpty) {
          _videos = (data['videos'] as List)
              .map((item) =>
                  PublicityVideo.fromJson(item as Map<String, dynamic>))
              .toList();

          _isInitialized = true;
          _isOffline = true;
          notifyListeners();
          print(
              'Successfully loaded ${_videos.length} publicity videos from local storage');
          return true;
        }
      }
      print('No valid publicity videos found in local storage');
      return false;
    } catch (e) {
      print('Error loading local publicity data: $e');
      return false;
    }
  }

  // Save videos to local storage
  Future<void> saveVideosToLocalStorage() async {
    try {
      print('Saving publicity videos to local storage');
      await initializeLocalPublicityFile();

      final localPath = await _localPublicityFilePath;
      final localFile = File(localPath);

      final data = {
        'videos': _videos.map((video) => video.toJson()).toList(),
      };

      final jsonContent = json.encode(data);
      await localFile.writeAsString(jsonContent);

      print('Saved ${_videos.length} publicity videos to local storage');
    } catch (e) {
      print('Error saving publicity data to local storage: $e');
    }
  }

  Future<void> loadVideos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First try to load from local storage
      await initializeLocalPublicityFile();
      final hasLocalData = await hasLocalPublicityData();

      if (hasLocalData) {
        print('Found local publicity data, loading from storage');
        final loaded = await loadVideosFromLocalStorage();
        if (loaded) {
          _isLoading = false;
          _isInitialized = true;
          _isOffline = true;
          notifyListeners();

          // Only try to refresh from server if we have connectivity
          if (await ConnectivityUtil.isConnected()) {
            _refreshVideosInBackground();
          } else {
            print('Using cached publicity videos (offline mode)');
          }
          return;
        }
      }

      // Check connectivity before attempting API call
      if (!await ConnectivityUtil.isConnected()) {
        print('No internet connection and no local publicity data');
        _isLoading = false;
        _isOffline = true;
        _error = 'No internet connection';
        notifyListeners();
        return;
      }

      // If no local data or loading failed, fetch from API
      await _fetchVideosFromServer();
    } catch (e) {
      print('Error in loadVideos: $e');

      // Check if we have local data to fall back to
      final hasLocalData = await hasLocalPublicityData();
      if (hasLocalData) {
        print(
            'Error fetching from server, falling back to local publicity data');
        final loaded = await loadVideosFromLocalStorage();
        if (loaded) {
          _isLoading = false;
          _isInitialized = true;
          _isOffline = true;
          // Don't set an error if we have local data
          notifyListeners();
          return;
        }
      }

      // No local data to fall back to
      _error = 'Failed to load videos: $e';
      _videos = []; // Clear videos on error
      _isLoading = false;
      _isOffline = true;
      notifyListeners();
    }
  }

  // Refresh videos in background without showing loading state
  Future<void> _refreshVideosInBackground() async {
    try {
      final freshVideos = await _publicityService.getPublicityVideos();

      // Check if there are any changes
      final newVideoIds = freshVideos.map((v) => v.id).toSet();
      final oldVideoIds = _videos.map((v) => v.id).toSet();

      final hasChanges = newVideoIds.length != oldVideoIds.length ||
          !newVideoIds.every((id) => oldVideoIds.contains(id));

      if (hasChanges) {
        print('Publicity video list has changed, updating local storage');
        _videos = freshVideos;
        await saveVideosToLocalStorage();
        _isOffline = false;
        notifyListeners();
      } else {
        print('No changes in publicity video list detected');
      }
    } catch (e) {
      print('Background publicity refresh failed: $e');
      // Don't show errors for background refresh
    }
  }

  Future<void> _fetchVideosFromServer() async {
    try {
      _videos = await _publicityService.getPublicityVideos();

      // Successfully loaded, save to local storage
      await saveVideosToLocalStorage();

      _error = null;
      _isOffline = false;
      _isInitialized = true;
    } catch (e) {
      print('Error fetching videos from server: $e');

      // Check if we can fall back to local data
      final hasLocalData = await hasLocalPublicityData();
      if (hasLocalData) {
        await loadVideosFromLocalStorage();
        _error = 'Could not connect to server. Using cached videos.';
      } else {
        _error = 'Failed to load videos: $e';
        _videos = []; // Clear videos on error
      }
    } finally {
      _isLoading = false;
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

  Future<void> navigateWithDelay() async {
    if (_videos.isEmpty) return;
    await Future.delayed(const Duration(milliseconds: 500)); // Add 500ms delay
    _currentVideoIndex = (_currentVideoIndex + 1) % _videos.length;
    notifyListeners();
  }

  Future<void> clearCache() async {
    await _publicityService.clearCache();

    // Also clear the local JSON file
    try {
      final localPath = await _localPublicityFilePath;
      final localFile = File(localPath);
      if (localFile.existsSync()) {
        await localFile.delete();
      }
      await initializeLocalPublicityFile();
    } catch (e) {
      print('Error clearing local publicity cache: $e');
    }

    _videos = [];
    _currentVideoIndex = 0;
    _isInitialized = false;
    _isOffline = false;
    notifyListeners();
  }
}
