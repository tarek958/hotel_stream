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

  factory PublicityVideo.fromJson(Map<String, dynamic> json) {
    return PublicityVideo(
      id: json['id'] as String,
      videoUrl: json['video_url'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
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
}
