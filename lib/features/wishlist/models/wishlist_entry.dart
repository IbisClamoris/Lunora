class WishlistEntry {
  final String id;
  final String title;
  final String description;
  final String? imagePath;
  final String category;
  final List<String> tags;
  final double? price;
  final String currency;
  final String? sourceUrl;
  final String priority;
  final DateTime? desiredDate;
  final bool isPurchased;
  final DateTime? purchasedAt;
  final String notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WishlistEntry({
    required this.id,
    required this.title,
    this.description = '',
    this.imagePath,
    this.category = 'Без категории',
    this.tags = const [],
    this.price,
    this.currency = '',
    this.sourceUrl,
    this.priority = 'normal',
    this.desiredDate,
    this.isPurchased = false,
    this.purchasedAt,
    this.notes = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WishlistEntry.fromMap(Map<String, dynamic> map) {
    return WishlistEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      imagePath: map['image_path'] as String?,
      category: map['category'] as String? ?? 'Без категории',
      tags: (map['tags'] as String? ?? '[]')
          .replaceAll('[', '')
          .replaceAll(']', '')
          .split(',')
          .map((tag) => tag.trim().replaceAll('"', ''))
          .where((tag) => tag.isNotEmpty)
          .toList(),
      price: (map['price'] as num?)?.toDouble(),
      currency: map['currency'] as String? ?? '',
      sourceUrl: map['source_url'] as String?,
      priority: map['priority'] as String? ?? 'normal',
      desiredDate: map['desired_date'] != null
          ? DateTime.tryParse(map['desired_date'] as String)
          : null,
      isPurchased: (map['is_purchased'] as int? ?? 0) == 1,
      purchasedAt: map['purchased_at'] != null
          ? DateTime.tryParse(map['purchased_at'] as String)
          : null,
      notes: map['notes'] as String? ?? '',
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_path': imagePath,
      'category': category,
      'tags': _encodeTags(tags),
      'price': price,
      'currency': currency,
      'source_url': sourceUrl,
      'priority': priority,
      'desired_date': desiredDate?.toIso8601String(),
      'is_purchased': isPurchased ? 1 : 0,
      'purchased_at': purchasedAt?.toIso8601String(),
      'notes': notes,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String _encodeTags(List<String> tags) {
    return '[${tags.map((tag) => '"${tag.replaceAll('"', '\\"')}"').join(',')}]';
  }

  WishlistEntry copyWith({
    String? id,
    String? title,
    String? description,
    String? imagePath,
    bool clearImagePath = false,
    String? category,
    List<String>? tags,
    double? price,
    bool clearPrice = false,
    String? currency,
    String? sourceUrl,
    bool clearSourceUrl = false,
    String? priority,
    DateTime? desiredDate,
    bool clearDesiredDate = false,
    bool? isPurchased,
    DateTime? purchasedAt,
    bool clearPurchasedAt = false,
    String? notes,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WishlistEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: clearImagePath ? null : imagePath ?? this.imagePath,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      price: clearPrice ? null : price ?? this.price,
      currency: currency ?? this.currency,
      sourceUrl: clearSourceUrl ? null : sourceUrl ?? this.sourceUrl,
      priority: priority ?? this.priority,
      desiredDate: clearDesiredDate ? null : desiredDate ?? this.desiredDate,
      isPurchased: isPurchased ?? this.isPurchased,
      purchasedAt: clearPurchasedAt ? null : purchasedAt ?? this.purchasedAt,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
