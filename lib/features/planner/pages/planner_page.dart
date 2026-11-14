import 'package:lunora/core/settings/settings_service.dart';
import 'package:lunora/core/theme/lunora_theme_assets.dart';
import 'package:lunora/core/localization/lunora_localization.dart';

import 'dart:io';

import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';
import 'package:lunora/core/theme/lunora_dialog.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lunora/shared/widgets/lunora_section_header.dart';

import 'package:lunora/features/planner/models/planner_goal.dart';
import 'package:lunora/features/planner/repositories/planner_repository.dart';
import 'package:lunora/core/tasks/models/task.dart';
import 'package:lunora/core/tasks/repositories/task_repository.dart';
import 'package:lunora/core/theme/app_theme.dart';
import 'package:lunora/core/import_export/services/excel_service.dart';
import 'package:lunora/features/planner/services/planner_excel_import_service.dart';

enum _PlannerView { month, week }

class PlannerPage extends StatefulWidget {
  final bool openNewNoteOnStart;

  const PlannerPage({super.key, this.openNewNoteOnStart = false});

  @override
  State<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends State<PlannerPage> {
  static List<String> get _months => LunoraLocalization.isEnglish
      ? ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']
      : [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  static List<String> get _weekdays => LunoraLocalization.isEnglish
      ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
      : [
    'Пн',
    'Вт',
    'Ср',
    'Чт',
    'Пт',
    'Сб',
    'Вс',
  ];

  final PlannerRepository _plannerRepository = PlannerRepository.instance;
  final TaskRepository _taskRepository = TaskRepository.instance;

  DateTime _selectedDate = DateTime.now();
  _PlannerView _view = _PlannerView.month;

  List<PlannerGoal> _goals = [];
  List<Task> _tasks = [];
  List<Map<String, Object?>> _notes = [];

  bool _loading = true;

  int get _month => _selectedDate.month;
  int get _year => _selectedDate.year;

  DateTime get _monthStart => DateTime(_year, _month, 1);

  DateTime get _weekStart {
    final date = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    return date.subtract(Duration(days: date.weekday - 1));
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  LunoraPalette get _palette => Theme.of(context).extension<LunoraPalette>()!;

  @override
  void initState() {
    super.initState();
    _loadData();
    if (widget.openNewNoteOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showNoteDialog();
      });
    }
  }

  Future<void> _importPlanner() async {
    try {
      final result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xlsm'],
      );
      if (result == null || result.path == null || result.path!.isEmpty) return;
      final document = await ExcelService.instance.readWorkbook(
        File(result.path!),
      );
      final importResult = await PlannerExcelImportService.instance
          .importWorkbook(document);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LunoraLocalization.text(importResult.message))),
      );
      if (importResult.success) await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось импортировать планер: $error'),
          ),
        ),
      );
    }
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final results = await Future.wait([
        _plannerRepository.getGoals(month: _month, year: _year),
        _taskRepository.getAll(),
        _plannerRepository.getNotes(),
      ]);

      if (!mounted) return;

      setState(() {
        _goals = results[0] as List<PlannerGoal>;
        _tasks = results[1] as List<Task>;
        _notes = results[2] as List<Map<String, Object?>>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LunoraLocalization.text('Не удалось загрузить планер: $error'),
          ),
        ),
      );
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(_year, _month + offset, 1);
    });

    _loadData();
  }

  void _changeWeek(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset * 7));
    });
  }

  void _selectDate(DateTime date) {
    setState(() => _selectedDate = date);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _formatTime(int? minutes) {
    if (minutes == null) return LunoraLocalization.text('Весь день', 'All day');

    final hour = minutes ~/ 60;
    final minute = minutes % 60;

    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  List<Task> get _selectedTasks {
    return _tasks.where((task) {
      final date = task.dueDate;
      return date != null && _sameDay(date, _selectedDate);
    }).toList()..sort((a, b) {
      if (a.dueTimeMinutes == null && b.dueTimeMinutes != null) {
        return -1;
      }

      if (a.dueTimeMinutes != null && b.dueTimeMinutes == null) {
        return 1;
      }

      return (a.dueTimeMinutes ?? 0).compareTo(b.dueTimeMinutes ?? 0);
    });
  }

  List<Task> _tasksForDate(DateTime date) {
    return _tasks.where((task) {
      return task.dueDate != null && _sameDay(task.dueDate!, date);
    }).toList();
  }

  Widget _sectionTitle(String title, {Widget? trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _palette.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _buildViewSwitcher() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _palette.border),
      ),
      child: Row(
        children: [
          _viewButton(LunoraLocalization.text('Месяц'), _PlannerView.month),
          _viewButton(LunoraLocalization.text('Неделя'), _PlannerView.week),
        ],
      ),
    );
  }

  Widget _viewButton(String title, _PlannerView view) {
    final selected = _view == view;

    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _view = view),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _palette.sagePanel : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? _palette.text : _palette.secondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodHeader() {
    final title = _view == _PlannerView.month
        ? '${_months[_month - 1]} $_year'
        : '${_formatDate(_weekStart)} — ${_formatDate(_weekEnd)}';

    return Row(
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {
            if (_view == _PlannerView.month) {
              _changeMonth(-1);
            } else {
              _changeWeek(-1);
            }
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _palette.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {
            if (_view == _PlannerView.month) {
              _changeMonth(1);
            } else {
              _changeWeek(1);
            }
          },
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: LunoraLocalization.text('Сегодня'),
          onPressed: () {
            setState(() => _selectedDate = DateTime.now());
            _loadData();
          },
          icon: Icon(Icons.today_outlined, color: _palette.accent),
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(7, (index) {
              return Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      _weekdays[index],
                      style: TextStyle(
                        color: _palette.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_view == _PlannerView.month)
            _buildMonthGrid()
          else
            _buildWeekGrid(),
        ],
      ),
    );
  }

  Widget _buildMonthGrid() {
    final firstWeekday = _monthStart.weekday - 1;
    final daysInMonth = DateTime(_year, _month + 1, 0).day;

    final totalCells = ((firstWeekday + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: totalCells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        mainAxisExtent: 42,
      ),
      itemBuilder: (context, index) {
        final day = index - firstWeekday + 1;

        if (day < 1 || day > daysInMonth) {
          return const SizedBox.shrink();
        }

        return _buildDayCell(DateTime(_year, _month, day));
      },
    );
  }

  Widget _buildWeekGrid() {
    return Row(
      children: List.generate(7, (index) {
        final date = _weekStart.add(Duration(days: index));

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: SizedBox(height: 42, child: _buildDayCell(date)),
          ),
        );
      }),
    );
  }

  Widget _buildDayCell(DateTime date) {
    final selected = _sameDay(date, _selectedDate);
    final today = _sameDay(date, DateTime.now());
    final tasks = _tasksForDate(date);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _selectDate(date),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? _palette.sagePanel : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: today ? Border.all(color: _palette.accent) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: selected ? _palette.text : _palette.secondary,
                fontSize: 12,
                fontWeight: selected || today
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 3),
            if (tasks.isNotEmpty)
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: _palette.accent,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTasks() {
    final tasks = _selectedTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          LunoraLocalization.text('Задачи на ${_formatDate(_selectedDate)}', 'Tasks for ${_formatDate(_selectedDate)}'),
          trailing: Text(
            '${tasks.length}',
            style: TextStyle(color: _palette.secondary),
          ),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          _emptyCard(LunoraLocalization.text('На этот день задач пока нет.'))
        else
          ...tasks.map(_buildTaskCard),
      ],
    );
  }

  Widget _buildTaskCard(Task task) {
    final completed = task.status == TaskStatus.completed;
    final overdue = task.isOverdue;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _palette.border),
      ),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle
                : overdue
                ? Icons.warning_amber_rounded
                : Icons.circle_outlined,
            color: completed
                ? _palette.accent
                : overdue
                ? Colors.orange
                : _palette.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    color: _palette.text,
                    fontWeight: FontWeight.w500,
                    decoration: completed ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatTime(task.dueTimeMinutes)} · '
                  '${task.priority.name}',
                  style: TextStyle(color: _palette.secondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (overdue)
            Text(
              LunoraLocalization.text('Просрочена'),
              style: TextStyle(color: Colors.orange, fontSize: 11),
            ),
        ],
      ),
    );
  }

  Widget _buildGoals() {
    final completed = _goals.where((goal) => goal.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          LunoraLocalization.text('Цели месяца', 'Monthly goals'),
          trailing: TextButton.icon(
            onPressed: _showGoalDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text(LunoraLocalization.text('Добавить')),
          ),
        ),
        const SizedBox(height: 8),
        if (_goals.isNotEmpty) ...[
          Text(
            LunoraLocalization.text('$completed из ${_goals.length} выполнено'),
            style: TextStyle(color: _palette.secondary, fontSize: 12),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: completed / _goals.length,
              minHeight: 6,
              backgroundColor: _palette.border,
              color: _palette.accent,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_goals.isEmpty)
          _emptyCard(LunoraLocalization.text('Добавь цели, которые хочешь выполнить в этом месяце.'))
        else
          ..._goals.map(_buildGoalCard),
      ],
    );
  }

  Widget _buildGoalCard(PlannerGoal goal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _palette.border),
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: Checkbox(
              value: goal.isCompleted,
              activeColor: _palette.accent,
              onChanged: (value) async {
                await _plannerRepository.updateGoal(
                  goal.copyWith(isCompleted: value ?? false),
                );
                await _loadData();
              },
            ),
          ),
          Expanded(
            child: Text(
              goal.title,
              style: TextStyle(
                color: _palette.text,
                decoration: goal.isCompleted
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          IconButton(
            tooltip: LunoraLocalization.text('Редактировать'),
            onPressed: () => _showGoalDialog(goal: goal),
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
          IconButton(
            tooltip: LunoraLocalization.text('Удалить'),
            onPressed: () => _deleteGoal(goal),
            icon: const Icon(Icons.delete_outline, size: 19),
          ),
        ],
      ),
    );
  }

  Future<void> _showGoalDialog({PlannerGoal? goal}) async {
    final controller = TextEditingController(text: goal?.title ?? '');

    final result = await showLunoraDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(goal == null ? LunoraLocalization.text('Новая цель') : LunoraLocalization.text('Редактирование цели')),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 150,
            decoration: InputDecoration(
              labelText: LunoraLocalization.text('Название цели'),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              Navigator.pop(context, controller.text);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(LunoraLocalization.text('Сохранить')),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) return;

    if (goal == null) {
      await _plannerRepository.createGoal(
        title: result,
        month: _month,
        year: _year,
      );
    } else {
      await _plannerRepository.updateGoal(goal.copyWith(title: result));
    }

    await _loadData();
  }

  Future<void> _deleteGoal(PlannerGoal goal) async {
    final confirmed = await _confirmDelete('цель');

    if (!confirmed) return;

    await _plannerRepository.deleteGoal(goal.id);
    await _loadData();
  }

  Widget _buildNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(
          LunoraLocalization.text('Заметки', 'Notes'),
          trailing: TextButton.icon(
            onPressed: _showNoteDialog,
            icon: const Icon(Icons.add, size: 18),
            label: Text(LunoraLocalization.text('Добавить')),
          ),
        ),
        const SizedBox(height: 8),
        if (_notes.isEmpty)
          _emptyCard(LunoraLocalization.text('Здесь будут твои личные заметки планера.'))
        else
          ..._notes.map(_buildNoteCard),
      ],
    );
  }

  Widget _buildNoteCard(Map<String, Object?> note) {
    final title = note['title']?.toString() ?? '';
    final content = note['content']?.toString() ?? '';
    final id = note['id']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _palette.border),
      ),
      child: Row(
        children: [
          Icon(Icons.sticky_note_2_outlined, color: _palette.accent),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: () => _showNoteDialog(note: note),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: _palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: _palette.secondary, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: LunoraLocalization.text('Удалить'),
            onPressed: () => _deleteNote(id),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
    );
  }

  Future<void> _showNoteDialog({Map<String, Object?>? note}) async {
    final titleController = TextEditingController(
      text: note?['title']?.toString() ?? '',
    );

    final contentController = TextEditingController(
      text: note?['content']?.toString() ?? '',
    );

    final result = await showLunoraDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(note == null ? LunoraLocalization.text('Новая заметка') : LunoraLocalization.text('Редактирование')),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Название'),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    minLines: 4,
                    maxLines: 8,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Текст заметки'),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(LunoraLocalization.text('Сохранить')),
            ),
          ],
        );
      },
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      if (note == null) {
        await _plannerRepository.createNote(
          title: titleController.text,
          content: contentController.text,
        );
      } else {
        await _plannerRepository.updateNote(
          id: note['id'].toString(),
          title: titleController.text,
          content: contentController.text,
        );
      }

      await _loadData();
    }

    titleController.dispose();
    contentController.dispose();
  }

  Future<void> _deleteNote(String id) async {
    final confirmed = await _confirmDelete('заметку');

    if (!confirmed) return;

    await _plannerRepository.deleteNote(id);
    await _loadData();
  }

  Future<bool> _confirmDelete(String item) async {
    return await showLunoraDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(LunoraLocalization.text('Удаление')),
              content: Text(LunoraLocalization.text('Удалить $item?')),
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
            );
          },
        ) ??
        false;
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _palette.border),
      ),
      child: Text(
        text,
        style: TextStyle(color: _palette.secondary, fontSize: 13, height: 1.5),
      ),
    );
  }

  Widget _buildPlannerBackground({required Widget child}) {
    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: _palette.background)),
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: Theme.of(context).brightness == Brightness.dark
                  ? 0.07
                  : 0.22,
              child: Image.asset(
                LunoraThemeAssets.texture(
                  SettingsService.instance.settings.colorTheme,
                ),
                fit: BoxFit.none,
                repeat: ImageRepeat.repeat,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        Positioned(
          top: 155,
          right: -35,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.13,
              child: SvgPicture.asset(
                LunoraThemeAssets.decoration(
                  SettingsService.instance.settings.colorTheme,
                ),
                width: 190,
                height: 270,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 25,
          left: -42,
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.12,
              child: SvgPicture.asset(
                LunoraThemeAssets.extra(
                  SettingsService.instance.settings.colorTheme,
                ),
                width: 190,
                height: 230,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildPlannerHero(bool compact) {
    return LunoraSectionHeader(
      title: LunoraLocalization.text('Мой планер'),
      subtitle: LunoraLocalization.text(
        'Место для планов, маленьких шагов и больших задумок.',
      ),
      icon: Icons.event_note_outlined,
      actions: [
        Tooltip(
          message: LunoraLocalization.text('Импортировать планер из Excel'),
          child: OutlinedButton.icon(
            onPressed: _importPlanner,
            icon: const Icon(Icons.file_upload_outlined, size: 18),
            label: Text(compact ? 'Excel' : LunoraLocalization.text('Импорт Excel')),
            style: OutlinedButton.styleFrom(
              foregroundColor: _palette.text,
              side: BorderSide(color: _palette.border),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 10 : 16,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlannerToolbar(bool compact) {
    return _buildViewSwitcher();
  }

  Widget _buildPaperSection({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _palette.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _palette.border.withValues(alpha: 0.85)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCalendarSection() {
    return _buildPaperSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  LunoraLocalization.text('Календарь планов'),
                  style: TextStyle(
                    color: _palette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.calendar_month_outlined,
                color: _palette.accent,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPeriodHeader(),
          const SizedBox(height: 5),
          _buildCalendar(),
          const SizedBox(height: 10),
          Center(
            child: Text(
              LunoraLocalization.text('Выбрано: ${_formatDate(_selectedDate)}'),
              style: TextStyle(color: _palette.secondary, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Opacity(
        opacity: 0.65,
        child: SvgPicture.asset(
          LunoraThemeAssets.divider(
            SettingsService.instance.settings.colorTheme,
          ),
          width: double.infinity,
          height: 28,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildNotesSection() {
    return _buildPaperSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNotes(),
          if (_notes.isEmpty) ...[
            const SizedBox(height: 6),
            Center(
              child: Opacity(
                opacity: 0.78,
                child: SvgPicture.asset(
                  LunoraThemeAssets.extra(
                    SettingsService.instance.settings.colorTheme,
                  ),
                  height: 112,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCalendarSection(),
        const SizedBox(height: 18),
        _buildPaperSection(child: _buildSelectedTasks()),
      ],
    );
    final rightColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildPaperSection(child: _buildGoals()),
        const SizedBox(height: 18),
        _buildNotesSection(),
      ],
    );

    return _buildPlannerBackground(
      child: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(compact ? 14 : 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildPlannerHero(compact),
                        const SizedBox(height: 16),
                        _buildPlannerToolbar(compact),
                        _buildDecorativeDivider(),
                        if (compact) ...[
                          leftColumn,
                          const SizedBox(height: 18),
                          rightColumn,
                        ] else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 6, child: leftColumn),
                              const SizedBox(width: 20),
                              Expanded(flex: 5, child: rightColumn),
                            ],
                          ),
                        const SizedBox(height: 18),
                        Center(
                          child: Text(
                            LunoraLocalization.text('Планируй в своём ритме'),
                            style: TextStyle(
                              color: _palette.secondary.withValues(alpha: 0.8),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
