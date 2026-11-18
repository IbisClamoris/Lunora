import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/lunora_localization.dart';
import '../models/habit_entry.dart';
import '../repositories/habit_repository.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  final _repository = HabitRepository.instance;
  List<HabitEntry> _habits = [];
  final Map<String, Set<String>> _completionDates = {};
  DateTime _month = DateUtils.dateOnly(DateTime.now());
  bool _loading = true;
  bool _showArchived = false;

  bool get _english => LunoraLocalization.isEnglish;
  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final habits = await _repository.getAll(includeArchived: _showArchived);
      final monthFirst = DateTime(_month.year, _month.month, 1);
      final monthLast = DateTime(_month.year, _month.month + 1, 0);
      final weekStart = _today.subtract(Duration(days: (_today.weekday + 6) % 7));
      final weekEnd = weekStart.add(const Duration(days: 6));
      final first = monthFirst.isBefore(weekStart) ? monthFirst.subtract(const Duration(days: 365)) : weekStart;
      final last = monthLast.isAfter(weekEnd) ? monthLast : weekEnd;
      final dates = await Future.wait(habits.map((habit) =>
          _repository.getCompletionDates(habit.id, first, last)));
      if (!mounted) return;
      setState(() {
        _habits = habits;
        _completionDates
          ..clear()
          ..addEntries([
            for (var i = 0; i < habits.length; i++)
              MapEntry(habits[i].id, dates[i]),
          ]);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(_english ? 'Could not load habits: $error' : 'Не удалось загрузить привычки: $error');
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    await _load();
  }

  Future<void> _toggle(HabitEntry habit, DateTime date) async {
    if (date.isAfter(_today)) return;
    await _repository.toggleCompletion(habit.id, date);
    if (mounted) await _load();
  }

  Future<void> _editHabit([HabitEntry? habit]) async {
    final name = TextEditingController(text: habit?.name ?? '');
    final description = TextEditingController(text: habit?.description ?? '');
    var target = habit?.targetPerWeek ?? 7;
    var colorValue = habit?.colorValue ?? 0xFF8E9BCB;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(habit == null
              ? (_english ? 'New habit' : 'Новая привычка')
              : (_english ? 'Edit habit' : 'Редактировать привычку')),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: _english ? 'Habit name' : 'Название привычки',
                      hintText: _english ? 'Read 10 pages' : 'Читать 10 страниц',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: _english ? 'Description (optional)' : 'Описание (необязательно)',
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(_english ? 'Weekly target' : 'Цель на неделю',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    children: List.generate(7, (index) {
                      final value = index + 1;
                      return ChoiceChip(
                        label: Text('$value'),
                        selected: target == value,
                        onSelected: (_) => setDialogState(() => target = value),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  Text(_english ? 'Accent colour' : 'Цвет привычки'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    children: [
                      for (final value in const <int>[
                        0xFF8E9BCB, 0xFF7EAA91, 0xFFD29A9E,
                        0xFFC39BCB, 0xFFD0A66F, 0xFF78A9B5,
                      ])
                        GestureDetector(
                          onTap: () => setDialogState(() => colorValue = value),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Color(value),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorValue == value ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_english ? 'Cancel' : 'Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_english ? 'Save' : 'Сохранить'),
            ),
          ],
        ),
      ),
    );
    final normalizedName = name.text.trim();
    final normalizedDescription = description.text.trim();
    name.dispose();
    description.dispose();
    if (result != true || !mounted) return;
    if (normalizedName.isEmpty) {
      _message(_english ? 'Enter a habit name.' : 'Введи название привычки.');
      return;
    }
    try {
      if (habit == null) {
        await _repository.create(
          name: normalizedName,
          description: normalizedDescription,
          targetPerWeek: target,
          colorValue: colorValue,
        );
      } else {
        await _repository.update(habit.copyWith(
          name: normalizedName,
          description: normalizedDescription,
          targetPerWeek: target,
          colorValue: colorValue,
        ));
      }
      await _load();
    } catch (error) {
      _message(_english ? 'Could not save habit: $error' : 'Не удалось сохранить привычку: $error');
    }
  }

  Future<void> _deleteHabit(HabitEntry habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_english ? 'Delete habit?' : 'Удалить привычку?'),
        content: Text(_english
            ? 'Its completion history will also be deleted.'
            : 'История выполнения этой привычки тоже будет удалена.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_english ? 'Cancel' : 'Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(_english ? 'Delete' : 'Удалить')),
        ],
      ),
    );
    if (confirmed == true) {
      await _repository.delete(habit.id);
      await _load();
    }
  }

  Future<void> _archiveHabit(HabitEntry habit) async {
    await _repository.archive(habit.id, archived: !habit.isArchived);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final locale = _english ? 'en_US' : 'ru_RU';
    final monthTitle = DateFormat('MMMM yyyy', locale).format(_month);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(compact ? 18 : 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_english ? 'Your habits' : 'Твои привычки',
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 5),
                              Text(_english
                                  ? 'Small steps, repeated with care.'
                                  : 'Маленькие шаги, которые складываются в большие перемены.',
                                  style: TextStyle(color: colors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => _editHabit(),
                          icon: const Icon(Icons.add),
                          label: Text(_english ? 'Add habit' : 'Добавить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: _english ? 'Previous month' : 'Предыдущий месяц',
                              onPressed: () => _changeMonth(-1),
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Expanded(
                              child: Text(monthTitle[0].toUpperCase() + monthTitle.substring(1),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                            ),
                            IconButton(
                              tooltip: _english ? 'Next month' : 'Следующий месяц',
                              onPressed: _month.year == _today.year && _month.month == _today.month
                                  ? null : () => _changeMonth(1),
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(child: Text(_english ? 'Your routine' : 'Твой ритм',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700))),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _showArchived = !_showArchived);
                            _load();
                          },
                          icon: Icon(_showArchived ? Icons.visibility_off_outlined : Icons.archive_outlined),
                          label: Text(_showArchived
                              ? (_english ? 'Hide archived' : 'Скрыть архив')
                              : (_english ? 'Show archived' : 'Показать архив')),
                        ),
                      ],
                    ),
                    if (_loading)
                      const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                    else if (_habits.isEmpty)
                      _EmptyHabits(english: _english, onAdd: () => _editHabit())
                    else
                      ..._habits.map((habit) => _HabitCard(
                            habit: habit,
                            dates: _completionDates[habit.id] ?? {},
                            month: _month,
                            today: _today,
                            english: _english,
                            onToggle: (date) => _toggle(habit, date),
                            onEdit: () => _editHabit(habit),
                            onArchive: () => _archiveHabit(habit),
                            onDelete: () => _deleteHabit(habit),
                          )),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    required this.habit,
    required this.dates,
    required this.month,
    required this.today,
    required this.english,
    required this.onToggle,
    required this.onEdit,
    required this.onArchive,
    required this.onDelete,
  });

  final HabitEntry habit;
  final Set<String> dates;
  final DateTime month;
  final DateTime today;
  final bool english;
  final ValueChanged<DateTime> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = Color(habit.colorValue);
    final first = DateTime(month.year, month.month, 1);
    final offset = (first.weekday + 6) % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final cells = ((offset + days + 6) ~/ 7) * 7;
    final weekStart = today.subtract(Duration(days: (today.weekday + 6) % 7));
    final weekDone = List.generate(7, (i) => weekStart.add(Duration(days: i)))
        .where((date) => dates.contains(_key(date))).length;
    var streak = 0;
    var cursor = dates.contains(_key(today))
        ? today
        : today.subtract(const Duration(days: 1));
    while (dates.contains(_key(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    final locale = english ? 'en_US' : 'ru_RU';
    final weekdayLabels = english
        ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : ['П', 'В', 'С', 'Ч', 'П', 'С', 'В'];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(color: accent.withValues(alpha: .14), borderRadius: BorderRadius.circular(13)),
                  child: Icon(IconData(habit.iconCodePoint, fontFamily: 'MaterialIcons'), color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      if (habit.description.isNotEmpty)
                        Text(habit.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'archive') onArchive();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'edit', child: Text(english ? 'Edit' : 'Редактировать')),
                    PopupMenuItem(value: 'archive', child: Text(habit.isArchived
                        ? (english ? 'Restore' : 'Восстановить')
                        : (english ? 'Archive' : 'В архив'))),
                    PopupMenuItem(value: 'delete', child: Text(english ? 'Delete' : 'Удалить')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(english
                      ? '$weekDone / ${habit.targetPerWeek} this week'
                      : '$weekDone / ${habit.targetPerWeek} на этой неделе',
                      style: TextStyle(color: colors.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ),
                if (habit.targetPerWeek == 7)
                  Row(children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFE49A62), size: 18),
                    const SizedBox(width: 4),
                    Text(english ? '$streak day streak' : 'Серия: $streak дн.',
                        style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                  ])
                else
                  Text(english ? 'Goal: ${habit.targetPerWeek} / week' : 'Цель: ${habit.targetPerWeek} / неделю',
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (weekDone / habit.targetPerWeek).clamp(0.0, 1.0),
                minHeight: 7,
                backgroundColor: colors.surfaceContainerHighest,
                color: accent,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: Text(english ? 'Completion history' : 'История выполнения',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
                Text(english ? 'Tap a day to mark it' : 'Нажми на день, чтобы отметить',
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final label in weekdayLabels)
                  Expanded(child: Center(child: Text(label,
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11)))),
              ],
            ),
            const SizedBox(height: 5),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisSpacing: 5, crossAxisSpacing: 5,
                childAspectRatio: 1.55,
              ),
              itemBuilder: (context, index) {
                final day = index - offset + 1;
                if (day < 1 || day > days) return const SizedBox.shrink();
                final date = DateTime(month.year, month.month, day);
                final complete = dates.contains(_key(date));
                final future = date.isAfter(today);
                final isToday = DateUtils.isSameDay(date, today);
                return Tooltip(
                  message: DateFormat('d MMMM yyyy', locale).format(date),
                  child: InkWell(
                    onTap: future ? null : () => onToggle(date),
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      decoration: BoxDecoration(
                        color: complete ? accent.withValues(alpha: .22) : colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isToday ? accent : colors.outlineVariant,
                          width: isToday ? 1.7 : .7,
                        ),
                      ),
                      child: Center(
                        child: Text('$day',
                          style: TextStyle(
                            color: complete ? accent : (future ? colors.onSurface.withValues(alpha: .3) : colors.onSurfaceVariant),
                            fontWeight: complete || isToday ? FontWeight.w800 : FontWeight.w500,
                            fontSize: 12,
                          )),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits({required this.english, required this.onAdd});
  final bool english;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(34),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.spa_outlined, size: 44, color: colors.primary),
              const SizedBox(height: 12),
              Text(english ? 'A little habit can change a lot.' : 'Даже маленькая привычка может многое изменить.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(english ? 'Add your first habit to begin.' : 'Добавь первую привычку, чтобы начать.',
                  style: TextStyle(color: colors.onSurfaceVariant)),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add),
                  label: Text(english ? 'Create a habit' : 'Создать привычку')),
            ],
          ),
        ),
      ),
    );
  }
}
