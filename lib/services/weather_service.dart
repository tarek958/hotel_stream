import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static const String _apiKey =
      '69e30561fe53310426dff165d05934bf'; // Replace with your OpenWeatherMap API key
  static const String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  Future<Map<String, dynamic>> getWeather(String city) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/weather?q=$city&appid=$_apiKey&units=metric'),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      throw Exception('Error fetching weather: $e');
    }
  }
}
