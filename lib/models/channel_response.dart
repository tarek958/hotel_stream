import 'channel_model.dart';

class Bouquet {
  final String id;
  final String name;

  Bouquet({
    required this.id,
    required this.name,
  });

  factory Bouquet.fromJson(Map<String, dynamic> json) {
    return Bouquet(
      id: json['id'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class ChannelData {
  final List<Bouquet> bouquets;
  final List<Channel> channels;

  ChannelData({
    required this.bouquets,
    required this.channels,
  });

  factory ChannelData.fromJson(Map<String, dynamic> json) {
    return ChannelData(
      bouquets: (json['bouquets'] as List)
          .map((bouquet) => Bouquet.fromJson(bouquet as Map<String, dynamic>))
          .toList(),
      channels: (json['channels'] as List)
          .map((channel) => Channel.fromJson(channel as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bouquets': bouquets.map((b) => b.toJson()).toList(),
      'channels': channels.map((c) => c.toJson()).toList(),
    };
  }
}

class ChannelResponse {
  final List<ChannelData> data;
  bool isOffline;

  ChannelResponse({
    required this.data,
    this.isOffline = false,
  });

  factory ChannelResponse.fromJson(Map<String, dynamic> json) {
    return ChannelResponse(
      data: (json['data'] as List)
          .map((item) => ChannelData.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((d) => d.toJson()).toList(),
      'isOffline': isOffline,
    };
  }

  List<Channel> get channels => data.isNotEmpty ? data[0].channels : [];
  List<Bouquet> get categories => data.isNotEmpty ? data[0].bouquets : [];
}
