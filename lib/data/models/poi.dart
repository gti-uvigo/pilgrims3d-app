class Poi {
  final String poiId;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String? imageId;
  final String? iconCategory;

  Poi({
    required this.poiId,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    this.imageId,
    this.iconCategory,
  });

  factory Poi.fromJson(Map<String, dynamic> json) {
    // Intentar múltiples campos para el ID
    final String id = json['poi_id']?.toString() ?? 
                      json['id']?.toString() ?? 
                      json['_id']?.toString() ?? 
                      '';
    
    return Poi(
      poiId: id,
      title: json['title'] ?? json['name'] ?? 'Sin título',
      description: json['description'] ?? '',
      latitude: (json['latitude'] is String) 
          ? double.tryParse(json['latitude']) ?? 0.0 
          : (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] is String)
          ? double.tryParse(json['longitude']) ?? 0.0
          : (json['longitude'] ?? 0.0).toDouble(),
      imageId: json['image_id']?.toString(),
      iconCategory: json['icon_category']?.toString() ?? json['iconCategory']?.toString(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Poi &&
          runtimeType == other.runtimeType &&
          poiId == other.poiId &&
          poiId.isNotEmpty;

  @override
  int get hashCode => poiId.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'poi_id': poiId,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'image_id': imageId,
      'icon_category': iconCategory,
    };
  }
}
