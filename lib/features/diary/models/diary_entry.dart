import 'dart:convert';

class DiaryEntry {
  final String id;
  final String title;
  final String content;
  final DateTime entryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Настроение.
  final String? mood;

  // Категория записи.
  final String category;

  // diary или memory.
  final String entryType;

  // Любимый момент.
  final bool isFavorite;

  // Теги.
  final List<String> tags;

  const DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.entryDate,
    required this.createdAt,
    required this.updatedAt,
    this.mood,
    this.category = 'Без категории',
    this.entryType = 'diary',
    this.isFavorite = false,
    this.tags = const [],
  });

  factory DiaryEntry.fromMap(Map<String, dynamic> map) {
    return DiaryEntry(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      entryDate: DateTime.parse(map['entry_date'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      mood: map['mood'] as String?,
      category: map['category'] as String? ?? 'Без категории',
      entryType: map['entry_type'] as String? ?? 'diary',
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      tags: _decodeTags(map['tags']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'entry_date': _formatDate(entryDate),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'mood': mood,
      'category': category,
      'entry_type': entryType,
      'is_favorite': isFavorite ? 1 : 0,
      'tags': jsonEncode(tags),
    };
  }

  DiaryEntry copyWith({
    String? title,
    String? content,
    DateTime? entryDate,
    DateTime? updatedAt,
    String? mood,
    bool clearMood = false,
    String? category,
    String? entryType,
    bool? isFavorite,
    List<String>? tags,
  }) {
    return DiaryEntry(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      entryDate: entryDate ?? this.entryDate,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mood: clearMood ? null : mood ?? this.mood,
      category: category ?? this.category,
      entryType: entryType ?? this.entryType,
      isFavorite: isFavorite ?? this.isFavorite,
      tags: tags ?? this.tags,
    );
  }

  static List<String> _decodeTags(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(value as String);

      if (decoded is List) {
        return decoded.map((tag) => tag.toString()).toList();
      }
    } catch (_) {
      return const [];
    }

    return const [];
  }

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}
