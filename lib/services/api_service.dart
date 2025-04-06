import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel_model.dart';
import '../models/bouquet.dart';

class ApiService {
  static const String baseUrl =
      'YOUR_API_BASE_URL'; // Replace with your actual API URL

  Future<Map<String, dynamic>> getChannelsAndCategories() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/channels'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'channels': (data['channels'] as List)
              .map((channel) => Channel.fromJson(channel))
              .toList(),
          'bouquets': (data['bouquets'] as List)
              .map((bouquet) => Bouquet.fromJson(bouquet))
              .toList(),
        };
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load data: $e');
    }
  }

  Future<void> clearLocalData() async {
    // Implement local data clearing logic here if needed
  }
}
