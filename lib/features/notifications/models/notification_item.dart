import 'dart:convert';

enum NotificationCategory {
  tasks,
  calendar,
  finance,
  study,
  cooking,
  importExport,
  backups,
  system,
  other,
}

enum NotificationType { info, reminder, warning, success, error }

class NotificationItem {
  final String id;
  final NotificationCategory category;
  final NotificationType type;
  final String eventType;
  final String? eventKey;
  final String title;
  final String message;
  final String? sourceModule;
  final String? sourceRecordId;
  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? readAt;
  final Map<String, dynamic> metadata;

  const NotificationItem({
    required this.id,
    required this.category,
    this.type = NotificationType.info,
    required this.eventType,
    this.eventKey,
    required this.title,
    this.message = '',
    this.sourceModule,
    this.sourceRecordId,
    required this.createdAt,
    this.scheduledAt,
    this.readAt,
    this.metadata = const {},
  });

  bool get isRead => readAt != null;

  bool get isUnread => readAt == null;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'category': category.name,
      'type': type.name,
      'event_type': eventType,
      'event_key': eventKey,
      'title': title,
      'message': message,
      'source_module': sourceModule,
      'source_record_id': sourceRecordId,
      'created_at': createdAt.toIso8601String(),
      'scheduled_at': scheduledAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
      'metadata': jsonEncode(metadata),
      'is_delivered': metadata['systemDeliveryStatus'] == 'delivered' ? 1 : 0,
    };
  }

  factory NotificationItem.fromMap(Map<String, Object?> map) {
    final parsedMetadata = _parseMetadata(map['metadata']);
    if ((map['is_delivered'] as int? ?? 0) == 1) {
      parsedMetadata.putIfAbsent('systemDeliveryStatus', () => 'delivered');
    }

    return NotificationItem(
      id: map['id'] as String,
      category: NotificationCategory.values.firstWhere(
        (value) => value.name == map['category'],
        orElse: () => NotificationCategory.other,
      ),
      type: NotificationType.values.firstWhere(
        (value) => value.name == map['type'],
        orElse: () => NotificationType.info,
      ),
      eventType: map['event_type'] as String? ?? 'unknown',
      eventKey: map['event_key'] as String?,
      title: map['title'] as String,
      message: map['message'] as String? ?? '',
      sourceModule: map['source_module'] as String?,
      sourceRecordId: map['source_record_id'] as String?,
      createdAt: _parseDate(map['created_at']) ?? DateTime.now(),
      scheduledAt: _parseDate(map['scheduled_at']),
      readAt: _parseDate(map['read_at']),
      metadata: parsedMetadata,
    );
  }

  NotificationItem copyWith({
    NotificationCategory? category,
    NotificationType? type,
    String? eventType,
    String? eventKey,
    bool clearEventKey = false,
    String? title,
    String? message,
    String? sourceModule,
    bool clearSourceModule = false,
    String? sourceRecordId,
    bool clearSourceRecordId = false,
    DateTime? scheduledAt,
    bool clearScheduledAt = false,
    DateTime? readAt,
    bool clearReadAt = false,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationItem(
      id: id,
      category: category ?? this.category,
      type: type ?? this.type,
      eventType: eventType ?? this.eventType,
      eventKey: clearEventKey ? null : eventKey ?? this.eventKey,
      title: title ?? this.title,
      message: message ?? this.message,
      sourceModule: clearSourceModule
          ? null
          : sourceModule ?? this.sourceModule,
      sourceRecordId: clearSourceRecordId
          ? null
          : sourceRecordId ?? this.sourceRecordId,
      createdAt: createdAt,
      scheduledAt: clearScheduledAt ? null : scheduledAt ?? this.scheduledAt,
      readAt: clearReadAt ? null : readAt ?? this.readAt,
      metadata: metadata ?? this.metadata,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;

    return DateTime.tryParse(value.toString());
  }

  static Map<String, dynamic> _parseMetadata(Object? value) {
    if (value == null) return {};

    try {
      final decoded = jsonDecode(value.toString());

      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Повреждённые дополнительные данные не должны ломать историю.
    }

    return {};
  }
}
