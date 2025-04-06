import 'dart:convert';

class PublicityVideo {
  final String id;
  final String videoUrl;
  final DateTime timestamp;
  String? localPath; // Path to cached video file

  PublicityVideo({
    required this.id,
    required this.videoUrl,
    required this.timestamp,
    this.localPath,
  });

  // Handle different variations of JSON field names and formats
  factory PublicityVideo.fromJson(Map<String, dynamic> json) {
    print('Parsing video JSON: $json');

    // Get ID with fallbacks
    final String videoId = json['id']?.toString() ??
        json['video_id']?.toString() ??
        json['publicityId']?.toString() ??
        '';

    // Get URL with fallbacks for different field names
    final String url = json['video_url']?.toString() ??
        json['videoUrl']?.toString() ??
        json['url']?.toString() ??
        '';

    // Parse timestamp with fallbacks
    DateTime parsedTimestamp;
    try {
      final timeStr = json['timestamp']?.toString() ??
          json['created_at']?.toString() ??
          DateTime.now().toIso8601String();
      parsedTimestamp = DateTime.parse(timeStr);
    } catch (e) {
      print('Error parsing timestamp: $e');
      parsedTimestamp = DateTime.now();
    }

    return PublicityVideo(
      id: videoId,
      videoUrl: url,
      timestamp: parsedTimestamp,
      localPath: json['local_path'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'video_url': videoUrl,
      'timestamp': timestamp.toIso8601String(),
      'local_path': localPath,
    };
  }

  @override
  String toString() {
    return 'PublicityVideo(id: $id, url: $videoUrl, timestamp: $timestamp)';
  }
}
