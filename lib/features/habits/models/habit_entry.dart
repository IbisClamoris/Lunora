class HabitEntry {
  final String id;
  final String name;
  final String description;
  final int targetPerWeek;
  final int colorValue;
  final int iconCodePoint;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  const HabitEntry({
    required this.id,
    required this.name,
    this.description = '',
    this.targetPerWeek = 7,
    this.colorValue = 0xFF8E9BCB,
    this.iconCodePoint = 0xe3a1,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  factory HabitEntry.fromMap(Map<String, Object?> map) => HabitEntry(
        id: map['id'] as String,
        name: map['name'] as String,
        description: map['description'] as String? ?? '',
        targetPerWeek: (map['target_per_week'] as num?)?.toInt() ?? 7,
        colorValue: (map['color_value'] as num?)?.toInt() ?? 0xFF8E9BCB,
        iconCodePoint: (map['icon_code_point'] as num?)?.toInt() ?? 0xe3a1,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
        isArchived: (map['is_archived'] as num?) == 1,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'target_per_week': targetPerWeek,
        'color_value': colorValue,
        'icon_code_point': iconCodePoint,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'is_archived': isArchived ? 1 : 0,
      };

  HabitEntry copyWith({
    String? name,
    String? description,
    int? targetPerWeek,
    int? colorValue,
    int? iconCodePoint,
    DateTime? updatedAt,
    bool? isArchived,
  }) =>
      HabitEntry(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        targetPerWeek: targetPerWeek ?? this.targetPerWeek,
        colorValue: colorValue ?? this.colorValue,
        iconCodePoint: iconCodePoint ?? this.iconCodePoint,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isArchived: isArchived ?? this.isArchived,
      );
}
