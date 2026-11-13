class FinanceSavingsGoal {
  final String id;
  final String title;
  final int targetAmountMinor;
  final int savedAmountMinor;
  final String currency;
  final DateTime? targetDate;
  final String status;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FinanceSavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmountMinor,
    required this.savedAmountMinor,
    required this.currency,
    this.targetDate,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  int get remainingAmountMinor {
    final remaining = targetAmountMinor - savedAmountMinor;
    return remaining > 0 ? remaining : 0;
  }

  double get progress {
    if (targetAmountMinor <= 0) return 0;

    return (savedAmountMinor / targetAmountMinor).clamp(0.0, 1.0);
  }

  bool get isCompleted {
    return savedAmountMinor >= targetAmountMinor;
  }

  FinanceSavingsGoal copyWith({
    String? title,
    int? targetAmountMinor,
    int? savedAmountMinor,
    String? currency,
    DateTime? targetDate,
    bool clearTargetDate = false,
    String? status,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    return FinanceSavingsGoal(
      id: id,
      title: title ?? this.title,
      targetAmountMinor: targetAmountMinor ?? this.targetAmountMinor,
      savedAmountMinor: savedAmountMinor ?? this.savedAmountMinor,
      currency: currency ?? this.currency,
      targetDate: clearTargetDate ? null : targetDate ?? this.targetDate,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target_amount_minor': targetAmountMinor,
      'saved_amount_minor': savedAmountMinor,
      'currency': currency,
      'target_date': targetDate?.toIso8601String(),
      'status': status,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory FinanceSavingsGoal.fromMap(Map<String, dynamic> map) {
    return FinanceSavingsGoal(
      id: map['id'] as String,
      title: map['title'] as String,
      targetAmountMinor: (map['target_amount_minor'] as num).toInt(),
      savedAmountMinor: (map['saved_amount_minor'] as num).toInt(),
      currency: map['currency'] as String? ?? 'RUB',
      targetDate: map['target_date'] != null
          ? DateTime.tryParse(map['target_date'] as String)
          : null,
      status: map['status'] as String? ?? 'active',
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
