class CollectionEntry {
  final String id;
  final String name;
  final String description;
  final String? coverPath;
  final int? colorValue;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int itemCount;

  const CollectionEntry({
    required this.id, required this.name, this.description = '',
    this.coverPath, this.colorValue, this.sortOrder = 0,
    required this.createdAt, required this.updatedAt, this.itemCount = 0,
  });

  factory CollectionEntry.fromMap(Map<String, dynamic> map) => CollectionEntry(
    id: map['id'] as String,
    name: map['name'] as String,
    description: map['description'] as String? ?? '',
    coverPath: map['cover_path'] as String?,
    colorValue: (map['color_value'] as num?)?.toInt(),
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
    itemCount: (map['item_count'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'name': name, 'description': description,
    'cover_path': coverPath, 'color_value': colorValue,
    'sort_order': sortOrder, 'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  CollectionEntry copyWith({
    String? name, String? description, String? coverPath,
    bool clearCoverPath = false, int? colorValue, bool clearColorValue = false,
    int? sortOrder, DateTime? updatedAt, int? itemCount,
  }) => CollectionEntry(
    id: id, name: name ?? this.name,
    description: description ?? this.description,
    coverPath: clearCoverPath ? null : coverPath ?? this.coverPath,
    colorValue: clearColorValue ? null : colorValue ?? this.colorValue,
    sortOrder: sortOrder ?? this.sortOrder, createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
    itemCount: itemCount ?? this.itemCount,
  );
}

class CollectionItem {
  final String id;
  final String collectionId;
  final String recordModule;
  final String recordId;
  final String note;
  final int sortOrder;
  final DateTime addedAt;

  const CollectionItem({
    required this.id, required this.collectionId, required this.recordModule,
    required this.recordId, this.note = '', this.sortOrder = 0,
    required this.addedAt,
  });

  factory CollectionItem.fromMap(Map<String, dynamic> map) => CollectionItem(
    id: map['id'] as String,
    collectionId: map['collection_id'] as String,
    recordModule: map['record_module'] as String,
    recordId: map['record_id'] as String,
    note: map['note'] as String? ?? '',
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
    addedAt: DateTime.parse(map['added_at'] as String),
  );
}
