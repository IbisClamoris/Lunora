class RecipeMealPlanEntry {
  final String id;
  final String recipeId;
  final String planDate;
  final String mealType;
  final int servings;
  final int cookingDays;
  final int? durationMinutes;
  final String status;
  final String notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecipeMealPlanEntry({
    required this.id,
    required this.recipeId,
    required this.planDate,
    this.mealType = 'Ужин',
    this.servings = 2,
    this.cookingDays = 1,
    this.durationMinutes,
    this.status = 'Запланировано',
    this.notes = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecipeMealPlanEntry.fromMap(Map<String, dynamic> map) {
    return RecipeMealPlanEntry(
      id: map['id'] as String,
      recipeId: map['recipe_id'] as String,
      planDate: map['plan_date'] as String,
      mealType: map['meal_type'] as String? ?? 'Ужин',
      servings: map['servings'] as int? ?? 2,
      cookingDays: map['cooking_days'] as int? ?? 1,
      durationMinutes: map['duration_minutes'] as int?,
      status: map['status'] as String? ?? 'Запланировано',
      notes: map['notes'] as String? ?? '',
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recipe_id': recipeId,
      'plan_date': planDate,
      'meal_type': mealType,
      'servings': servings,
      'cooking_days': cookingDays,
      'duration_minutes': durationMinutes,
      'status': status,
      'notes': notes,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RecipeMealPlanEntry copyWith({
    String? recipeId,
    String? planDate,
    String? mealType,
    int? servings,
    int? cookingDays,
    int? durationMinutes,
    bool clearDuration = false,
    String? status,
    String? notes,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return RecipeMealPlanEntry(
      id: id,
      recipeId: recipeId ?? this.recipeId,
      planDate: planDate ?? this.planDate,
      mealType: mealType ?? this.mealType,
      servings: servings ?? this.servings,
      cookingDays: cookingDays ?? this.cookingDays,
      durationMinutes: clearDuration
          ? null
          : durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
