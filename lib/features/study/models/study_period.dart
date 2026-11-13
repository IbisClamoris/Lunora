enum StudyPeriodType { semester, examSession, practice, other }

class StudyPeriod {
  final String id;
  final String title;
  final StudyPeriodType type;
  final String academicYear;
  final int semester;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyPeriod({
    required this.id,
    required this.title,
    required this.type,
    required this.academicYear,
    this.semester = 1,
    this.startsAt,
    this.endsAt,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'period_type': type.name,
      'academic_year': academicYear,
      'semester': semester,
      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudyPeriod.fromMap(Map<String, Object?> map) {
    return StudyPeriod(
      id: map['id'] as String,
      title: map['title'] as String,
      type: StudyPeriodType.values.firstWhere(
        (value) => value.name == map['period_type'],
        orElse: () => StudyPeriodType.other,
      ),
      academicYear: map['academic_year'] as String? ?? '',
      semester: map['semester'] as int? ?? 1,
      startsAt: map['starts_at'] == null
          ? null
          : DateTime.parse(map['starts_at'] as String),
      endsAt: map['ends_at'] == null
          ? null
          : DateTime.parse(map['ends_at'] as String),
      description: map['description'] as String? ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  StudyPeriod copyWith({
    String? title,
    StudyPeriodType? type,
    String? academicYear,
    int? semester,
    DateTime? startsAt,
    DateTime? endsAt,
    String? description,
    DateTime? updatedAt,
    bool clearStartsAt = false,
    bool clearEndsAt = false,
  }) {
    return StudyPeriod(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      startsAt: clearStartsAt ? null : startsAt ?? this.startsAt,
      endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
