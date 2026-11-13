class MovieGenre {
  final String id;
  final String name;
  final bool isFavorite;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MovieGenre({
    required this.id,
    required this.name,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MovieGenre.fromMap(Map<String, dynamic> map) {
    return MovieGenre(
      id: map['id'] as String,
      name: map['name'] as String,
      isFavorite: (map['is_favorite'] as num?)?.toInt() == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_favorite': isFavorite ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MovieGenre copyWith({String? name, bool? isFavorite, DateTime? updatedAt}) {
    return MovieGenre(
      id: id,
      name: name ?? this.name,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
