import 'dart:convert';

class RecordNote {
  final String id;
  final String title;
  final String content;
  final String sourceModule;
  final String sourceRecordId;
  final List<String> tags;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecordNote({
    required this.id,
    required this.title,
    this.content = '',
    required this.sourceModule,
    required this.sourceRecordId,
    this.tags = const [],
    this.isPinned = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecordNote.fromMap(Map<String, dynamic> map) {
    List<String> decodeTags(dynamic value) {
      if (value == null || value.toString().isEmpty) return [];
      try {
        final decoded = jsonDecode(value.toString());
        if (decoded is List) return decoded.whereType<String>().toList();
      } catch (_) {
        return [];
      }
      return [];
    }

    return RecordNote(
      id: map['id'] as String,
      title: map['title'] as String,
      content: map['content'] as String? ?? '',
      sourceModule: map['source_module'] as String? ?? '',
      sourceRecordId: map['source_record_id'] as String? ?? '',
      tags: decodeTags(map['tags']),
      isPinned: (map['is_pinned'] as num?)?.toInt() == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'content': content,
    'source_module': sourceModule,
    'source_record_id': sourceRecordId,
    'tags': jsonEncode(tags),
    'is_pinned': isPinned ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };
}
