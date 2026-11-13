import 'package:lunora/core/settings/settings_service.dart';
import 'package:lunora/core/theme/lunora_theme_assets.dart';
import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:lunora/core/theme/lunora_dialog.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lunora/shared/widgets/lunora_section_header.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:uuid/uuid.dart';

import 'package:lunora/core/tasks/models/task.dart';
import 'package:lunora/core/tasks/repositories/task_repository.dart';

import 'package:lunora/features/study/models/study_item.dart';
import 'package:lunora/features/study/models/study_period.dart';
import 'package:lunora/features/study/repositories/study_repository.dart';

import 'package:lunora/features/finance/models/finance_models.dart';
import 'package:lunora/features/finance/repositories/finance_repository.dart';

import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/features/notifications/repositories/notification_repository.dart';

enum _CalendarFilter { tasks, study, finance }

enum _EntryType { task, study, period, payment }

class _CalendarEntry {
  const _CalendarEntry({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
    this.time,
    this.task,
    this.studyItem,
    this.studyPeriod,
    this.debt,
    this.reminders = const [],
  });

  final String id;
  final String title;
  final String description;
  final DateTime date;
  final int? time;
  final _EntryType type;

  final Task? task;
  final StudyItem? studyItem;
  final StudyPeriod? studyPeriod;
  final FinanceDebt? debt;

  final List<NotificationItem> reminders;

  String get timeLabel {
    if (time == null) return 'Весь день';

    final hour = time! ~/ 60;
    final minute = time! % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  final TaskRepository _taskRepository = TaskRepository.instance;
  final StudyRepository _studyRepository = StudyRepository.instance;
  final FinanceRepository _financeRepository = FinanceRepository.instance;
  final NotificationRepository _notificationRepository =
      NotificationRepository();

  DateTime _displayedMonth = DateUtils.dateOnly(DateTime.now());
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());

  List<Task> _tasks = [];
  List<StudyItem> _studyItems = [];
  List<StudyPeriod> _studyPeriods = [];
  List<FinanceDebt> _debts = [];
  List<NotificationItem> _notifications = [];

  bool _isLoading = true;
  String? _error;

  final Set<_CalendarFilter> _activeFilters = {
    _CalendarFilter.tasks,
    _CalendarFilter.study,
    _CalendarFilter.finance,
  };

  @override
  void initState() {
    super.initState();
    _initializeCalendar();
  }

  Future<void> _initializeCalendar() async {
    try {
      await initializeDateFormatting('ru', null);

      if (!mounted) return;

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'Не удалось инициализировать календарь: $e';
      });
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _taskRepository.getAll(),
        _studyRepository.getItems(),
        _studyRepository.getPeriods(),
        _financeRepository.getDebts(status: FinanceDebtStatus.active),
        _notificationRepository.getAll(limit: 1000),
      ]);

      if (!mounted) return;

      setState(() {
        _tasks = results[0] as List<Task>;
        _studyItems = results[1] as List<StudyItem>;
        _studyPeriods = results[2] as List<StudyPeriod>;
        _debts = results[3] as List<FinanceDebt>;
        _notifications = results[4] as List<NotificationItem>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _error = 'Не удалось загрузить данные календаря: $e';
      });
    }
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<_CalendarEntry> get _allEntries {
    final entries = <_CalendarEntry>[];

    if (_activeFilters.contains(_CalendarFilter.tasks)) {
      for (final task in _tasks) {
        if (task.dueDate == null) continue;

        entries.add(
          _CalendarEntry(
            id: task.id,
            title: task.title,
            description: task.description,
            date: _dateOnly(task.dueDate!),
            time: task.dueTimeMinutes,
            type: _EntryType.task,
            task: task,
            reminders: _findReminders(task.id, const ['task', 'tasks']),
          ),
        );
      }
    }

    if (_activeFilters.contains(_CalendarFilter.study)) {
      for (final item in _studyItems) {
        if (item.scheduledAt != null) {
          entries.add(
            _CalendarEntry(
              id: '${item.id}_scheduled',
              title: item.title,
              description: _studyDescription(item),
              date: _dateOnly(item.scheduledAt!),
              time: item.scheduledAt!.hour * 60 + item.scheduledAt!.minute,
              type: _EntryType.study,
              studyItem: item,
              reminders: _findReminders(item.id, const [
                'study',
                'study_planner',
              ]),
            ),
          );
        }

        if (item.dueAt != null &&
            (item.scheduledAt == null ||
                !_sameDate(item.dueAt!, item.scheduledAt!))) {
          entries.add(
            _CalendarEntry(
              id: '${item.id}_deadline',
              title: LunoraLocalization.text('Срок: ${item.title}'),
              description: _studyDescription(item),
              date: _dateOnly(item.dueAt!),
              type: _EntryType.study,
              studyItem: item,
              reminders: _findReminders(item.id, const [
                'study',
                'study_planner',
              ]),
            ),
          );
        }
      }

      // Отображаем учебный период на каждом дне его продолжительности.
      for (final period in _studyPeriods) {
        if (period.startsAt == null && period.endsAt == null) {
          continue;
        }

        final startDate = _dateOnly(period.startsAt ?? period.endsAt!);

        final endDate = _dateOnly(period.endsAt ?? period.startsAt!);

        final lastDate = endDate.isBefore(startDate) ? startDate : endDate;

        for (
          var date = startDate;
          !date.isAfter(lastDate);
          date = date.add(const Duration(days: 1))
        ) {
          entries.add(
            _CalendarEntry(
              id: '${period.id}_${date.year}_${date.month}_${date.day}',
              title: period.title,
              description: _periodDescription(period),
              date: date,
              type: _EntryType.period,
              studyPeriod: period,
            ),
          );
        }
      }
    }

    if (_activeFilters.contains(_CalendarFilter.finance)) {
      for (final debt in _debts) {
        final date = debt.nextPaymentDate;

        if (date == null || debt.monthlyPaymentMinor <= 0) {
          continue;
        }

        entries.add(
          _CalendarEntry(
            id: debt.id,
            title: LunoraLocalization.text('Платёж: ${debt.name}'),
            description: debt.creditor,
            date: _dateOnly(date),
            type: _EntryType.payment,
            debt: debt,
            reminders: _findReminders(debt.id, const ['finance']),
          ),
        );
      }
    }

    entries.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;

      return (a.time ?? -1).compareTo(b.time ?? -1);
    });

    return entries;
  }

  List<NotificationItem> _findReminders(String recordId, List<String> modules) {
    return _notifications.where((notification) {
      return notification.sourceRecordId == recordId &&
          modules.contains(notification.sourceModule);
    }).toList();
  }

  String _studyDescription(StudyItem item) {
    switch (item.type) {
      case StudyItemType.lecture:
        return 'Лекция';
      case StudyItemType.onlineLecture:
        return 'Онлайн-лекция';
      case StudyItemType.test:
        return 'Тест';
      case StudyItemType.writtenAssignment:
        return 'Письменное задание';
      case StudyItemType.exam:
        return 'Экзамен';
      case StudyItemType.credit:
        return 'Зачёт';
      case StudyItemType.practice:
        return 'Практика';
      case StudyItemType.coursework:
        return 'Курсовая работа';
      case StudyItemType.diploma:
        return 'Дипломная работа';
      case StudyItemType.other:
        return 'Учебное событие';
    }
  }

  String _periodDescription(StudyPeriod period) {
    switch (period.type) {
      case StudyPeriodType.semester:
        return 'Учебный семестр';
      case StudyPeriodType.examSession:
        return 'Экзаменационная сессия';
      case StudyPeriodType.practice:
        return 'Практика';
      case StudyPeriodType.other:
        return 'Учебный период';
    }
  }

  List<_CalendarEntry> get _selectedEntries {
    return _allEntries
        .where((entry) => _sameDate(entry.date, _selectedDate))
        .toList();
  }

  List<_CalendarEntry> _entriesForDate(DateTime date) {
    return _allEntries.where((entry) => _sameDate(entry.date, date)).toList();
  }

  List<DateTime> get _calendarDays {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);

    final offset = firstDay.weekday - 1;
    final start = firstDay.subtract(Duration(days: offset));

    final lastDay = DateTime(
      _displayedMonth.year,
      _displayedMonth.month + 1,
      0,
    );

    final totalDays = offset + lastDay.day;
    final rows = (totalDays / 7).ceil();

    return List.generate(rows * 7, (index) => start.add(Duration(days: index)));
  }

  void _changeMonth(int amount) {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + amount,
        1,
      );
    });
  }

  void _goToToday() {
    final today = DateUtils.dateOnly(DateTime.now());

    setState(() {
      _selectedDate = today;
      _displayedMonth = DateTime(today.year, today.month, 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = _dateOnly(date);

      if (date.month != _displayedMonth.month ||
          date.year != _displayedMonth.year) {
        _displayedMonth = DateTime(date.year, date.month, 1);
      }
    });
  }

  Future<void> _openTaskEditor({Task? task}) async {
    final result = await showLunoraDialog<_TaskDraft>(
      context: context,
      builder: (_) => _TaskEditorDialog(initialDate: _selectedDate, task: task),
    );

    if (result == null) return;

    try {
      if (task == null) {
        final now = DateTime.now();

        final newTask = Task(
          id: const Uuid().v4(),
          title: result.title,
          description: result.description,
          status: result.status,
          priority: result.priority,
          dueDate: result.dueDate,
          dueTimeMinutes: result.dueTimeMinutes,
          createdAt: now,
          updatedAt: now,
          completedAt: result.status == TaskStatus.completed ? now : null,
        );

        await _taskRepository.create(newTask);
      } else {
        final updated = task.copyWith(
          title: result.title,
          description: result.description,
          status: result.status,
          priority: result.priority,
          dueDate: result.dueDate,
          dueTimeMinutes: result.dueTimeMinutes,
          clearDueDate: result.dueDate == null,
          clearDueTime: result.dueTimeMinutes == null,
          completedAt: result.status == TaskStatus.completed
              ? (task.completedAt ?? DateTime.now())
              : null,
          clearCompletedAt: result.status != TaskStatus.completed,
          updatedAt: DateTime.now(),
        );

        await _taskRepository.update(updated);
      }

      await _loadData();
    } catch (e) {
      _showMessage('Не удалось сохранить задачу: $e');
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showLunoraDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LunoraLocalization.text('Удалить задачу?')),
        content: Text(
          LunoraLocalization.text('«${task.title}» будет удалена.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LunoraLocalization.text('Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LunoraLocalization.text('Удалить')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _taskRepository.delete(task.id);
    await _loadData();
  }

  Future<void> _changeTaskStatus(Task task, TaskStatus status) async {
    final updated = task.copyWith(
      status: status,
      completedAt: status == TaskStatus.completed ? DateTime.now() : null,
      clearCompletedAt: status != TaskStatus.completed,
      updatedAt: DateTime.now(),
    );

    await _taskRepository.update(updated);
    await _loadData();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
  }

  Color _entryColor(_EntryType type, BuildContext context) {
    switch (type) {
      case _EntryType.task:
        return const Color(0xFF91A98D);
      case _EntryType.study:
        return const Color(0xFF9C91B8);
      case _EntryType.period:
        return const Color(0xFFB49AB8);
      case _EntryType.payment:
        return const Color(0xFFC69A86);
    }
  }

  IconData _entryIcon(_EntryType type) {
    switch (type) {
      case _EntryType.task:
        return Icons.check_circle_outline_rounded;
      case _EntryType.study:
        return Icons.menu_book_rounded;
      case _EntryType.period:
        return Icons.school_outlined;
      case _EntryType.payment:
        return Icons.account_balance_wallet_outlined;
    }
  }

  String _monthTitle(DateTime date) {
    final value = DateFormat('LLLL yyyy', 'ru').format(date);
    return value[0].toUpperCase() + value.substring(1);
  }

  String _selectedDateTitle(DateTime date) {
    final value = DateFormat('d MMMM yyyy', 'ru').format(date);
    return value[0].toUpperCase() + value.substring(1);
  }

  String _taskStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.planned:
        return 'Запланирована';
      case TaskStatus.inProgress:
        return 'В процессе';
      case TaskStatus.completed:
        return 'Выполнена';
      case TaskStatus.cancelled:
        return 'Отменена';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildError()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 1050;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 18, 28, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1450),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 8),
                            _decorativeDivider(
                              'lunora-divider-06.svg',
                              height: 20,
                            ),
                            const SizedBox(height: 12),
                            _buildFilters(),
                            const SizedBox(height: 14),
                            if (wide)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 11, child: _buildCalendar()),
                                  const SizedBox(width: 16),
                                  Expanded(flex: 9, child: _buildDayPanel()),
                                ],
                              )
                            else ...[
                              _buildCalendar(),
                              const SizedBox(height: 20),
                              _buildDayPanel(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 42),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _initializeCalendar,
              icon: const Icon(Icons.refresh),
              label: Text(LunoraLocalization.text('Повторить')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LunoraSectionHeader(
      title: LunoraLocalization.text('Календарь'),
      subtitle: LunoraLocalization.text('Все планы и события в одном месте'),
      icon: Icons.calendar_month_outlined,
      actions: [
        OutlinedButton.icon(
          onPressed: _goToToday,
          icon: const Icon(Icons.today_outlined),
          label: Text(LunoraLocalization.text('Сегодня')),
        ),
        FilledButton.icon(
          onPressed: () => _openTaskEditor(),
          icon: const Icon(Icons.add),
          label: Text(LunoraLocalization.text('Задача')),
        ),
        IconButton(
          tooltip: LunoraLocalization.text('Обновить'),
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _botanicalMark(
    String asset, {
    double width = 72,
    double height = 72,
    double opacity = 0.88,
  }) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: SvgPicture.asset(
          LunoraThemeAssets.decoration(
            SettingsService.instance.settings.colorTheme,
          ),
          width: width,
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _decorativeDivider(String asset, {double height = 22}) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.82,
        child: SvgPicture.asset(
          LunoraThemeAssets.divider(
            SettingsService.instance.settings.colorTheme,
          ),
          width: double.infinity,
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _filterChip(
          'Задачи и планер',
          _CalendarFilter.tasks,
          const Color(0xFF91A98D),
          Icons.check_circle_outline,
        ),
        _filterChip(
          'Учёба',
          _CalendarFilter.study,
          const Color(0xFF9C91B8),
          Icons.menu_book_outlined,
        ),
        _filterChip(
          'Финансы',
          _CalendarFilter.finance,
          const Color(0xFFC69A86),
          Icons.account_balance_wallet_outlined,
        ),
      ],
    );
  }

  Widget _filterChip(
    String label,
    _CalendarFilter filter,
    Color color,
    IconData icon,
  ) {
    final selected = _activeFilters.contains(filter);

    return FilterChip(
      selected: selected,
      showCheckmark: false,
      avatar: Icon(icon, size: 17, color: color),
      label: Text(label),
      onSelected: (value) {
        setState(() {
          if (value) {
            _activeFilters.add(filter);
          } else {
            _activeFilters.remove(filter);
          }
        });
      },
    );
  }

  Widget _buildCalendar() {
    final colors = Theme.of(context).colorScheme;
    final days = _calendarDays;

    return _panel(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _monthTitle(_displayedMonth),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 3),
          _decorativeDivider('lunora-divider-03.svg', height: 13),
          const SizedBox(height: 7),
          Row(
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: days.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 3,
              crossAxisSpacing: 3,
              childAspectRatio: 1.38,
            ),
            itemBuilder: (context, index) {
              final date = days[index];
              final selected = _sameDate(date, _selectedDate);
              final today = _sameDate(date, DateTime.now());
              final inMonth = date.month == _displayedMonth.month;
              final entries = _entriesForDate(date);

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _selectDate(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: selected
                          ? colors.primaryContainer
                          : today
                          ? colors.surfaceContainerHighest
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: today && !selected
                          ? Border.all(color: colors.primary, width: 1)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontWeight: selected || today
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: !inMonth
                                ? colors.onSurface.withValues(alpha: 0.3)
                                : selected
                                ? colors.onPrimaryContainer
                                : colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        SizedBox(
                          height: 7,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: _eventDots(entries),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _legend('Задачи', const Color(0xFF91A98D)),
              _legend('Учёба', const Color(0xFF9C91B8)),
              _legend('Платежи', const Color(0xFFC69A86)),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _eventDots(List<_CalendarEntry> entries) {
    final types = <_EntryType>{};

    for (final entry in entries) {
      types.add(entry.type);
    }

    return types.take(4).map((type) {
      return Container(
        width: 6,
        height: 6,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: _entryColor(type, context),
          shape: BoxShape.circle,
        ),
      );
    }).toList();
  }

  Widget _legend(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  String _entryCountLabel(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'запись';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'записи';
    }
    return 'записей';
  }

  Widget _buildDayPanel() {
    final entries = _selectedEntries;

    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedDateTitle(_selectedDate),
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${entries.length} ${_entryCountLabel(entries.length)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              _botanicalMark('lunora-clover.svg', width: 38, height: 38),
            ],
          ),
          const SizedBox(height: 2),
          _decorativeDivider('lunora-divider-09.svg', height: 16),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            _buildEmptyDay()
          else
            ...entries.map(_buildEntryCard),
        ],
      ),
    );
  }

  Widget _buildEmptyDay() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 35),
      child: Center(
        child: Column(
          children: [
            SvgPicture.asset(
              LunoraThemeAssets.decoration(
                SettingsService.instance.settings.colorTheme,
              ),
              width: 112,
              height: 92,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            _botanicalMark('lunora-chamomile.svg', width: 46, height: 42),
            const SizedBox(height: 8),
            Text(
              LunoraLocalization.text(
                'На этот день пока ничего не запланировано',
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _openTaskEditor(),
              icon: const Icon(Icons.add),
              label: Text(LunoraLocalization.text('Добавить задачу')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(_CalendarEntry entry) {
    final color = _entryColor(entry.type, context);
    final task = entry.task;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.10),
          Theme.of(context).colorScheme.surfaceContainerLow,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openEntryDetails(entry),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_entryIcon(entry.type), color: color, size: 21),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (entry.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry.description,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        children: [
                          _smallLabel(entry.timeLabel),
                          if (task != null)
                            _smallLabel(_taskStatusLabel(task.status)),
                          if (entry.reminders.isNotEmpty)
                            _smallLabel(
                              'Напоминаний: ${entry.reminders.length}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (task != null)
                  PopupMenuButton<String>(
                    tooltip: LunoraLocalization.text('Действия'),
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _openTaskEditor(task: task);
                          break;
                        case 'complete':
                          _changeTaskStatus(task, TaskStatus.completed);
                          break;
                        case 'delete':
                          _deleteTask(task);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(LunoraLocalization.text('Редактировать')),
                      ),
                      if (task.status != TaskStatus.completed)
                        PopupMenuItem(
                          value: 'complete',
                          child: Text(LunoraLocalization.text('Завершить')),
                        ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(LunoraLocalization.text('Удалить')),
                      ),
                    ],
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallLabel(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Future<void> _openEntryDetails(_CalendarEntry entry) async {
    if (entry.task != null) {
      await _openTaskEditor(task: entry.task);
      return;
    }

    final title = entry.title;
    String description = entry.description;

    if (entry.studyItem != null) {
      final item = entry.studyItem!;

      description = [
        _studyDescription(item),
        if (item.description.isNotEmpty) item.description,
        if (item.notes.isNotEmpty) item.notes,
        if (item.grade.isNotEmpty) 'Оценка: ${item.grade}',
      ].join('\n\n');
    } else if (entry.studyPeriod != null) {
      final period = entry.studyPeriod!;

      description = [
        _periodDescription(period),
        if (period.description.isNotEmpty) period.description,
        if (period.startsAt != null)
          'Начало: ${DateFormat('dd.MM.yyyy').format(period.startsAt!)}',
        if (period.endsAt != null)
          'Окончание: ${DateFormat('dd.MM.yyyy').format(period.endsAt!)}',
      ].join('\n\n');
    } else if (entry.debt != null) {
      final debt = entry.debt!;

      description = [
        'Кредитор: ${debt.creditor}',
        'Дата платежа: ${DateFormat('dd.MM.yyyy').format(debt.nextPaymentDate!)}',
        'Ежемесячный платёж: ${(debt.monthlyPaymentMinor / 100).toStringAsFixed(2)}',
      ].join('\n');
    }

    if (!mounted) return;

    await showLunoraDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            description.isEmpty
                ? 'Дополнительной информации нет.'
                : description,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LunoraLocalization.text('Закрыть')),
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        image: Theme.of(context).brightness == Brightness.dark
            ? null
            : DecorationImage(
                image: AssetImage(
                  LunoraThemeAssets.texture(
                    SettingsService.instance.settings.colorTheme,
                  ),
                ),
                repeat: ImageRepeat.repeat,
                scale: 2,
                opacity: 0.16,
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: child,
    );
  }
}

class _TaskDraft {
  const _TaskDraft({
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.dueDate,
    required this.dueTimeMinutes,
  });

  final String title;
  final String description;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final int? dueTimeMinutes;
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({required this.initialDate, this.task});

  final DateTime initialDate;
  final Task? task;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  late TaskStatus _status;
  late TaskPriority _priority;

  DateTime? _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );

    _status = task?.status ?? TaskStatus.planned;
    _priority = task?.priority ?? TaskPriority.normal;
    _date = task?.dueDate ?? widget.initialDate;

    final dueTimeMinutes = task?.dueTimeMinutes;

    if (dueTimeMinutes != null) {
      _time = TimeOfDay(
        hour: dueTimeMinutes ~/ 60,
        minute: dueTimeMinutes % 60,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selected != null) {
      setState(() => _date = selected);
    }
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );

    if (selected != null) {
      setState(() => _time = selected);
    }
  }

  void _save() {
    final title = _titleController.text.trim();

    if (title.isEmpty) return;

    Navigator.pop(
      context,
      _TaskDraft(
        title: title,
        description: _descriptionController.text.trim(),
        status: _status,
        priority: _priority,
        dueDate: _date,
        dueTimeMinutes: _time == null ? null : _time!.hour * 60 + _time!.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.task != null;

    return AlertDialog(
      title: Text(editing ? 'Редактирование задачи' : 'Новая задача'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: LunoraLocalization.text('Название'),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: LunoraLocalization.text('Описание'),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskStatus>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: LunoraLocalization.text('Статус'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: TaskStatus.planned,
                    child: Text(LunoraLocalization.text('Запланирована')),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.inProgress,
                    child: Text(LunoraLocalization.text('В процессе')),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.completed,
                    child: Text(LunoraLocalization.text('Выполнена')),
                  ),
                  DropdownMenuItem(
                    value: TaskStatus.cancelled,
                    child: Text(LunoraLocalization.text('Отменена')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: InputDecoration(
                  labelText: LunoraLocalization.text('Приоритет'),
                  border: OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: TaskPriority.low,
                    child: Text(LunoraLocalization.text('Низкий')),
                  ),
                  DropdownMenuItem(
                    value: TaskPriority.normal,
                    child: Text(LunoraLocalization.text('Обычный')),
                  ),
                  DropdownMenuItem(
                    value: TaskPriority.high,
                    child: Text(LunoraLocalization.text('Высокий')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _priority = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _selectDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        _date == null
                            ? 'Без даты'
                            : DateFormat('dd.MM.yyyy').format(_date!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: LunoraLocalization.text('Убрать дату'),
                    onPressed: () {
                      setState(() {
                        _date = null;
                        _time = null;
                      });
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _date == null ? null : _selectTime,
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _time == null ? 'Без времени' : _time!.format(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: LunoraLocalization.text('Убрать время'),
                    onPressed: () => setState(() => _time = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(LunoraLocalization.text('Отмена')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(LunoraLocalization.text('Сохранить')),
        ),
      ],
    );
  }
}
