import 'package:lunora/core/settings/settings_service.dart';
import 'package:lunora/core/theme/lunora_theme_assets.dart';
import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lunora/shared/widgets/lunora_section_header.dart';

import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/features/notifications/services/notification_service.dart';
import 'package:lunora/core/theme/app_theme.dart';

enum _NotificationFilter { all, unread }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const double _contentMaxWidth = 940;
  static const double _compactBreakpoint = 650;

  final NotificationService _service = NotificationService.instance;

  Timer? _refreshTimer;

  List<NotificationItem> _notifications = [];
  NotificationCategory? _selectedCategory;
  _NotificationFilter _filter = _NotificationFilter.all;

  bool _isLoading = true;
  bool _isBusy = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();

    // Обновляем состояния доставки, пока страница открыта.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshSilently(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final notifications = await _service.getAll();
      final unreadCount = await _service.getUnreadCount();

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showMessage(LunoraLocalization.text('Не удалось загрузить уведомления: $error', 'Could not load notifications: $error'));
    }
  }

  Future<void> _refreshSilently() async {
    try {
      final notifications = await _service.getAll();
      final unreadCount = await _service.getUnreadCount();

      if (!mounted) return;

      setState(() {
        _notifications = notifications;
        _unreadCount = unreadCount;
      });
    } catch (_) {
      // Ошибка фонового обновления не должна прерывать работу страницы.
    }
  }

  List<NotificationItem> get _visibleNotifications {
    return _notifications.where((notification) {
      if (_filter == _NotificationFilter.unread && notification.isRead) {
        return false;
      }

      if (_selectedCategory != null &&
          notification.category != _selectedCategory) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _isScheduled(NotificationItem notification) {
    final scheduledAt = notification.scheduledAt;
    return scheduledAt != null && scheduledAt.isAfter(DateTime.now());
  }

  String? _systemDeliveryStatus(NotificationItem notification) {
    final metadata = notification.metadata;
    final status = metadata['systemDeliveryStatus']?.toString();

    if (_isScheduled(notification)) {
      return LunoraLocalization.text('Запланировано', 'Scheduled');
    }

    if (status == 'disabled') {
      return LunoraLocalization.text('Отключено настройками', 'Disabled in settings');
    }

    if (status == 'delivered' || metadata['systemDeliveredAt'] != null) {
      return LunoraLocalization.text('Доставлено', 'Delivered');
    }

    if (notification.scheduledAt != null) {
      return LunoraLocalization.text('Ожидает доставки', 'Pending delivery');
    }

    return null;
  }

  String _displayTitle(NotificationItem notification) {
    if (_isScheduled(notification) &&
        notification.eventType == 'task_overdue') {
      return LunoraLocalization.text(
        LunoraLocalization.text('Напоминание о просрочке', 'Overdue reminder'),
        'Overdue reminder',
      );
    }

    return LunoraLocalization.text(notification.title);
  }

  String? _deliveryDateLabel(NotificationItem notification) {
    final status = _systemDeliveryStatus(notification);

    if (status == null) return null;

    if (status == LunoraLocalization.text('Запланировано', 'Scheduled') && notification.scheduledAt != null) {
      return LunoraLocalization.text('Запланировано на ${_formatDate(notification.scheduledAt!)}', 'Scheduled for ${_formatDate(notification.scheduledAt!)}');
    }

    final deliveredAt = notification.metadata['systemDeliveredAt']?.toString();

    if (status == LunoraLocalization.text('Доставлено', 'Delivered') && deliveredAt != null) {
      final date = DateTime.tryParse(deliveredAt);

      if (date != null) {
        return LunoraLocalization.text('Доставлено: ${_formatDate(date)}', 'Delivered: ${_formatDate(date)}');
      }
    }

    if (status == LunoraLocalization.text('Ожидает доставки', 'Pending delivery') && notification.scheduledAt != null) {
      return LunoraLocalization.text('Время события: ${_formatDate(notification.scheduledAt!)}', 'Event time: ${_formatDate(notification.scheduledAt!)}');
    }

    return null;
  }

  Color _deliveryStatusColor(String status, LunoraPalette palette) {
    return switch (status) {
      'Запланировано' => palette.accent,
      'Ожидает доставки' => Colors.orange.shade700,
      'Доставлено' => Colors.green.shade700,
      'Отключено настройками' => palette.secondary,
      _ => palette.secondary,
    };
  }

  IconData _deliveryStatusIcon(String status) {
    return switch (status) {
      'Запланировано' => Icons.schedule,
      'Ожидает доставки' => Icons.hourglass_empty,
      'Доставлено' => Icons.check_circle_outline,
      'Отключено настройками' => Icons.notifications_off_outlined,
      _ => Icons.info_outline,
    };
  }

  Future<void> _markRead(NotificationItem notification) async {
    if (_isBusy) return;

    setState(() => _isBusy = true);

    try {
      if (notification.isRead) {
        await _service.markUnread(notification.id);
      } else {
        await _service.markRead(notification.id);
      }

      await _refreshAfterAction();
    } catch (error) {
      _showMessage(LunoraLocalization.text('Не удалось обновить уведомление: $error', 'Could not update notification: $error'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _markAllRead() async {
    if (_isBusy || _unreadCount == 0) return;

    setState(() => _isBusy = true);

    try {
      await _service.markAllRead();
      await _refreshAfterAction();
      _showMessage(LunoraLocalization.text('Все уведомления отмечены прочитанными.', 'All notifications marked as read.'));
    } catch (error) {
      _showMessage(LunoraLocalization.text('Не удалось обновить уведомления: $error', 'Could not update notifications: $error'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _deleteNotification(NotificationItem notification) async {
    if (_isBusy) return;

    final confirmed = await _showConfirmation(
      title: LunoraLocalization.text('Удалить уведомление?'),
      message: LunoraLocalization.text('Запись «${notification.title}» будет удалена из истории.', 'Entry “${notification.title}” will be removed from history.'),
      confirmLabel: LunoraLocalization.text('Удалить', 'Delete'),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);

    try {
      await _service.delete(notification.id);
      await _refreshAfterAction();
    } catch (error) {
      _showMessage(LunoraLocalization.text('Не удалось удалить уведомление: $error', 'Could not delete notification: $error'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _clearHistory() async {
    if (_isBusy || _notifications.isEmpty) return;

    final confirmed = await _showConfirmation(
      title: LunoraLocalization.text('Очистить историю?'),
      message: LunoraLocalization.text('Все уведомления будут удалены без возможности восстановления.', 'All notifications will be permanently deleted.'),
      confirmLabel: LunoraLocalization.text('Очистить', 'Clear'),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);

    try {
      await _service.clearHistory();
      await _refreshAfterAction();
      _showMessage(LunoraLocalization.text('История уведомлений очищена.', 'Notification history cleared.'));
    } catch (error) {
      _showMessage(LunoraLocalization.text('Не удалось очистить историю: $error', 'Could not clear history: $error'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<bool?> _showConfirmation({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(title, style: TextStyle(color: palette.text)),
          content: Text(
            message,
            style: TextStyle(color: palette.secondary, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(
                LunoraLocalization.text('Отмена'),
                style: TextStyle(color: palette.secondary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.white,
              ),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshAfterAction() async {
    final notifications = await _service.getAll();
    final unreadCount = await _service.getUnreadCount();

    if (!mounted) return;

    setState(() {
      _notifications = notifications;
      _unreadCount = unreadCount;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
  }

  String _categoryName(NotificationCategory category) {
    return switch (category) {
      NotificationCategory.tasks => LunoraLocalization.text('Задачи', 'Tasks'),
      NotificationCategory.calendar => LunoraLocalization.text('Календарь', 'Calendar'),
      NotificationCategory.finance => LunoraLocalization.text('Финансы', 'Finances'),
      NotificationCategory.study => LunoraLocalization.text('Учёба', 'Study'),
      NotificationCategory.cooking => LunoraLocalization.text('Готовка', 'Cooking'),
      NotificationCategory.importExport => LunoraLocalization.text('Импорт и экспорт', 'Import & export'),
      NotificationCategory.backups => LunoraLocalization.text('Резервные копии', 'Backups'),
      NotificationCategory.system => LunoraLocalization.text('Система', 'System'),
      NotificationCategory.other => LunoraLocalization.text('Другое', 'Other'),
    };
  }

  Color _typeColor(NotificationType type, LunoraPalette palette) {
    return switch (type) {
      NotificationType.info => palette.accent,
      NotificationType.reminder => palette.accent,
      NotificationType.warning => Colors.orange.shade700,
      NotificationType.success => Colors.green.shade700,
      NotificationType.error => Colors.red.shade700,
    };
  }

  IconData _typeIcon(NotificationType type) {
    return switch (type) {
      NotificationType.info => Icons.info_outline,
      NotificationType.reminder => Icons.alarm_outlined,
      NotificationType.warning => Icons.warning_amber_rounded,
      NotificationType.success => Icons.check_circle_outline,
      NotificationType.error => Icons.error_outline,
    };
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);

    final difference = today.difference(target).inDays;

    final time =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';

    if (difference == 0) return 'Сегодня, $time';
    if (difference == 1) return 'Вчера, $time';

    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}, $time';
  }

  Widget _buildHeader(
    BuildContext context,
    LunoraPalette palette,
    bool compact,
  ) {
    final unreadDescription = _unreadCount == 0
        ? LunoraLocalization.text('Все события на своих местах.', 'Everything is in its place.')
        : '$_unreadCount ${_unreadCount == 1
              ? LunoraLocalization.text('новое уведомление', 'new notification')
              : _unreadCount < 5
              ? LunoraLocalization.text('новых уведомления', 'new notifications')
              : LunoraLocalization.text('новых уведомлений', 'new notifications')}';
    return LunoraSectionHeader(
      title: LunoraLocalization.text('Уведомления'),
      subtitle: unreadDescription,
      icon: Icons.mark_email_unread_outlined,
      actions: [
        IconButton(
          tooltip: LunoraLocalization.text('Обновить'),
          onPressed: _isLoading ? null : _loadNotifications,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _buildFilters(LunoraPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildFilterChip(
          palette,
          label: LunoraLocalization.text('Все'),
          selected: _filter == _NotificationFilter.all,
          onSelected: () => setState(() => _filter = _NotificationFilter.all),
        ),
        _buildFilterChip(
          palette,
          label: LunoraLocalization.text('Непрочитанные'),
          selected: _filter == _NotificationFilter.unread,
          onSelected: () =>
              setState(() => _filter = _NotificationFilter.unread),
          count: _unreadCount,
        ),
        PopupMenuButton<NotificationCategory?>(
          tooltip: LunoraLocalization.text('Фильтр по категории'),
          onSelected: (category) =>
              setState(() => _selectedCategory = category),
          itemBuilder: (context) => [
            PopupMenuItem<NotificationCategory?>(
              value: null,
              child: Text(LunoraLocalization.text('Все категории')),
            ),
            ...NotificationCategory.values.map(
              (category) => PopupMenuItem<NotificationCategory?>(
                value: category,
                child: Row(
                  children: [
                    Icon(
                      _categoryIcon(category),
                      size: 17,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 9),
                    Text(_categoryName(category)),
                  ],
                ),
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: _selectedCategory == null
                  ? palette.surface
                  : palette.sagePanel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 16, color: palette.accent),
                const SizedBox(width: 7),
                Text(
                  _selectedCategory == null
                      ? LunoraLocalization.text('Все категории', 'All categories')
                      : _categoryName(_selectedCategory!),
                  style: TextStyle(color: palette.text, fontSize: 12),
                ),
                const SizedBox(width: 5),
                Icon(Icons.expand_more, size: 17, color: palette.secondary),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _categoryIcon(NotificationCategory category) {
    return switch (category) {
      NotificationCategory.tasks => Icons.task_alt_rounded,
      NotificationCategory.calendar => Icons.calendar_month_rounded,
      NotificationCategory.finance => Icons.account_balance_wallet_outlined,
      NotificationCategory.study => Icons.menu_book_rounded,
      NotificationCategory.cooking => Icons.soup_kitchen_outlined,
      NotificationCategory.importExport => Icons.import_export_rounded,
      NotificationCategory.backups => Icons.backup_outlined,
      NotificationCategory.system => Icons.settings_outlined,
      NotificationCategory.other => Icons.notifications_none_rounded,
    };
  }

  Widget _buildFilterChip(
    LunoraPalette palette, {
    required String label,
    required bool selected,
    required VoidCallback onSelected,
    int? count,
  }) {
    return FilterChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null && count > 0) ...[
            const SizedBox(width: 6),
            Text('$count', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ],
      ),
      backgroundColor: palette.surface,
      selectedColor: palette.sagePanel,
      side: BorderSide(color: selected ? palette.accent : palette.border),
      labelStyle: TextStyle(
        color: selected ? palette.text : palette.secondary,
        fontSize: 12,
      ),
    );
  }

  Widget _buildActions(LunoraPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TextButton.icon(
          onPressed: _isBusy || _unreadCount == 0 ? null : _markAllRead,
          icon: const Icon(Icons.done_all_rounded, size: 17),
          label: Text(LunoraLocalization.text('Прочитать все')),
          style: TextButton.styleFrom(foregroundColor: palette.accent),
        ),
        TextButton.icon(
          onPressed: _isBusy || _notifications.isEmpty ? null : _clearHistory,
          icon: const Icon(Icons.delete_sweep_outlined, size: 17),
          label: Text(LunoraLocalization.text('Очистить историю')),
          style: TextButton.styleFrom(foregroundColor: palette.secondary),
        ),
      ],
    );
  }

  Widget _buildDeliveryStatus(
    NotificationItem notification,
    LunoraPalette palette,
  ) {
    final status = _systemDeliveryStatus(notification);
    if (status == null) return const SizedBox.shrink();

    final color = _deliveryStatusColor(status, palette);
    final dateLabel = _deliveryDateLabel(notification);

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_deliveryStatusIcon(status), size: 13, color: color),
                const SizedBox(width: 5),
                Text(
                  LunoraLocalization.text(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (dateLabel != null)
            Text(
              dateLabel,
              style: TextStyle(color: palette.secondary, fontSize: 10.5),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
    NotificationItem notification,
    LunoraPalette palette,
    bool compact,
  ) {
    final color = _typeColor(notification.type, palette);
    final tint = switch (notification.type) {
      NotificationType.success => palette.success,
      NotificationType.warning => palette.warning,
      NotificationType.error => palette.danger,
      NotificationType.info => palette.lavender,
      NotificationType.reminder => palette.rose,
    };

    return Container(
      padding: EdgeInsets.all(compact ? 11 : 13),
      decoration: BoxDecoration(
        color: notification.isUnread
            ? tint.withValues(alpha: 0.15)
            : palette.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isUnread
              ? color.withValues(alpha: 0.42)
              : palette.border,
        ),
        boxShadow: notification.isUnread
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(_typeIcon(notification.type), color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _displayTitle(notification),
                        style: TextStyle(
                          color: palette.text,
                          fontWeight: notification.isUnread
                              ? FontWeight.w700
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (notification.isUnread)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 8),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    PopupMenuButton<String>(
                      tooltip: LunoraLocalization.text('Действия'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 32,
                      ),
                      onSelected: (value) {
                        if (value == 'read') _markRead(notification);
                        if (value == 'delete') {
                          _deleteNotification(notification);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'read',
                          child: Text(
                            notification.isRead
                                ? LunoraLocalization.text('Вернуть в непрочитанные', 'Mark as unread')
                                : LunoraLocalization.text('Отметить прочитанным', 'Mark as read'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(LunoraLocalization.text('Удалить')),
                        ),
                      ],
                      child: Icon(
                        Icons.more_horiz_rounded,
                        color: palette.secondary,
                        size: 21,
                      ),
                    ),
                  ],
                ),
                if (notification.message.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    LunoraLocalization.text(notification.message),
                    style: TextStyle(
                      color: palette.secondary,
                      fontSize: 12.5,
                      height: 1.45,
                    ),
                  ),
                ],
                _buildDeliveryStatus(notification, palette),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _categoryIcon(notification.category),
                            size: 13,
                            color: palette.accent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            LunoraLocalization.text(
                              _categoryName(notification.category),
                            ),
                            style: TextStyle(
                              color: palette.secondary,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatDate(notification.createdAt),
                      style: TextStyle(
                        color: palette.secondary,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(LunoraPalette palette) {
    final hasFilters =
        _filter == _NotificationFilter.unread || _selectedCategory != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          SvgPicture.asset(
            LunoraThemeAssets.emptyState(
              SettingsService.instance.settings.colorTheme,
              hasFilters ? 'search' : 'notifications',
            ),
            width: 150,
            height: 125,
          ),
          const SizedBox(height: 12),
          Text(
            hasFilters ? LunoraLocalization.text('Ничего не найдено', 'Nothing found') : LunoraLocalization.text('Пока тихо', 'All quiet'),
            style: TextStyle(
              color: palette.text,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hasFilters ? LunoraLocalization.text('Измени фильтры, чтобы увидеть другие уведомления.', 'Change the filters to see other notifications.') : LunoraLocalization.text('Здесь появятся напоминания и события из разных разделов Lunora.', 'Reminders and events from different Lunora sections will appear here.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.secondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactBreakpoint;
        final notifications = _visibleNotifications;

        return Stack(
          children: [
            Positioned(
              top: 92,
              right: 8,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.10,
                  child: SvgPicture.asset(
                    LunoraThemeAssets.extra(
                      SettingsService.instance.settings.colorTheme,
                    ),
                    width: 150,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 18,
              left: 4,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.09,
                  child: SvgPicture.asset(
                    LunoraThemeAssets.decoration(
                      SettingsService.instance.settings.colorTheme,
                    ),
                    width: 160,
                    height: 210,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.all(compact ? 16 : 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, palette, compact),
                      SizedBox(height: compact ? 14 : 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _buildFilters(palette)),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _buildActions(palette),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (notifications.isEmpty)
                        _buildEmptyState(palette)
                      else
                        ...notifications.map(
                          (notification) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildNotificationCard(
                              notification,
                              palette,
                              compact,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
