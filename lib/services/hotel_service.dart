import 'dart:convert';
import 'package:http/http.dart' as http;

class HotelService {
  static const String baseUrl = 'http://151.80.133.55:6666/api';

  Future<Map<String, dynamic>> getHotelInfo(String hotelId) async {
    try {
      // For testing, return hardcoded data if the server is not available
      return {
        "name": "Luxury Palace Hotel",
        "description": "A 5-star luxury hotel with premium amenities",
        "location": "Tunisia, Tunis",
        "channels": [
          {
            "name": "Essaida TV",
            "category": "Entertainment",
            "streamUrl": "https://essaidatv.dextream.com/hls/stream/index.m3u8",
            "description": "Tunisian entertainment channel featuring local content",
            "thumbnail": "https://upload.wikimedia.org/wikipedia/commons/8/8e/Logo_essaida.png",
            "isLive": true,
          },
          {
            "name": "JAWHARA TV",
            "category": "Entertainment",
            "streamUrl": "https://streaming.toutech.net/live/jtv/index.m3u8",
            "description": "Live entertainment and cultural programming [720p]",
            "thumbnail": "https://www.jawharafm.net/ar/static/fr/image/jpg/logo-jawhara.jpg",
            "isLive": true,
          },
          {
            "name": "Mosaïque FM",
            "category": "News",
            "streamUrl": "https://webcam.mosaiquefm.net:1936/mosatv/studio/playlist.m3u8",
            "description": "News and current affairs from Tunisia [480p]",
            "thumbnail": "https://www.mosaiquefm.net/images/front2020/logoMosaique.png",
            "isLive": true,
          },
          {
            "name": "Watania 1",
            "category": "National",
            "streamUrl": "http://live.watania1.tn:1935/live/watanya1.stream/playlist.m3u8",
            "description": "National public television channel [576p]",
            "thumbnail": "https://upload.wikimedia.org/wikipedia/commons/6/65/Watania1.png",
            "isLive": true,
          }
        ]
      };

      // Uncomment this when the server is available
      /*
      final response = await http.get(Uri.parse('$baseUrl/hotels/$hotelId'));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load hotel information');
      }
      */
    } catch (e) {
      throw Exception('Failed to load hotel information: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllHotels() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/hotels'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to load hotels');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }

  Future<Map<String, dynamic>> getChannelsAndCategories() async {
    try {
      // For testing, return hardcoded data if the server is not available
      return {
        "categories": [
          {
            "id": "Entertainment",
            "name": "Entertainment"
          },
          {
            "id": "News",
            "name": "News"
          },
          {
            "id": "Sports",
            "name": "Sports"
          }
        ],
        "channels": [
          {
            "id": "essaida",
            "name": "Essaida TV",
            "category": "Entertainment",
            "streamUrl": "https://essaidatv.dextream.com/hls/stream/index.m3u8",
            "description": "Tunisian entertainment channel featuring local content",
            "logoUrl": "https://upload.wikimedia.org/wikipedia/commons/8/8e/Logo_essaida.png",
            "isLive": true
          },
          {
            "id": "jawhara",
            "name": "JAWHARA TV",
            "category": "Entertainment",
            "streamUrl": "https://streaming.toutech.net/live/jtv/index.m3u8",
            "description": "Live entertainment and cultural programming [720p]",
            "logoUrl": "https://www.jawharafm.net/ar/static/fr/image/jpg/logo-jawhara.jpg",
            "isLive": true
          },
          {
            "id": "watania1",
            "name": "Watania 1",
            "category": "News",
            "streamUrl": "https://www.youtube.com/watch?v=7at1RVsIOO8",
            "description": "Tunisia's national television channel",
            "logoUrl": "https://upload.wikimedia.org/wikipedia/fr/5/54/Wataniya_1.png",
            "isLive": true
          },
          {
            "id": "watania2",
            "name": "Watania 2",
            "category": "News",
            "streamUrl": "https://www.youtube.com/watch?v=MQQQYr4yXhI",
            "description": "Second channel of Tunisia's national television",
            "logoUrl": "https://upload.wikimedia.org/wikipedia/commons/7/72/Logo_Wataniya_2.png",
            "isLive": true
          }
        ]
      };

      // When ready to connect to real API:
      // final response = await http.get(Uri.parse('$baseUrl/channels'));
      // if (response.statusCode == 200) {
      //   return json.decode(response.body);
      // } else {
      //   throw Exception('Failed to load channels');
      // }
    } catch (e) {
      throw Exception('Failed to load channels: $e');
    }
  }
}
