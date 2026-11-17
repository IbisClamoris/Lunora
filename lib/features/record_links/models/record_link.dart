class RecordLink {
  final String id;
  final String sourceModule;
  final String sourceRecordId;
  final String targetModule;
  final String targetRecordId;
  final String relationType;
  final String note;
  final DateTime createdAt;

  const RecordLink({
    required this.id, required this.sourceModule, required this.sourceRecordId,
    required this.targetModule, required this.targetRecordId,
    this.relationType = 'related', this.note = '', required this.createdAt,
  });

  factory RecordLink.fromMap(Map<String, dynamic> map) => RecordLink(
    id: map['id'] as String,
    sourceModule: map['source_module'] as String,
    sourceRecordId: map['source_record_id'] as String,
    targetModule: map['target_module'] as String,
    targetRecordId: map['target_record_id'] as String,
    relationType: map['relation_type'] as String? ?? 'related',
    note: map['note'] as String? ?? '',
    createdAt: DateTime.parse(map['created_at'] as String),
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'source_module': sourceModule, 'source_record_id': sourceRecordId,
    'target_module': targetModule, 'target_record_id': targetRecordId,
    'relation_type': relationType, 'note': note,
    'created_at': createdAt.toIso8601String(),
  };
}

class LinkedRecord {
  final RecordLink link;
  final String module;
  final String recordId;
  const LinkedRecord({required this.link, required this.module, required this.recordId});
}
