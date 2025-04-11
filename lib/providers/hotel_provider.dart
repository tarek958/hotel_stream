import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/channel_model.dart';
import '../models/channel_response.dart';
import '../services/channel_service.dart';
import '../utils/connectivity_util.dart';

class HotelProvider with ChangeNotifier {
  final ChannelService _channelService = ChannelService();
  List<Channel> _channels = [];
  List<Bouquet> _bouquets = [];
  bool _isLoading = false;
  bool _isOffline = false;
  String? _error;
  String _hotelName = '';
  String _currentLanguage = 'en';
  int _maxRetries = 5;
  int _currentRetry = 0;
  Timer? _retryTimer;
  bool _isChannelsLoaded = false;

  List<Channel> get channels => _channels;
  List<Bouquet> get bouquets => _bouquets;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String? get error => _error;
  String get hotelName => _hotelName;
  String get currentLanguage => _currentLanguage;
  bool get isChannelsLoaded => _isChannelsLoaded;

  // File paths for local data
  Future<String> get _localChannelsFilePath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/channels.json';
  }

  // Check if local data exists and has content
  Future<bool> hasLocalChannelData() async {
    try {
      final localPath = await _localChannelsFilePath;
      final localFile = File(localPath);

      if (!localFile.existsSync()) {
        return false;
      }

      final content = await localFile.readAsString();
      final data = json.decode(content);

      // Check if the channels array has content
      return (data['channels'] as List).isNotEmpty;
    } catch (e) {
      print('Error checking local data: $e');
      return false;
    }
  }

  // Initialize the local file from assets if needed
  Future<void> initializeLocalChannelsFile() async {
    try {
      final localPath = await _localChannelsFilePath;
      final localFile = File(localPath);

      if (!localFile.existsSync()) {
        // Create directory if needed
        final directory = await getApplicationDocumentsDirectory();
        await Directory(directory.path).create(recursive: true);

        // Copy the empty template from assets
        final assetData =
            await rootBundle.loadString('assets/json/channels.json');
        await localFile.writeAsString(assetData);
        print('Created local channels file from assets template');
      }
    } catch (e) {
      print('Error initializing local channels file: $e');
    }
  }

  // Load channels from local storage
  Future<bool> loadChannelsFromLocalStorage() async {
    try {
      print('Loading channels from local storage');
      await initializeLocalChannelsFile();

      final localPath = await _localChannelsFilePath;
      final localFile = File(localPath);

      if (localFile.existsSync()) {
        final content = await localFile.readAsString();
        final data = json.decode(content);

        if ((data['channels'] as List).isNotEmpty) {
          _channels = (data['channels'] as List)
              .map((item) => Channel.fromJson(item as Map<String, dynamic>))
              .toList();

          _bouquets = (data['bouquets'] as List)
              .map((item) => Bouquet.fromJson(item as Map<String, dynamic>))
              .toList();

          _isChannelsLoaded = true;
          notifyListeners();
          print(
              'Successfully loaded ${_channels.length} channels from local storage');
          return true;
        }
      }
      print('No valid channels found in local storage');
      return false;
    } catch (e) {
      print('Error loading local data: $e');
      return false;
    }
  }

  // Save channels to local storage
  Future<void> saveChannelsToLocalStorage() async {
    try {
      print('Saving channels to local storage');
      await initializeLocalChannelsFile();

      final localPath = await _localChannelsFilePath;
      final localFile = File(localPath);

      final data = {
        'channels': _channels.map((channel) => channel.toJson()).toList(),
        'bouquets': _bouquets.map((bouquet) => bouquet.toJson()).toList()
      };

      final jsonContent = json.encode(data);
      await localFile.writeAsString(jsonContent);

      print('Saved ${_channels.length} channels to local storage');
    } catch (e) {
      print('Error saving data to local storage: $e');
    }
  }

  Future<void> loadHotelInfo(String hotelId) async {
    _isLoading = true;
    notifyListeners();

    try {
      // For now, we'll just set a default hotel name
      // TODO: Implement actual hotel info fetching
      _hotelName = 'One Resort';
    } catch (e) {
      _error = 'Failed to load hotel info: $e';
      print(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadChannelsAndCategories() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // First try to load from local storage (regardless of connectivity)
      await initializeLocalChannelsFile();
      final hasLocalData = await hasLocalChannelData();
      final bool localDataLoaded = false;

      if (hasLocalData) {
        print('Found local channel data, loading from storage');
        final loaded = await loadChannelsFromLocalStorage();
        if (loaded) {
          _isLoading = false;
          _isChannelsLoaded = true;
          _isOffline = false;
          notifyListeners();

          // Check internet connectivity before trying to refresh
          if (await ConnectivityUtil.isConnected()) {
            // Optionally refresh in the background to check for updates
            _refreshChannelsInBackground();
          } else {
            print('No internet connection, using cached channel data');
            _isOffline = true;
            // Don't show error since we have local data
            notifyListeners();
          }
          return;
        }
      } else {
        print('No local channel data found or it was empty');
      }

      // Check connectivity before attempting API call
      if (!await ConnectivityUtil.isConnected()) {
        print('No internet connection and no local data');
        _isLoading = false;
        _isOffline = true;
        _error =
            'No internet connection. Please connect to the internet and try again.';
        notifyListeners();
        return;
      }

      // If no local data or loading failed, fetch from API
      await _fetchChannelsAndCategories();
    } catch (e) {
      print('Error in loadChannelsAndCategories: $e');

      // Check if we have local data to fall back to
      final hasLocalData = await hasLocalChannelData();
      if (hasLocalData) {
        print('Server error, falling back to local data');
        final loaded = await loadChannelsFromLocalStorage();
        if (loaded) {
          _isLoading = false;
          _isChannelsLoaded = true;
          _isOffline = true;
          _error = 'Could not connect to server. Using cached data.';
          notifyListeners();
          return;
        }
      }

      // No local data to fall back to
      _error = 'Failed to load channels: $e';
      _isLoading = false;
      _isOffline = true;
      notifyListeners();
    }
  }

  // Refresh channels in background without showing loading state
  Future<void> _refreshChannelsInBackground() async {
    if (!await ConnectivityUtil.isConnected()) {
      print('Skipping background refresh - no internet connection');
      return;
    }

    try {
      final response = await _channelService.getChannelsAndCategories();

      // Check if there are any changes in the channel list
      final newChannelIds = response.channels.map((c) => c.id).toSet();
      final oldChannelIds = _channels.map((c) => c.id).toSet();

      final hasChanges = newChannelIds.length != oldChannelIds.length ||
          !newChannelIds.every((id) => oldChannelIds.contains(id));

      if (hasChanges) {
        print('Channel list has changed, updating local storage');
        _channels = response.channels;
        _bouquets = response.categories;
        await saveChannelsToLocalStorage();
        notifyListeners();
      } else {
        print('No changes in channel list detected');
      }
    } catch (e) {
      print('Background refresh failed: $e');
      // Don't show errors for background refresh
    }
  }

  Future<void> _fetchChannelsAndCategories() async {
    if (!await ConnectivityUtil.isConnected()) {
      _isLoading = false;
      _isOffline = true;
      _error = 'No internet connection';

      // Try to load from local storage as fallback
      final hasLocalData = await hasLocalChannelData();
      if (hasLocalData) {
        await loadChannelsFromLocalStorage();
        _error = 'No internet connection. Using cached data.';
      }

      notifyListeners();
      return;
    }

    try {
      print('Fetching channels from API (try #${_currentRetry + 1})');
      _isLoading = true;
      notifyListeners();

      // Use the existing channel service to keep the app's API consistency
      final response = await _channelService.getChannelsAndCategories();

      _channels = response.channels;
      _bouquets = response.categories;

      // Successfully loaded, save to local storage
      await saveChannelsToLocalStorage();

      _isChannelsLoaded = true;
      _isLoading = false;
      _isOffline = false;
      _error = null;
      _cancelRetryTimer();
      notifyListeners();
    } catch (e) {
      print('Error loading channels: $e');

      // Check if we have local data to fall back to
      final hasLocalData = await hasLocalChannelData();
      if (hasLocalData) {
        print('Server error, falling back to local data');
        final loaded = await loadChannelsFromLocalStorage();
        if (loaded) {
          _isLoading = false;
          _isChannelsLoaded = true;
          _isOffline = true;
          _error = 'Could not connect to server. Using cached data.';
          notifyListeners();
          return;
        }
      }

      // If no local data or failed to load it, continue with retry logic
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    _isLoading = false;
    _isOffline = true;
    _error = 'Failed to load channels. Retrying...';

    if (_currentRetry < _maxRetries) {
      _currentRetry++;

      _cancelRetryTimer();
      _retryTimer = Timer(const Duration(seconds: 5), () async {
        // Check connectivity before retry
        if (await ConnectivityUtil.isConnected()) {
          _fetchChannelsAndCategories();
        } else {
          // Try to load from local storage one last time
          final hasLocalData = await hasLocalChannelData();
          if (hasLocalData) {
            await loadChannelsFromLocalStorage();
            _error = 'No internet connection. Using cached data.';
            _isOffline = true;
            notifyListeners();
            _cancelRetryTimer();
          } else {
            // Schedule another retry if we have retries left
            _scheduleRetry();
          }
        }
      });

      notifyListeners();
    } else {
      _isOffline = true;
      _error = 'Failed to load channels after multiple attempts.';

      // One final attempt to load from local storage
      _tryLoadFromLocalAsLastResort();

      _cancelRetryTimer();
      notifyListeners();
    }
  }

  // Try to load from local storage as a last resort after all retries fail
  Future<void> _tryLoadFromLocalAsLastResort() async {
    final hasLocalData = await hasLocalChannelData();
    if (hasLocalData) {
      final loaded = await loadChannelsFromLocalStorage();
      if (loaded) {
        _error = 'Could not connect to server. Using cached data.';
        _isOffline = true;
      }
    }
  }

  void _cancelRetryTimer() {
    if (_retryTimer != null && _retryTimer!.isActive) {
      _retryTimer!.cancel();
      _retryTimer = null;
    }
    _currentRetry = 0;
  }

  Future<void> refreshData() async {
    if (await ConnectivityUtil.isConnected()) {
      _isOffline = false;
      _error = null;
      notifyListeners();
      await _fetchChannelsAndCategories();
    } else {
      _isOffline = true;
      _error = 'offline_no_connection';
      notifyListeners();
    }
  }

  void setCurrentLanguage(String languageCode) {
    _currentLanguage = languageCode;
    notifyListeners();
  }

  Channel? getChannelById(String id) {
    try {
      return _channels.firstWhere((channel) => channel.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Channel> getChannelsByCategory(String categoryId) {
    if (categoryId == 'all') {
      return _channels;
    }
    return _channels.where((channel) => channel.categ == categoryId).toList();
  }

  @override
  void dispose() {
    _cancelRetryTimer();
    super.dispose();
  }
}
