import 'dart:convert';

class KnowledgeEntry {
  final String id;
  final String title;
  final String content;
  final String category;
  final List<String> tags;
  final String? sourceUrl;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;

  const KnowledgeEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.tags = const [],
    this.sourceUrl,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.isFavorite = false,
  });

  static const List<String> categories = [
    'Учебные материалы',
    'Конспекты',
    'Определения',
    'Формулы',
    'Вопросы',
    'Полезные сайты',
    'Инструкции',
    'Идеи',
    'Другое',
  ];

  factory KnowledgeEntry.fromMap(
    Map<String, dynamic> map, {
    bool isFavorite = false,
  }) {
    final rawTags = map['tags'] as String? ?? '[]';

    List<String> parsedTags = [];

    try {
      final decoded = jsonDecode(rawTags);
      if (decoded is List) {
        parsedTags = decoded.map((tag) => tag.toString()).toList();
      }
    } catch (_) {
      parsedTags = [];
    }

    return KnowledgeEntry(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      category: map['category'] as String? ?? 'Другое',
      tags: parsedTags,
      sourceUrl: map['source_url'] as String?,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      isFavorite: isFavorite,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'category': category,
      'tags': jsonEncode(tags),
      'source_url': sourceUrl,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  KnowledgeEntry copyWith({
    String? title,
    String? content,
    String? category,
    List<String>? tags,
    String? sourceUrl,
    int? sortOrder,
    DateTime? updatedAt,
    bool? isFavorite,
  }) {
    return KnowledgeEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      tags: tags ?? this.tags,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
