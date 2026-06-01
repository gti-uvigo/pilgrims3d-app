class RouteType {
  final String id;
  final String name;
  final List<String> subtypes;

  RouteType({
    required this.id,
    required this.name,
    required this.subtypes,
  });

  factory RouteType.fromJson(Map<String, dynamic> json) {
    return RouteType(
      id: json['route_type_id']?.toString() ?? '',
      name: json['name'] ?? '',
      subtypes: (json['subtypes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_type_id': id,
      'name': name,
      'subtypes': subtypes,
    };
  }
}
