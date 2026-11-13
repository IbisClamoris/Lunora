class FinanceBudget {
  final String id;
  final String categoryId;
  final int year;
  final int month;
  final int limitMinor;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinanceBudget({
    required this.id,
    required this.categoryId,
    required this.year,
    required this.month,
    required this.limitMinor,
    required this.createdAt,
    required this.updatedAt,
  });

  double get limitAmount => limitMinor / 100;

  DateTime get periodStart => DateTime(year, month);

  DateTime get periodEnd => DateTime(year, month + 1, 0);

  FinanceBudget copyWith({
    String? id,
    String? categoryId,
    int? year,
    int? month,
    int? limitMinor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinanceBudget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      year: year ?? this.year,
      month: month ?? this.month,
      limitMinor: limitMinor ?? this.limitMinor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'year': year,
      'month': month,
      'limit_minor': limitMinor,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FinanceBudget.fromMap(Map<String, Object?> map) {
    return FinanceBudget(
      id: map['id'] as String,
      categoryId: map['category_id'] as String,
      year: map['year'] as int,
      month: map['month'] as int,
      limitMinor: map['limit_minor'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
