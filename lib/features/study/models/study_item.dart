enum StudyItemType {
  lecture,
  onlineLecture,
  test,
  writtenAssignment,
  exam,
  credit,
  practice,
  coursework,
  diploma,
  other,
}

enum StudyItemFormat { none, offline, online }

enum StudyItemStatus { planned, inProgress, completed, cancelled }

class StudyItem {
  final String id;
  final String? subjectId;
  final String? periodId;
  final String title;
  final String description;
  final StudyItemType type;
  final StudyItemFormat format;
  final StudyItemStatus status;
  final DateTime? scheduledAt;
  final DateTime? dueAt;
  final String grade;
  final String notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyItem({
    required this.id,
    this.subjectId,
    this.periodId,
    required this.title,
    this.description = '',
    required this.type,
    this.format = StudyItemFormat.none,
    this.status = StudyItemStatus.planned,
    this.scheduledAt,
    this.dueAt,
    this.grade = '',
    this.notes = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'subject_id': subjectId,
      'period_id': periodId,
      'title': title,
      'description': description,
      'item_type': type.name,
      'format': format.name,
      'status': status.name,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'due_at': dueAt?.toIso8601String(),
      'grade': grade,
      'notes': notes,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudyItem.fromMap(Map<String, Object?> map) {
    return StudyItem(
      id: map['id'] as String,
      subjectId: map['subject_id'] as String?,
      periodId: map['period_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      type: StudyItemType.values.firstWhere(
        (value) => value.name == map['item_type'],
        orElse: () => StudyItemType.other,
      ),
      format: StudyItemFormat.values.firstWhere(
        (value) => value.name == map['format'],
        orElse: () => StudyItemFormat.none,
      ),
      status: StudyItemStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => StudyItemStatus.planned,
      ),
      scheduledAt: map['scheduled_at'] == null
          ? null
          : DateTime.parse(map['scheduled_at'] as String),
      dueAt: map['due_at'] == null
          ? null
          : DateTime.parse(map['due_at'] as String),
      grade: map['grade'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  StudyItem copyWith({
    String? subjectId,
    String? periodId,
    String? title,
    String? description,
    StudyItemType? type,
    StudyItemFormat? format,
    StudyItemStatus? status,
    DateTime? scheduledAt,
    DateTime? dueAt,
    String? grade,
    String? notes,
    int? sortOrder,
    DateTime? updatedAt,
    bool clearSubjectId = false,
    bool clearPeriodId = false,
    bool clearScheduledAt = false,
    bool clearDueAt = false,
  }) {
    return StudyItem(
      id: id,
      subjectId: clearSubjectId ? null : subjectId ?? this.subjectId,
      periodId: clearPeriodId ? null : periodId ?? this.periodId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      format: format ?? this.format,
      status: status ?? this.status,
      scheduledAt: clearScheduledAt ? null : scheduledAt ?? this.scheduledAt,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      grade: grade ?? this.grade,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
