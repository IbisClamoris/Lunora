class PlannerGoal {
  final String id;
  final String title;
  final int month;
  final int year;
  final bool isCompleted;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlannerGoal({
    required this.id,
    required this.title,
    required this.month,
    required this.year,
    this.isCompleted = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'month': month,
      'year': year,
      'is_completed': isCompleted ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PlannerGoal.fromMap(Map<String, Object?> map) {
    return PlannerGoal(
      id: map['id'] as String,
      title: map['title'] as String,
      month: map['month'] as int,
      year: map['year'] as int,
      isCompleted: (map['is_completed'] as int? ?? 0) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  PlannerGoal copyWith({
    String? title,
    bool? isCompleted,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return PlannerGoal(
      id: id,
      title: title ?? this.title,
      month: month,
      year: year,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
