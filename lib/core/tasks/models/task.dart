class Task {
  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final int? dueTimeMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const Task({
    required this.id,
    required this.title,
    this.description = '',
    this.status = TaskStatus.planned,
    this.priority = TaskPriority.normal,
    this.dueDate,
    this.dueTimeMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  bool get isOverdue {
    if (dueDate == null ||
        status == TaskStatus.completed ||
        status == TaskStatus.cancelled) {
      return false;
    }

    final now = DateTime.now();
    final date = dueDate!;

    final today = DateTime(now.year, now.month, now.day);
    final taskDay = DateTime(date.year, date.month, date.day);

    if (taskDay.isBefore(today)) return true;
    if (taskDay.isAfter(today)) return false;

    if (dueTimeMinutes == null) return false;

    final currentMinutes = now.hour * 60 + now.minute;
    return currentMinutes > dueTimeMinutes!;
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'status': status.name,
      'priority': priority.name,
      'due_date': dueDate?.toIso8601String(),
      'due_time_minutes': dueTimeMinutes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      status: TaskStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => TaskStatus.planned,
      ),
      priority: TaskPriority.values.firstWhere(
        (value) => value.name == map['priority'],
        orElse: () => TaskPriority.normal,
      ),
      dueDate: DateTime.tryParse(map['due_date']?.toString() ?? ''),
      dueTimeMinutes: map['due_time_minutes'] as int?,
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),
      completedAt: DateTime.tryParse(map['completed_at']?.toString() ?? ''),
    );
  }

  Task copyWith({
    String? title,
    String? description,
    TaskStatus? status,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    int? dueTimeMinutes,
    bool clearDueTime = false,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      dueTimeMinutes: clearDueTime
          ? null
          : dueTimeMinutes ?? this.dueTimeMinutes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    );
  }
}

enum TaskStatus { planned, inProgress, completed, cancelled }

enum TaskPriority { low, normal, high }
