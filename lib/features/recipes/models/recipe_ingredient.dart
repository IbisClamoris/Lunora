class RecipeIngredient {
  final String id;
  final String recipeId;
  final String name;
  final double? quantity;
  final String unit;
  final String notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecipeIngredient({
    required this.id,
    required this.recipeId,
    required this.name,
    this.quantity,
    this.unit = '',
    this.notes = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecipeIngredient.fromMap(Map<String, dynamic> map) {
    return RecipeIngredient(
      id: map['id'] as String,
      recipeId: map['recipe_id'] as String,
      name: map['name'] as String,
      quantity: (map['quantity'] as num?)?.toDouble(),
      unit: map['unit'] as String? ?? '',
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
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'notes': notes,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RecipeIngredient copyWith({
    String? name,
    double? quantity,
    bool clearQuantity = false,
    String? unit,
    String? notes,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return RecipeIngredient(
      id: id,
      recipeId: recipeId,
      name: name ?? this.name,
      quantity: clearQuantity ? null : quantity ?? this.quantity,
      unit: unit ?? this.unit,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
