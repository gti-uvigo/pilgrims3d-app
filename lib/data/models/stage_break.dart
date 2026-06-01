class StageBreak {
  final String id;
  final String name;

  StageBreak({required this.id, String? name})
      : name = name ?? 'Cambio de Etapa';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}
