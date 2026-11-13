class ShoppingItem {
  final String id;
  final String title;
  final String? category;
  final double? quantity;
  final String? unit;
  final String? notes;
  final bool isPurchased;
  final DateTime? purchasedAt;
  final String? sourceModule;
  final String? sourceRecordId;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ShoppingItem({
    required this.id,
    required this.title,
    this.category,
    this.quantity,
    this.unit,
    this.notes,
    this.isPurchased = false,
    this.purchasedAt,
    this.sourceModule,
    this.sourceRecordId,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String?,
      quantity: (map['quantity'] as num?)?.toDouble(),
      unit: map['unit'] as String?,
      notes: map['notes'] as String?,
      isPurchased: (map['is_purchased'] as int? ?? 0) == 1,
      purchasedAt: map['purchased_at'] != null
          ? DateTime.tryParse(map['purchased_at'] as String)
          : null,
      sourceModule: map['source_module'] as String?,
      sourceRecordId: map['source_record_id'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'notes': notes,
      'is_purchased': isPurchased ? 1 : 0,
      'purchased_at': purchasedAt?.toIso8601String(),
      'source_module': sourceModule,
      'source_record_id': sourceRecordId,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ShoppingItem copyWith({
    String? id,
    String? title,
    String? category,
    double? quantity,
    String? unit,
    String? notes,
    bool? isPurchased,
    DateTime? purchasedAt,
    String? sourceModule,
    String? sourceRecordId,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearCategory = false,
    bool clearQuantity = false,
    bool clearUnit = false,
    bool clearNotes = false,
    bool clearPurchasedAt = false,
    bool clearSource = false,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      title: title ?? this.title,
      category: clearCategory ? null : category ?? this.category,
      quantity: clearQuantity ? null : quantity ?? this.quantity,
      unit: clearUnit ? null : unit ?? this.unit,
      notes: clearNotes ? null : notes ?? this.notes,
      isPurchased: isPurchased ?? this.isPurchased,
      purchasedAt: clearPurchasedAt ? null : purchasedAt ?? this.purchasedAt,
      sourceModule: clearSource ? null : sourceModule ?? this.sourceModule,
      sourceRecordId: clearSource
          ? null
          : sourceRecordId ?? this.sourceRecordId,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
