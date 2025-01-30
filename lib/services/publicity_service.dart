import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/publicity_video_model.dart';

class PublicityService {
  static const String API_URL = 'http://51.83.97.190/publicity.json';
  static const String CACHE_KEY = 'publicity_videos';
  static const Duration CACHE_DURATION = Duration(hours: 24);

  Future<List<PublicityVideo>> getPublicityVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString(CACHE_KEY);
    final cacheTimestamp = prefs.getInt('${CACHE_KEY}_timestamp');

    // Check if cache is valid
    if (cachedData != null && cacheTimestamp != null) {
      final cacheAge = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(cacheTimestamp),
      );
      if (cacheAge < CACHE_DURATION) {
        final List<dynamic> jsonList = json.decode(cachedData);
        return jsonList.map((json) => PublicityVideo.fromJson(json)).toList();
      }
    }

    try {
      // Fetch fresh data from API
      final response = await http.get(Uri.parse(API_URL));
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final videos =
            jsonList.map((json) => PublicityVideo.fromJson(json)).toList();

        // Update cache
        await prefs.setString(CACHE_KEY, response.body);
        await prefs.setInt(
            '${CACHE_KEY}_timestamp', DateTime.now().millisecondsSinceEpoch);

        return videos;
      } else {
        throw Exception('Failed to load publicity videos');
      }
    } catch (e) {
      // If offline and cache exists, return cached data regardless of age
      if (cachedData != null) {
        final List<dynamic> jsonList = json.decode(cachedData);
        return jsonList.map((json) => PublicityVideo.fromJson(json)).toList();
      }
      rethrow;
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
