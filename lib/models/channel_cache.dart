import 'dart:convert';
import 'channel_response.dart';

class ChannelCache {
  final ChannelResponse data;
  final String version;
  final DateTime lastUpdated;

  ChannelCache({
    required this.data,
    required this.version,
    required this.lastUpdated,
  });

  factory ChannelCache.fromJson(Map<String, dynamic> json) {
    return ChannelCache(
      data: ChannelResponse.fromJson(json['data'] as Map<String, dynamic>),
      version: json['version'] as String,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.toJson(),
      'version': version,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  static String encode(ChannelCache data) => json.encode(data.toJson());
  
  static ChannelCache decode(String data) {
    final jsonData = json.decode(data) as Map<String, dynamic>;
    return ChannelCache.fromJson(jsonData);
  }
}
