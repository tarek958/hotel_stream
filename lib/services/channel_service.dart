import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel_model.dart';
import '../models/channel_response.dart';
import '../models/channel_cache.dart';
import '../utils/connectivity_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ChannelService {
  static const String baseUrl = 'http://51.83.97.190/rmd.php';
  static const String _cacheFileName = 'channel_cache.json';
  static const Duration _cacheValidDuration = Duration(hours: 24);

  Future<ChannelResponse> getChannelsAndCategories() async {
    try {
      final isConnected = await ConnectivityUtil.isConnected();
      
      // Try to get cached data first
      final cachedData = await _readFromCache();

      if (!isConnected) {
        if (cachedData != null) {
          print('Using cached data (offline)');
          final response = cachedData.data;
          response.isOffline = true;
          return response;
        }
        throw Exception('offline_no_cache');
      }

      // If we're online and have valid cache, check for updates
      if (cachedData != null && _isCacheValid(cachedData)) {
        final hasUpdate = await _checkForUpdates(cachedData.version);
        if (!hasUpdate) {
          print('Using cached data');
          return cachedData.data;
        }
      }

      // If no valid cache or updates available, fetch from server
      print('Fetching from server');
      final response = await http.get(Uri.parse(baseUrl));
      
      if (response.statusCode == 200) {
        final channelResponse = ChannelResponse.fromJson(json.decode(response.body));
        await _saveToCache(channelResponse);
        return channelResponse;
      }

      // If server request fails and we have cached data, use it
      if (cachedData != null) {
        print('Using expired cache due to server error');
        final response = cachedData.data;
        response.isOffline = true;
        return response;
      }

      throw Exception('server_error');
    } catch (e) {
      print('Error in getChannelsAndCategories: $e');
      if (e.toString().contains('offline_no_cache')) {
        throw Exception('offline_no_cache');
      } else if (e.toString().contains('server_error')) {
        throw Exception('server_error');
      }
      throw Exception('Failed to load channels');
    }
  }

  Future<bool> _checkForUpdates(String currentVersion) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl?version=$currentVersion'),
        headers: {'If-None-Match': currentVersion},
      );
      return response.statusCode != 304;
    } catch (e) {
      print('Error checking for updates: $e');
      return false;
    }
  }

  Future<void> _saveToCache(ChannelResponse data) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/$_cacheFileName');
      
      final cache = ChannelCache(
        data: data,
        version: DateTime.now().millisecondsSinceEpoch.toString(),
        lastUpdated: DateTime.now(),
      );

      await cacheFile.writeAsString(ChannelCache.encode(cache));
      print('Cache saved successfully');
    } catch (e) {
      print('Error saving cache: $e');
    }
  }

  Future<ChannelCache?> _readFromCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/$_cacheFileName');

      if (await cacheFile.exists()) {
        final jsonString = await cacheFile.readAsString();
        return ChannelCache.decode(jsonString);
      }
    } catch (e) {
      print('Error reading cache: $e');
    }
    return null;
  }

  bool _isCacheValid(ChannelCache cache) {
    final now = DateTime.now();
    return now.difference(cache.lastUpdated) < _cacheValidDuration;
  }

  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  Future<void> clearLocalData() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final cacheFile = File('${cacheDir.path}/$_cacheFileName');
      if (await cacheFile.exists()) {
        await cacheFile.delete();
        print('Cache cleared successfully');
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}
