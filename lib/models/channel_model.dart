class Channel {
  final String id;
  final String name;
  final String categ;
  final String ch;
  final String logo;
  final String description;
  final bool isLive;

  Channel({
    required this.id,
    required this.name,
    required this.categ,
    required this.ch,
    required this.logo,
    this.description = '',
    this.isLive = false,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'].toString(),
      name: json['name'] as String,
      categ: json['categ'].toString(),
      ch: json['ch'].toString(),
      logo: json['logo'] as String,
      description: json['description']?.toString() ?? '',
      isLive: json['isLive'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'categ': categ,
      'ch': ch,
      'logo': logo,
      'description': description,
      'isLive': isLive,
    };
  }

  String get category => categ.toString();
  String get streamUrl => ch;
  String get logoUrl => logo;
}