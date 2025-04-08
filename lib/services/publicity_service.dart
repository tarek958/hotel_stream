import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/publicity_video_model.dart';

class PublicityService {
  static const String API_URL = 'http://192.168.40.3/publicity.json';
  static const String CACHE_KEY = 'publicity_videos';
  static const Duration CACHE_DURATION =
      Duration(minutes: 15); // Reduced to ensure fresh data

  Future<List<PublicityVideo>> getPublicityVideos() async {
    try {
      // Print request information for debugging
      print('Fetching publicity videos from: $API_URL');

      // Try to use direct HTTP for better cross-platform compatibility
      final response = await http.get(Uri.parse(API_URL), headers: {
        'User-Agent': 'HotelStream/1.0',
        'Connection': 'Keep-Alive',
        'Cache-Control': 'no-cache'
      });

      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Print raw response for debugging
        print('Raw response body: ${response.body}');

        if (response.body.isEmpty) {
          print('Received empty response body');
          return [];
        }

        try {
          // Try to decode as JSON array
          final dynamic jsonData = json.decode(response.body);
          print('Decoded JSON: $jsonData');

          List<dynamic> jsonList;
          // Handle both array and single object responses
          if (jsonData is List) {
            jsonList = jsonData;
          } else if (jsonData is Map) {
            // If it's a single object, wrap it in a list
            jsonList = [jsonData];
          } else {
            throw Exception(
                'Unexpected response format - not a List or Map: ${jsonData.runtimeType}');
          }

          print('Processing ${jsonList.length} videos from API');

          // Map each JSON object to a PublicityVideo
          final videos = jsonList
              .map((json) {
                try {
                  return PublicityVideo.fromJson(json);
                } catch (e) {
                  print('Error parsing video: $e');
                  print('Problematic JSON: $json');
                  // Return null for failed items - we'll filter these out below
                  return null;
                }
              })
              .where((video) => video != null)
              .cast<PublicityVideo>()
              .toList();

          print(
              'Successfully parsed ${videos.length} of ${jsonList.length} videos');

          // Update cache
          _updateCache(jsonList);

          return videos;
        } catch (parseError) {
          print('Error parsing JSON: $parseError');
          // Try to parse with more lenient approach or fall back to cache
          return _loadFromCache();
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        // If API call fails, try to use cached data
        return _loadFromCache();
      }
    } catch (e) {
      print('Failed to load publicity videos: $e');
      // If offline or error, return cached data
      return _loadFromCache();
    }
  }

  Future<List<PublicityVideo>> _loadFromCache() async {
    try {
      print('Attempting to load videos from cache');
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(CACHE_KEY);

      if (cachedData != null) {
        print('Found cached data');
        final List<dynamic> jsonList = json.decode(cachedData);
        return jsonList.map((json) => PublicityVideo.fromJson(json)).toList();
      }
      print('No cache found');
    } catch (e) {
      print('Error loading from cache: $e');
    }

    return []; // Return empty list if no cache or error
  }

  Future<void> _updateCache(List<dynamic> jsonList) async {
    try {
      print('Updating cache with ${jsonList.length} videos');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(CACHE_KEY, json.encode(jsonList));
      await prefs.setInt(
          '${CACHE_KEY}_timestamp', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      print('Error updating cache: $e');
    }
  }

  Future<String> downloadAndCacheVideo(PublicityVideo video) async {
    if (video.localPath != null) {
      final file = File(video.localPath!);
      if (await file.exists()) {
        return video.localPath!;
      }
    }

    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${video.id}.mp4';
    final filePath = '${directory.path}/publicity_videos/$fileName';
    final file = File(filePath);

    // Create directory if it doesn't exist
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    try {
      final response = await http.get(Uri.parse(video.videoUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        video.localPath = filePath;

        // Update cache with new local path
        final prefs = await SharedPreferences.getInstance();
        final cachedData = prefs.getString(CACHE_KEY);
        if (cachedData != null) {
          final List<dynamic> jsonList = json.decode(cachedData);
          final updatedList = jsonList.map((json) {
            if (json['id'] == video.id) {
              return video.toJson();
            }
            return json;
          }).toList();
          await prefs.setString(CACHE_KEY, json.encode(updatedList));
        }

        return filePath;
      } else {
        throw Exception('Failed to download video');
      }
    } catch (e) {
      if (await file.exists()) {
        await file.delete();
      }
      rethrow;
    }
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(CACHE_KEY);
    await prefs.remove('${CACHE_KEY}_timestamp');

    final directory = await getApplicationDocumentsDirectory();
    final videosDir = Directory('${directory.path}/publicity_videos');
    if (await videosDir.exists()) {
      await videosDir.delete(recursive: true);
    }
  }
}
