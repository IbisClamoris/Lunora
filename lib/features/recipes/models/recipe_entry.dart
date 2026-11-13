import 'dart:convert';

class RecipeEntry {
  final String id;
  final String title;
  final String description;
  final String instructions;
  final String? coverPath;
  final String category;
  final String cuisine;
  final String difficulty;
  final List<String> tags;
  final int servings;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final double? rating;
  final String review;
  final String? sourceUrl;
  final String sourceName;
  final bool isFavorite;
  final bool isCookAhead;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecipeEntry({
    required this.id,
    required this.title,
    this.description = '',
    this.instructions = '',
    this.coverPath,
    this.category = 'Без категории',
    this.cuisine = '',
    this.difficulty = '',
    this.tags = const [],
    this.servings = 2,
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.rating,
    this.review = '',
    this.sourceUrl,
    this.sourceName = '',
    this.isFavorite = false,
    this.isCookAhead = false,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecipeEntry.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags'] as String? ?? '[]';

    List<String> tags;

    try {
      tags = (jsonDecode(rawTags) as List)
          .map((tag) => tag.toString())
          .toList();
    } catch (_) {
      tags = [];
    }

    return RecipeEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      instructions: map['instructions'] as String? ?? '',
      coverPath: map['cover_path'] as String?,
      category: map['category'] as String? ?? 'Без категории',
      cuisine: map['cuisine'] as String? ?? '',
      difficulty: map['difficulty'] as String? ?? '',
      tags: tags,
      servings: map['servings'] as int? ?? 2,
      prepTimeMinutes: map['prep_time_minutes'] as int?,
      cookTimeMinutes: map['cook_time_minutes'] as int?,
      rating: (map['rating'] as num?)?.toDouble(),
      review: map['review'] as String? ?? '',
      sourceUrl: map['source_url'] as String?,
      sourceName: map['source_name'] as String? ?? '',
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      isCookAhead: (map['is_cook_ahead'] as int? ?? 0) == 1,
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
      'instructions': instructions,
      'cover_path': coverPath,
      'category': category,
      'cuisine': cuisine,
      'difficulty': difficulty,
      'tags': jsonEncode(tags),
      'servings': servings,
      'prep_time_minutes': prepTimeMinutes,
      'cook_time_minutes': cookTimeMinutes,
      'rating': rating,
      'review': review,
      'source_url': sourceUrl,
      'source_name': sourceName,
      'is_favorite': isFavorite ? 1 : 0,
      'is_cook_ahead': isCookAhead ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  RecipeEntry copyWith({
    String? title,
    String? description,
    String? instructions,
    String? coverPath,
    bool clearCoverPath = false,
    String? category,
    String? cuisine,
    String? difficulty,
    List<String>? tags,
    int? servings,
    int? prepTimeMinutes,
    bool clearPrepTime = false,
    int? cookTimeMinutes,
    bool clearCookTime = false,
    double? rating,
    bool clearRating = false,
    String? review,
    String? sourceUrl,
    bool clearSourceUrl = false,
    String? sourceName,
    bool? isFavorite,
    bool? isCookAhead,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return RecipeEntry(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      instructions: instructions ?? this.instructions,
      coverPath: clearCoverPath ? null : coverPath ?? this.coverPath,
      category: category ?? this.category,
      cuisine: cuisine ?? this.cuisine,
      difficulty: difficulty ?? this.difficulty,
      tags: tags ?? this.tags,
      servings: servings ?? this.servings,
      prepTimeMinutes: clearPrepTime
          ? null
          : prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: clearCookTime
          ? null
          : cookTimeMinutes ?? this.cookTimeMinutes,
      rating: clearRating ? null : rating ?? this.rating,
      review: review ?? this.review,
      sourceUrl: clearSourceUrl ? null : sourceUrl ?? this.sourceUrl,
      sourceName: sourceName ?? this.sourceName,
      isFavorite: isFavorite ?? this.isFavorite,
      isCookAhead: isCookAhead ?? this.isCookAhead,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
