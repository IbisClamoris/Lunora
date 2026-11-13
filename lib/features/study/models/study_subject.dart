class StudySubject {
  final String id;
  final String name;
  final String teacher;
  final String description;
  final String academicYear;
  final int semester;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudySubject({
    required this.id,
    required this.name,
    this.teacher = '',
    this.description = '',
    this.academicYear = '',
    this.semester = 1,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'teacher': teacher,
      'description': description,
      'academic_year': academicYear,
      'semester': semester,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudySubject.fromMap(Map<String, Object?> map) {
    return StudySubject(
      id: map['id'] as String,
      name: map['name'] as String,
      teacher: map['teacher'] as String? ?? '',
      description: map['description'] as String? ?? '',
      academicYear: map['academic_year'] as String? ?? '',
      semester: map['semester'] as int? ?? 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  StudySubject copyWith({
    String? name,
    String? teacher,
    String? description,
    String? academicYear,
    int? semester,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return StudySubject(
      id: id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      description: description ?? this.description,
      academicYear: academicYear ?? this.academicYear,
      semester: semester ?? this.semester,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
