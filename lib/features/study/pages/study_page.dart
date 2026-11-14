import 'package:lunora/core/settings/settings_service.dart';
import 'package:lunora/core/theme/lunora_theme_assets.dart';
import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:lunora/features/study/models/study_item.dart';

import 'package:lunora/features/study/models/study_period.dart';

import 'package:lunora/features/study/models/study_subject.dart';

import 'package:lunora/features/study/repositories/study_repository.dart';
import 'package:lunora/features/study/pages/study_excel_import_page.dart';
import 'package:lunora/features/study/services/study_excel_import_service.dart';

class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  final StudyRepository _repository = StudyRepository.instance;

  late String _academicYear;

  int _semester = 1;

  List<StudySubject> _subjects = [];

  List<StudyPeriod> _periods = [];

  List<StudyItem> _items = [];

  bool _isLoading = true;

  String? _error;

  final TextEditingController _itemSearchController = TextEditingController();
  String _typeFilter = '';
  String _subjectFilter = '';
  String _statusFilter = '';

  bool get _hasItemFilters =>
      _itemSearchController.text.trim().isNotEmpty ||
      _typeFilter.isNotEmpty ||
      _subjectFilter.isNotEmpty ||
      _statusFilter.isNotEmpty;

  List<StudyItem> get _filteredItems {
    final query = _itemSearchController.text.trim().toLowerCase();
    return _visibleItems.where((item) {
      if (_typeFilter.isNotEmpty && item.type.name != _typeFilter) return false;
      if (_statusFilter.isNotEmpty && item.status.name != _statusFilter) {
        return false;
      }
      if (_subjectFilter.isNotEmpty && item.subjectId != _subjectFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final subject = _subjectForItem(item);
        final searchable =
            '${item.title} ${item.description} ${item.notes} ${subject?.name ?? ''}'
                .toLowerCase();
        if (!searchable.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  void _resetItemFilters() {
    setState(() {
      _itemSearchController.clear();
      _typeFilter = '';
      _subjectFilter = '';
      _statusFilter = '';
    });
  }

  @override
  void dispose() {
    _itemSearchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    final startYear = now.month >= 8 ? now.year : now.year - 1;

    _academicYear = '$startYear/${startYear + 1}';

    _loadData();
  }

  List<String> get _availableYears {
    final now = DateTime.now();

    final currentStartYear = now.month >= 8 ? now.year : now.year - 1;

    return List.generate(5, (index) {
      final year = currentStartYear - 2 + index;

      return '$year/${year + 1}';
    });
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;

      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.getSubjects(
          academicYear: _academicYear,

          semester: _semester,
        ),

        _repository.getPeriods(
          academicYear: _academicYear,

          semester: _semester,
        ),

        _repository.getItems(),
      ]);

      if (!mounted) return;

      final subjects = results[0] as List<StudySubject>;

      final periods = results[1] as List<StudyPeriod>;

      final items = results[2] as List<StudyItem>;

      items.sort((a, b) {
        final dateA = _itemDate(a);

        final dateB = _itemDate(b);

        if (dateA == null && dateB == null) return 0;

        if (dateA == null) return 1;

        if (dateB == null) return -1;

        return dateA.compareTo(dateB);
      });

      setState(() {
        _subjects = subjects;

        _periods = periods;

        _items = items;

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();

        _isLoading = false;
      });
    }
  }

  Future<void> _openExcelImport() async {
    final result = await Navigator.of(context).push<StudyExcelImportResult>(
      MaterialPageRoute(builder: (_) => const StudyExcelImportPage()),
    );

    if (!mounted || result == null) return;

    await _loadData();

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(LunoraLocalization.text('Импорт завершён')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LunoraLocalization.text(
                  'Всего импортировано: ${result.totalImported}',
                ),
              ),
              Text(
                LunoraLocalization.text(
                  'Всего пропущено: ${result.totalSkipped}',
                ),
              ),
              const Divider(height: 24),
              Text(
                '${LunoraLocalization.text('Предметы: ${result.subjects} добавлено, ')}${result.skippedSubjects} пропущено',
              ),
              const SizedBox(height: 8),
              Text(
                '${LunoraLocalization.text('Учебные периоды: ${result.periods} добавлено, ')}${result.skippedPeriods} пропущено',
              ),
              const SizedBox(height: 8),
              Text(
                '${LunoraLocalization.text('События и задания: ${result.items} добавлено, ')}${result.existingItems} уже были в базе, ${result.skippedItems} пропущено',
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(LunoraLocalization.text('Понятно')),
            ),
          ],
        );
      },
    );
  }

  List<StudyItem> get _visibleItems {
    final subjectIds = _subjects.map((subject) => subject.id).toSet();

    final periodIds = _periods.map((period) => period.id).toSet();

    return _items.where((item) {
      final belongsToSubject =
          item.subjectId == null || subjectIds.contains(item.subjectId);

      final belongsToPeriod =
          item.periodId == null || periodIds.contains(item.periodId);

      return belongsToSubject && belongsToPeriod;
    }).toList();
  }

  int get _completedCount {
    return _visibleItems
        .where((item) => item.status == StudyItemStatus.completed)
        .length;
  }

  int get _activeCount {
    return _visibleItems.where(_isActive).length;
  }

  bool _isActive(StudyItem item) {
    return item.status == StudyItemStatus.planned ||
        item.status == StudyItemStatus.inProgress;
  }

  DateTime? _itemDate(StudyItem item) {
    return item.scheduledAt ?? item.dueAt;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // ПРОСРОЧЕННЫЕ ЗАДАНИЯ

  List<StudyItem> get _overdueItems {
    final today = _dateOnly(DateTime.now());

    return _visibleItems.where((item) {
      if (!_isActive(item) || item.dueAt == null) return false;

      return _dateOnly(item.dueAt!).isBefore(today);
    }).toList()..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
  }

  // БЛИЖАЙШИЕ ДЕДЛАЙНЫ

  List<StudyItem> get _upcomingDeadlines {
    final today = _dateOnly(DateTime.now());

    final items = _visibleItems.where((item) {
      if (!_isActive(item) || item.dueAt == null) return false;

      final isLecture =
          item.type == StudyItemType.lecture ||
          item.type == StudyItemType.onlineLecture;

      return !isLecture && !_dateOnly(item.dueAt!).isBefore(today);
    }).toList();

    items.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));

    return items.take(5).toList();
  }

  // ПРЕДСТОЯЩИЕ ЗАНЯТИЯ

  List<StudyItem> get _upcomingClasses {
    final today = _dateOnly(DateTime.now());

    final items = _visibleItems.where((item) {
      if (!_isActive(item) || item.scheduledAt == null) return false;

      final isLecture =
          item.type == StudyItemType.lecture ||
          item.type == StudyItemType.onlineLecture;

      return isLecture && !_dateOnly(item.scheduledAt!).isBefore(today);
    }).toList();

    items.sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!));

    return items.take(5).toList();
  }

  // ПРЕДСТОЯЩИЕ УЧЕБНЫЕ ПЕРИОДЫ

  List<StudyPeriod> get _upcomingPeriods {
    final today = _dateOnly(DateTime.now());

    final periods = _periods.where((period) {
      final endDate = period.endsAt;

      final startDate = period.startsAt;

      if (endDate != null) {
        return !_dateOnly(endDate).isBefore(today);
      }

      if (startDate != null) {
        return !_dateOnly(startDate).isBefore(today);
      }

      return false;
    }).toList();

    periods.sort((a, b) {
      final dateA = a.startsAt ?? a.endsAt;

      final dateB = b.startsAt ?? b.endsAt;

      if (dateA == null && dateB == null) return 0;

      if (dateA == null) return 1;

      if (dateB == null) return -1;

      return dateA.compareTo(dateB);
    });

    return periods.take(5).toList();
  }

  Future<void> _changeSemester(int semester) async {
    if (_semester == semester) return;

    setState(() => _semester = semester);

    await _loadData();
  }

  Future<void> _changeAcademicYear(String? year) async {
    if (year == null || year == _academicYear) return;

    setState(() => _academicYear = year);

    await _loadData();
  }

  // ПРЕДМЕТЫ

  Future<void> _addSubject() async {
    await _showSubjectDialog();
  }

  Future<void> _editSubject(StudySubject subject) async {
    await _showSubjectDialog(subject: subject);
  }

  Future<void> _showSubjectDialog({StudySubject? subject}) async {
    final isEditing = subject != null;

    final nameController = TextEditingController(text: subject?.name ?? '');

    final teacherController = TextEditingController(
      text: subject?.teacher ?? '',
    );

    final descriptionController = TextEditingController(
      text: subject?.description ?? '',
    );

    final result = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: Text(isEditing ? LunoraLocalization.text('Редактировать предмет') : LunoraLocalization.text('Новый предмет')),

          content: SizedBox(
            width: 420,

            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  TextField(
                    controller: nameController,

                    autofocus: true,

                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Название предмета *'),

                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: teacherController,

                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Преподаватель'),

                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextField(
                    controller: descriptionController,

                    minLines: 2,

                    maxLines: 4,

                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Описание'),

                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),

              child: Text(LunoraLocalization.text('Отмена')),
            ),

            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) return;

                Navigator.pop(dialogContext, true);
              },

              child: Text(isEditing ? LunoraLocalization.text('Сохранить') : LunoraLocalization.text('Добавить')),
            ),
          ],
        );
      },
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        if (subject == null) {
          await _repository.createSubject(
            name: nameController.text.trim(),

            teacher: teacherController.text.trim(),

            description: descriptionController.text.trim(),

            academicYear: _academicYear,

            semester: _semester,
          );
        } else {
          await _repository.updateSubject(
            subject.copyWith(
              name: nameController.text.trim(),

              teacher: teacherController.text.trim(),

              description: descriptionController.text.trim(),

              updatedAt: DateTime.now(),
            ),
          );
        }

        await _loadData();
      } catch (error) {
        _showError(
          isEditing
              ? 'Не удалось сохранить предмет: $error'
              : 'Не удалось добавить предмет: $error',
        );
      }
    }

    nameController.dispose();

    teacherController.dispose();

    descriptionController.dispose();
  }

  // УЧЕБНЫЕ ПЕРИОДЫ

  Future<void> _addPeriod() async {
    await _showPeriodDialog();
  }

  Future<void> _editPeriod(StudyPeriod period) async {
    await _showPeriodDialog(period: period);
  }

  Future<void> _showPeriodDialog({StudyPeriod? period}) async {
    final isEditing = period != null;

    final titleController = TextEditingController(text: period?.title ?? '');

    StudyPeriodType selectedType = period?.type ?? StudyPeriodType.examSession;

    DateTime? selectedStartsAt = period?.startsAt;

    DateTime? selectedEndsAt = period?.endsAt;

    String? dateError;

    Future<void> pickStartDate(StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,

        initialDate: selectedStartsAt ?? DateTime.now(),

        firstDate: DateTime(2000),

        lastDate: DateTime(2100),

        helpText: LunoraLocalization.text('Выбери начало периода'),
      );

      if (picked == null) return;

      setDialogState(() {
        selectedStartsAt = DateTime(picked.year, picked.month, picked.day);

        dateError = null;
      });
    }

    Future<void> pickEndDate(StateSetter setDialogState) async {
      final initialDate = selectedEndsAt ?? selectedStartsAt ?? DateTime.now();

      final picked = await showDatePicker(
        context: context,

        initialDate: initialDate,

        firstDate: DateTime(2000),

        lastDate: DateTime(2100),

        helpText: LunoraLocalization.text('Выбери окончание периода'),
      );

      if (picked == null) return;

      setDialogState(() {
        selectedEndsAt = DateTime(picked.year, picked.month, picked.day);

        dateError = null;
      });
    }

    final result = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              constraints: const BoxConstraints(maxWidth: 520),
              title: Text(
                isEditing
                    ? 'Редактировать учебный период'
                    : 'Новый учебный период',
              ),

              content: SizedBox(
                width: 440,

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      TextField(
                        controller: titleController,

                        autofocus: true,

                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text(
                            'Название периода *',
                          ),

                          hintText: LunoraLocalization.text(
                            'Например, зимняя сессия',
                          ),

                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      DropdownButtonFormField<StudyPeriodType>(
                        initialValue: selectedType,

                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Тип периода'),

                          border: OutlineInputBorder(),
                        ),

                        items: StudyPeriodType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,

                            child: Text(_periodTypeName(type)),
                          );
                        }).toList(),

                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedType = value);
                          }
                        },
                      ),

                      const SizedBox(height: 20),

                      _buildDialogDateField(
                        context,

                        label: LunoraLocalization.text('Дата начала'),

                        value: _dateLabel(selectedStartsAt),

                        onPickDate: () {
                          pickStartDate(setDialogState);
                        },

                        onClear: selectedStartsAt == null
                            ? null
                            : () {
                                setDialogState(() {
                                  selectedStartsAt = null;

                                  dateError = null;
                                });
                              },
                      ),

                      const SizedBox(height: 16),

                      _buildDialogDateField(
                        context,

                        label: LunoraLocalization.text('Дата окончания'),

                        value: _dateLabel(selectedEndsAt),

                        onPickDate: () {
                          pickEndDate(setDialogState);
                        },
                        onClear: selectedEndsAt == null
                            ? null
                            : () {
                                setDialogState(() {
                                  selectedEndsAt = null;

                                  dateError = null;
                                });
                              },
                      ),

                      if (dateError != null) ...[
                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerLeft,

                          child: Text(
                            dateError!,

                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 8),

                      Align(
                        alignment: Alignment.centerLeft,

                        child: Text(
                          LunoraLocalization.text(
                            'Даты можно оставить пустыми и заполнить позже.',
                          ),

                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),

                  child: Text(LunoraLocalization.text('Отмена')),
                ),

                FilledButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;

                    if (selectedStartsAt != null &&
                        selectedEndsAt != null &&
                        _dateOnly(selectedEndsAt!)
                            .isBefore(_dateOnly(selectedStartsAt!))) {
                      setDialogState(() {
                        dateError =
                            'Дата окончания не может быть раньше даты начала.';
                      });

                      return;
                    }

                    Navigator.pop(dialogContext, true);
                  },

                  child: Text(isEditing ? LunoraLocalization.text('Сохранить') : LunoraLocalization.text('Добавить')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      try {
        if (period == null) {
          await _repository.createPeriod(
            title: titleController.text.trim(),

            type: selectedType,

            academicYear: _academicYear,

            semester: _semester,

            startsAt: selectedStartsAt,

            endsAt: selectedEndsAt,
          );
        } else {
          await _repository.updatePeriod(
            period.copyWith(
              title: titleController.text.trim(),

              type: selectedType,

              startsAt: selectedStartsAt,

              clearStartsAt: selectedStartsAt == null,

              endsAt: selectedEndsAt,

              clearEndsAt: selectedEndsAt == null,

              updatedAt: DateTime.now(),
            ),
          );
        }

        await _loadData();
      } catch (error) {
        _showError(
          isEditing
              ? 'Не удалось сохранить период: $error'
              : 'Не удалось добавить период: $error',
        );
      }
    }

    titleController.dispose();
  }

  // УЧЕБНЫЕ СОБЫТИЯ

  Future<void> _addItem() async {
    if (_subjects.isEmpty) {
      _showError('Сначала добавь хотя бы один учебный предмет.');

      return;
    }

    await _showItemDialog();
  }

  Future<void> _editItem(StudyItem item) async {
    await _showItemDialog(item: item);
  }

  Future<void> _showItemDialog({StudyItem? item}) async {
    final isEditing = item != null;

    final titleController = TextEditingController(text: item?.title ?? '');

    StudyItemType selectedType = item?.type ?? StudyItemType.lecture;

    StudyItemFormat selectedFormat = item?.format ?? StudyItemFormat.none;

    StudyItemStatus selectedStatus = item?.status ?? StudyItemStatus.planned;

    String? selectedSubjectId =
        item?.subjectId ?? (_subjects.isNotEmpty ? _subjects.first.id : null);

    DateTime? selectedScheduledAt = item?.scheduledAt;

    DateTime? selectedDueAt = item?.dueAt;

    Future<void> pickScheduledDate(StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,

        initialDate: selectedScheduledAt ?? DateTime.now(),

        firstDate: DateTime(2000),

        lastDate: DateTime(2100),

        helpText: LunoraLocalization.text('Выбери дату занятия'),
      );

      if (picked == null) return;

      setDialogState(() {
        selectedScheduledAt = DateTime(
          picked.year,

          picked.month,

          picked.day,

          selectedScheduledAt?.hour ?? 9,

          selectedScheduledAt?.minute ?? 0,
        );
      });
    }

    Future<void> pickScheduledTime(StateSetter setDialogState) async {
      if (selectedScheduledAt == null) {
        _showError('Сначала выбери дату занятия.');

        return;
      }

      final picked = await showTimePicker(
        context: context,

        initialTime: TimeOfDay.fromDateTime(selectedScheduledAt!),

        helpText: LunoraLocalization.text('Выбери время занятия'),
      );

      if (picked == null) return;

      setDialogState(() {
        selectedScheduledAt = DateTime(
          selectedScheduledAt!.year,

          selectedScheduledAt!.month,

          selectedScheduledAt!.day,

          picked.hour,

          picked.minute,
        );
      });
    }

    Future<void> pickDueDate(StateSetter setDialogState) async {
      final picked = await showDatePicker(
        context: context,

        initialDate: selectedDueAt ?? selectedScheduledAt ?? DateTime.now(),

        firstDate: DateTime(2000),

        lastDate: DateTime(2100),

        helpText: LunoraLocalization.text('Выбери срок сдачи'),
      );

      if (picked == null) return;

      setDialogState(() {
        selectedDueAt = DateTime(picked.year, picked.month, picked.day);
      });
    }

    final result = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Редактировать событие' : 'Новое учебное событие',
              ),

              content: SizedBox(
                width: 460,

                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,

                    children: [
                      TextField(
                        controller: titleController,

                        autofocus: true,

                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Название *'),

                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<String?>(
                        initialValue: selectedSubjectId,

                        isExpanded: true,

                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Предмет'),

                          border: OutlineInputBorder(),
                        ),

                        items: [
                          DropdownMenuItem<String?>(
                            value: null,

                            child: Text(
                              LunoraLocalization.text('Без предмета'),
                            ),
                          ),

                          ..._subjects.map((subject) {
                            return DropdownMenuItem<String?>(
                              value: subject.id,

                              child: Text(
                                subject.name,

                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }),
                        ],

                        onChanged: (value) {
                          setDialogState(() => selectedSubjectId = value);
                        },
                      ),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<StudyItemType>(
                        initialValue: selectedType,

                        isExpanded: true,

                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Тип события'),

                          border: OutlineInputBorder(),
                        ),

                        items: StudyItemType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,

                            child: Text(_itemTypeName(type)),
                          );
                        }).toList(),

                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedType = value);
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      DropdownButtonFormField<StudyItemFormat>(
                        initialValue: selectedFormat,

                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Формат'),

                          border: OutlineInputBorder(),
                        ),

                        items: StudyItemFormat.values.map((format) {
                          return DropdownMenuItem(
                            value: format,

                            child: Text(_formatName(format)),
                          );
                        }).toList(),

                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedFormat = value);
                          }
                        },
                      ),

                      const SizedBox(height: 20),

                      _buildDialogDateField(
                        context,

                        label: LunoraLocalization.text('Дата и время занятия'),

                        value: selectedScheduledAt == null
                            ? 'Не указано'
                            : _dateTimeLabel(selectedScheduledAt!),

                        onPickDate: () {
                          pickScheduledDate(setDialogState);
                        },

                        onPickTime: () {
                          pickScheduledTime(setDialogState);
                        },

                        onClear: selectedScheduledAt == null
                            ? null
                            : () {
                                setDialogState(
                                  () => selectedScheduledAt = null,
                                );
                              },

                        showTime: true,
                      ),

                      const SizedBox(height: 16),

                      _buildDialogDateField(
                        context,

                        label: LunoraLocalization.text('Срок сдачи'),

                        value: selectedDueAt == null
                            ? 'Не указан'
                            : _dateLabel(selectedDueAt),

                        onPickDate: () {
                          pickDueDate(setDialogState);
                        },

                        onClear: selectedDueAt == null
                            ? null
                            : () {
                                setDialogState(() => selectedDueAt = null);
                              },
                      ),

                      if (isEditing) ...[
                        const SizedBox(height: 16),

                        DropdownButtonFormField<StudyItemStatus>(
                          initialValue: selectedStatus,

                          decoration: InputDecoration(
                            labelText: LunoraLocalization.text('Статус'),

                            border: OutlineInputBorder(),
                          ),

                          items: StudyItemStatus.values.map((status) {
                            return DropdownMenuItem(
                              value: status,

                              child: Text(_statusName(status)),
                            );
                          }).toList(),

                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() => selectedStatus = value);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),

                  child: Text(LunoraLocalization.text('Отмена')),
                ),

                FilledButton(
                  onPressed: () {
                    if (titleController.text.trim().isEmpty) return;

                    Navigator.pop(dialogContext, true);
                  },

                  child: Text(isEditing ? LunoraLocalization.text('Сохранить') : LunoraLocalization.text('Добавить')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == true && titleController.text.trim().isNotEmpty) {
      try {
        if (item == null) {
          await _repository.createItem(
            subjectId: selectedSubjectId,

            title: titleController.text.trim(),

            type: selectedType,

            format: selectedFormat,

            scheduledAt: selectedScheduledAt,

            dueAt: selectedDueAt,
          );
        } else {
          final updatedItem = item.copyWith(
            title: titleController.text.trim(),

            subjectId: selectedSubjectId,

            clearSubjectId: selectedSubjectId == null,

            type: selectedType,

            format: selectedFormat,

            status: selectedStatus,

            scheduledAt: selectedScheduledAt,

            clearScheduledAt: selectedScheduledAt == null,

            dueAt: selectedDueAt,

            clearDueAt: selectedDueAt == null,

            updatedAt: DateTime.now(),
          );

          await _repository.updateItem(updatedItem);
        }

        await _loadData();
      } catch (error) {
        _showError(
          isEditing
              ? 'Не удалось сохранить событие: $error'
              : 'Не удалось добавить событие: $error',
        );
      }
    }

    titleController.dispose();
  }

  // ПОЛЯ ВЫБОРА ДАТЫ

  Widget _buildDialogDateField(
    BuildContext context, {

    required String label,

    required String value,

    required VoidCallback onPickDate,

    required VoidCallback? onClear,

    VoidCallback? onPickTime,

    bool showTime = false,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),

        const SizedBox(height: 8),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

          decoration: BoxDecoration(
            border: Border.all(color: colors.outline),

            borderRadius: BorderRadius.circular(12),
          ),

          child: Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 19),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  value,

                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),

              if (showTime && onPickTime != null)
                IconButton(
                  tooltip: LunoraLocalization.text('Выбрать время'),

                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  onPressed: onPickTime,
                  icon: const Icon(Icons.access_time, size: 20),
                ),

              IconButton(
                tooltip: LunoraLocalization.text('Выбрать дату'),

                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                onPressed: onPickDate,
                icon: const Icon(Icons.edit_calendar_outlined, size: 20),
              ),

              IconButton(
                tooltip: LunoraLocalization.text('Очистить дату'),

                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints.tightFor(
                  width: 40,
                  height: 40,
                ),
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // УДАЛЕНИЕ

  Future<void> _deleteSubject(StudySubject subject) async {
    final confirmed = await _confirmDelete(
      'Удалить предмет «${subject.name}»?',

      'Связанные с ним учебные события могут потерять связь с предметом.',
    );

    if (!confirmed) return;

    try {
      await _repository.deleteSubject(subject.id);

      await _loadData();
    } catch (error) {
      _showError('Не удалось удалить предмет: $error');
    }
  }

  Future<void> _deletePeriod(StudyPeriod period) async {
    final confirmed = await _confirmDelete(
      'Удалить период «${period.title}»?',

      'Проверь связанные с ним учебные события перед удалением.',
    );

    if (!confirmed) return;

    try {
      await _repository.deletePeriod(period.id);

      await _loadData();
    } catch (error) {
      _showError('Не удалось удалить период: $error');
    }
  }

  Future<void> _deleteItem(StudyItem item) async {
    final confirmed = await _confirmDelete(
      'Удалить «${item.title}»?',

      'Это действие нельзя отменить.',
    );

    if (!confirmed) return;

    try {
      await _repository.deleteItem(item.id);

      await _loadData();
    } catch (error) {
      _showError('Не удалось удалить событие: $error');
    }
  }

  Future<bool> _confirmDelete(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),

          content: Text(LunoraLocalization.text(message)),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),

              child: Text(LunoraLocalization.text('Отмена')),
            ),

            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),

              onPressed: () => Navigator.pop(dialogContext, true),

              child: Text(LunoraLocalization.text('Удалить')),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(LunoraLocalization.text(message))));
  }

  // ПОДПИСИ

  String _periodTypeName(StudyPeriodType type) {
    switch (type) {
      case StudyPeriodType.semester:
        return LunoraLocalization.text('Семестр', 'Semester');

      case StudyPeriodType.examSession:
        return LunoraLocalization.text('Экзаменационная сессия', 'Exam session');

      case StudyPeriodType.practice:
        return LunoraLocalization.text('Практика', 'Internship');

      case StudyPeriodType.other:
        return LunoraLocalization.text('Другое', 'Other');
    }
  }

  String _itemTypeName(StudyItemType type) {
    switch (type) {
      case StudyItemType.lecture:
        return LunoraLocalization.text('Лекция', 'Lecture');

      case StudyItemType.onlineLecture:
        return LunoraLocalization.text('Онлайн-лекция', 'Online lecture');

      case StudyItemType.test:
        return LunoraLocalization.text('Тест', 'Test');

      case StudyItemType.writtenAssignment:
        return LunoraLocalization.text('Письменная работа', 'Written assignment');

      case StudyItemType.exam:
        return LunoraLocalization.text('Экзамен', 'Exam');

      case StudyItemType.credit:
        return LunoraLocalization.text('Зачёт', 'Pass/fail test');

      case StudyItemType.practice:
        return LunoraLocalization.text('Практика', 'Internship');

      case StudyItemType.coursework:
        return LunoraLocalization.text('Курсовая работа', 'Coursework');

      case StudyItemType.diploma:
        return LunoraLocalization.text('Дипломная работа', 'Thesis');

      case StudyItemType.other:
        return LunoraLocalization.text('Другое', 'Other');
    }
  }

  String _formatName(StudyItemFormat format) {
    switch (format) {
      case StudyItemFormat.none:
        return LunoraLocalization.text('Не указан', 'Not specified');

      case StudyItemFormat.offline:
        return LunoraLocalization.text('Очно', 'In person');

      case StudyItemFormat.online:
        return LunoraLocalization.text('Онлайн', 'Online');
    }
  }

  String _statusName(StudyItemStatus status) {
    switch (status) {
      case StudyItemStatus.planned:
        return LunoraLocalization.text('Запланировано', 'Planned');

      case StudyItemStatus.inProgress:
        return LunoraLocalization.text('В процессе', 'In progress');

      case StudyItemStatus.completed:
        return LunoraLocalization.text('Выполнено', 'Completed');

      case StudyItemStatus.cancelled:
        return LunoraLocalization.text('Отменено', 'Cancelled');
    }
  }

  String _dateLabel(DateTime? date) {
    if (date == null) return LunoraLocalization.text('Не указана', 'Not specified');

    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  String _dateTimeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');

    final minute = date.minute.toString().padLeft(2, '0');

    return LunoraLocalization.text('${_dateLabel(date)} в $hour:$minute', '${_dateLabel(date)} at $hour:$minute');
  }

  // ОСНОВНОЙ ЭКРАН

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,

          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontalPadding = constraints.maxWidth < 700
                        ? 16.0
                        : 28.0;

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),

                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,

                        24,

                        horizontalPadding,

                        32,
                      ),

                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1100),

                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,

                            children: [
                              _buildHeader(context),

                              const SizedBox(height: 8),
                              _buildBotanicalDivider(),
                              const SizedBox(height: 12),

                              _buildAcademicSelectors(context),

                              const SizedBox(height: 20),

                              _buildStatistics(context),

                              const SizedBox(height: 28),

                              _buildScheduleOverview(context),

                              const SizedBox(height: 10),
                              _buildBotanicalDivider(),
                              const SizedBox(height: 18),

                              _buildSectionHeader(
                                context,

                                title: LunoraLocalization.text(
                                  'Учебные предметы',
                                ),

                                actionLabel: LunoraLocalization.text('Добавить предмет', 'Add subject'),

                                onAction: _addSubject,
                              ),

                              const SizedBox(height: 12),

                              _buildSubjects(context),

                              const SizedBox(height: 28),

                              _buildSectionHeader(
                                context,

                                title: LunoraLocalization.text(
                                  'Учебные периоды',
                                ),

                                actionLabel: LunoraLocalization.text('Добавить период', 'Add period'),

                                onAction: _addPeriod,
                              ),

                              const SizedBox(height: 12),

                              _buildPeriods(context),

                              const SizedBox(height: 28),

                              _buildSectionHeader(
                                context,

                                title: LunoraLocalization.text(
                                  'Учебные события',
                                ),

                                actionLabel: LunoraLocalization.text('Добавить событие', 'Add event'),

                                onAction: _addItem,
                              ),

                              const SizedBox(height: 12),

                              _buildItemFilters(context),

                              const SizedBox(height: 12),

                              _buildItems(context),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildBotanicalDivider() {
    return Center(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Opacity(
            opacity: Theme.of(context).brightness == Brightness.dark
                ? 0.28
                : 0.52,
            child: SvgPicture.asset(
              LunoraThemeAssets.divider(
                SettingsService.instance.settings.colorTheme,
              ),
              width: 280,
              height: 34,
              fit: BoxFit.contain,
            ),
          ),
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
            const Icon(Icons.error_outline, size: 42),

            const SizedBox(height: 12),

            Text(
              LunoraLocalization.text('Не удалось загрузить учебный планер'),
            ),

            const SizedBox(height: 8),

            Text(_error!, textAlign: TextAlign.center),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: _loadData,

              icon: const Icon(Icons.refresh),

              label: Text(LunoraLocalization.text('Повторить')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 20, 22),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .045),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.auto_stories_rounded,
              color: colors.onPrimaryContainer,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LunoraLocalization.text('МОЁ ПРОСТРАНСТВО'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  LunoraLocalization.text('Мой учебный мир'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LunoraLocalization.text(
                    'Предметы, открытия и маленькие шаги к большим целям.',
                  ),
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            children: [
              IconButton(
                tooltip: LunoraLocalization.text('Импорт из Excel'),
                onPressed: _openExcelImport,
                icon: const Icon(Icons.file_upload_outlined),
              ),
              IconButton(
                tooltip: LunoraLocalization.text('Обновить'),
                onPressed: _loadData,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicSelectors(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 210,
            child: DropdownButtonFormField<String>(
              initialValue: _academicYear,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: LunoraLocalization.text('Учебный год'),
                prefixIcon: Icon(Icons.calendar_month_outlined),
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              items: _availableYears
                  .map(
                    (year) => DropdownMenuItem(value: year, child: Text(year)),
                  )
                  .toList(),
              onChanged: _changeAcademicYear,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LunoraLocalization.text('СЕМЕСТР'),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 1,
                    label: Text(LunoraLocalization.text('Первый')),
                  ),
                  ButtonSegment(
                    value: 2,
                    label: Text(LunoraLocalization.text('Второй')),
                  ),
                ],
                selected: {_semester},
                onSelectionChanged: (selection) =>
                    _changeSemester(selection.first),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        final cardWidth = compact
            ? (constraints.maxWidth - 12) / 2
            : (constraints.maxWidth - 24) / 3;

        return Wrap(
          spacing: 12,

          runSpacing: 12,

          children: [
            SizedBox(
              width: cardWidth,

              child: _statCard(
                context,

                icon: Icons.menu_book_outlined,

                label: LunoraLocalization.text('Предметы'),

                value: _subjects.length.toString(),
              ),
            ),

            SizedBox(
              width: cardWidth,

              child: _statCard(
                context,

                icon: Icons.pending_actions_outlined,

                label: LunoraLocalization.text('В работе'),

                value: _activeCount.toString(),
              ),
            ),

            SizedBox(
              width: cardWidth,

              child: _statCard(
                context,

                icon: Icons.check_circle_outline,

                label: LunoraLocalization.text('Выполнено'),

                value: _completedCount.toString(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.secondaryContainer.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: colors.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.1),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ОБЗОР УЧЁБЫ

  // ОБЗОР УЧЁБЫ

  Widget _buildScheduleOverview(BuildContext context) {
    final deadlines = _upcomingDeadlines;

    final classes = _upcomingClasses;

    final periods = _upcomingPeriods;

    final overdue = _overdueItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [
        Text(
          LunoraLocalization.text('Ближайшее в учёбе'),

          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),

        const SizedBox(height: 14),

        if (overdue.isNotEmpty) ...[
          _buildOverviewCard(
            context,

            title: LunoraLocalization.text('Просроченные задания'),

            icon: Icons.warning_amber_rounded,

            items: overdue,

            emptyText: LunoraLocalization.text('Просроченных заданий нет'),

            color: Theme.of(context).colorScheme.error,

            showDueDate: true,
          ),

          const SizedBox(height: 12),
        ],

        _buildOverviewCard(
          context,

          title: LunoraLocalization.text('Ближайшие дедлайны'),

          icon: Icons.assignment_outlined,

          items: deadlines,

          emptyText: LunoraLocalization.text('Ближайших дедлайнов нет'),

          showDueDate: true,
        ),

        const SizedBox(height: 12),

        _buildOverviewCard(
          context,

          title: LunoraLocalization.text('Предстоящие занятия'),

          icon: Icons.menu_book_outlined,

          items: classes,

          emptyText: LunoraLocalization.text('Предстоящих занятий нет'),

          showDueDate: false,
        ),

        const SizedBox(height: 12),

        _buildPeriodsOverview(context, periods),
      ],
    );
  }

  Widget _buildOverviewCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<StudyItem> items,
    required String emptyText,
    required bool showDueDate,
    Color? color,
  }) {
    final colors = Theme.of(context).colorScheme;
    final accent = color ?? colors.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 15, 12, 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length}',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                emptyText,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            )
          else
            ...items.map((item) {
              final subject = _subjectForItem(item);
              final date = showDueDate ? item.dueAt : item.scheduledAt;
              return Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Row(
                  children: [
                    Icon(_itemIcon(item.type), size: 19, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (subject != null) subject.name,
                              if (date != null)
                                showDueDate
                                    ? 'Сдать до ${_dateLabel(date)}'
                                    : _dateTimeLabel(date),
                            ].join(' · '),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: LunoraLocalization.text('Редактировать'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _editItem(item),
                      icon: const Icon(Icons.edit_outlined, size: 19),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPeriodsOverview(
    BuildContext context,

    List<StudyPeriod> periods,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                Icon(Icons.date_range_outlined, color: colors.primary),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    LunoraLocalization.text('Сессии и учебные периоды'),

                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),

                Text(
                  periods.length.toString(),

                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (periods.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),

                child: Text(
                  LunoraLocalization.text('Предстоящих учебных периодов нет'),

                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant),
                ),
              )
            else
              ...periods.map((period) {
                final dateText =
                    '${_dateLabel(period.startsAt)} — ${_dateLabel(period.endsAt)}';

                return ListTile(
                  contentPadding: EdgeInsets.zero,

                  dense: true,

                  leading: const Icon(Icons.calendar_month_outlined),

                  title: Text(
                    period.title,

                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),

                  subtitle: Text('${_periodTypeName(period.type)} · $dateText'),

                  trailing: IconButton(
                    tooltip: LunoraLocalization.text('Редактировать период'),

                    onPressed: () => _editPeriod(period),

                    icon: const Icon(Icons.edit_outlined),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  StudySubject? _subjectForItem(StudyItem item) {
    for (final subject in _subjects) {
      if (subject.id == item.subjectId) return subject;
    }

    return null;
  }

  // ЗАГОЛОВКИ РАЗДЕЛОВ

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Container(
                width: 54,
                height: 2,
                decoration: BoxDecoration(
                  color: colors.tertiary.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }

  // СПИСОК ПРЕДМЕТОВ

  // СПИСОК ПРЕДМЕТОВ

  Widget _buildSubjects(BuildContext context) {
    if (_subjects.isEmpty) {
      return _emptyCard(
        context,
        icon: Icons.menu_book_outlined,
        message: LunoraLocalization.text('Пока нет предметов'),
        hint: LunoraLocalization.text('Добавь первый предмет, чтобы начать вести учебный план.', 'Add your first subject to start planning your studies.'),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 760 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _subjects
              .map(
                (subject) => SizedBox(
                  width: width,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(15, 14, 9, 12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: .55),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(
                              alpha: .65,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                subject.teacher.isEmpty
                                    ? LunoraLocalization.text('Преподаватель не указан', 'No teacher specified')
                                    : subject.teacher,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: LunoraLocalization.text('Действия'),
                          onSelected: (value) {
                            if (value == 'edit') _editSubject(subject);
                            if (value == 'delete') _deleteSubject(subject);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(
                                LunoraLocalization.text('Редактировать'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(LunoraLocalization.text('Удалить')),
                            ),
                          ],
                          icon: const Icon(Icons.more_vert),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  // СПИСОК УЧЕБНЫХ ПЕРИОДОВ

  // СПИСОК УЧЕБНЫХ ПЕРИОДОВ

  Widget _buildPeriods(BuildContext context) {
    if (_periods.isEmpty) {
      return _emptyCard(
        context,
        icon: Icons.date_range_outlined,
        message: LunoraLocalization.text('Учебные периоды не добавлены'),
        hint: LunoraLocalization.text('Здесь будут семестры, сессии и практика.', 'Semesters, exam sessions and internships will appear here.'),
      );
    }
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: _periods.map((period) {
        final dateText = period.startsAt == null && period.endsAt == null
            ? LunoraLocalization.text('Даты не указаны', 'Dates not specified')
            : '${_dateLabel(period.startsAt)} — ${_dateLabel(period.endsAt)}';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: .55),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: colors.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_periodTypeName(period.type)} · $dateText',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: LunoraLocalization.text('Редактировать'),
                onPressed: () => _editPeriod(period),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: LunoraLocalization.text('Удалить'),
                onPressed: () => _deletePeriod(period),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // СПИСОК УЧЕБНЫХ СОБЫТИЙ

  // СПИСОК УЧЕБНЫХ СОБЫТИЙ

  Widget _buildItemFilters(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            TextField(
              controller: _itemSearchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: LunoraLocalization.text('Поиск по событиям'),
                hintText: LunoraLocalization.text(
                  'Название, описание, заметки или предмет',
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _itemSearchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: LunoraLocalization.text('Очистить поиск'),
                        onPressed: () {
                          _itemSearchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String>(
                        initialValue: _typeFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Тип события'),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(LunoraLocalization.text('Все типы')),
                          ),
                          ...StudyItemType.values.map(
                            (type) => DropdownMenuItem(
                              value: type.name,
                              child: Text(
                                _itemTypeName(type),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _typeFilter = value ?? ''),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String>(
                        initialValue: _subjectFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Предмет'),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(
                              LunoraLocalization.text('Все предметы'),
                            ),
                          ),
                          ..._subjects.map(
                            (subject) => DropdownMenuItem(
                              value: subject.id,
                              child: Text(
                                subject.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _subjectFilter = value ?? ''),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Статус'),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            child: Text(LunoraLocalization.text('Все статусы')),
                          ),
                          ...StudyItemStatus.values.map(
                            (status) => DropdownMenuItem(
                              value: status.name,
                              child: Text(
                                _statusName(status),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _statusFilter = value ?? ''),
                      ),
                    ),
                    if (_hasItemFilters)
                      TextButton.icon(
                        onPressed: _resetItemFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: Text(LunoraLocalization.text('Сбросить')),
                      ),
                  ],
                );
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  LunoraLocalization.text(
                    'Найдено: ${_filteredItems.length} из ${_visibleItems.length}',
                  ),
                  style: textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItems(BuildContext context) {
    final items = _filteredItems;
    if (items.isEmpty) {
      return _emptyCard(
        context,
        icon: Icons.assignment_outlined,
        message: _hasItemFilters
            ? LunoraLocalization.text('Ничего не найдено', 'Nothing found')
            : LunoraLocalization.text('Учебных событий пока нет', 'No study events yet'),
        hint: _hasItemFilters
            ? LunoraLocalization.text('Измени условия поиска или сбрось фильтры.', 'Change your search or reset the filters.')
            : LunoraLocalization.text('Добавляй лекции, тесты, письменные работы и экзамены.', 'Add lectures, tests, written assignments and exams.'),
      );
    }

    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // На широком экране события располагаются в две колонки,
        // на узком окне переходят в одну, чтобы карточки не сжимались.
        final columns = constraints.maxWidth >= 680 ? 2 : 1;
        final spacing = 12.0;
        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            final subject = _subjectForItem(item);
            final isCompleted = item.status == StudyItemStatus.completed;
            final accent = isCompleted ? colors.tertiary : colors.secondary;

            return SizedBox(
              width: cardWidth,
              child: Container(
                constraints: const BoxConstraints(minHeight: 142),
                padding: const EdgeInsets.fromLTRB(14, 13, 8, 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(19),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: .55),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: .025),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: 3,
                      top: 0,
                      child: IgnorePointer(
                        child: Icon(
                          Icons.spa_outlined,
                          size: 43,
                          color: colors.tertiary.withValues(alpha: .10),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: .13),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(
                                isCompleted
                                    ? Icons.check_rounded
                                    : _itemIcon(item.type),
                                color: accent,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    height: 1.2,
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 42,
                                minHeight: 42,
                              ),
                              tooltip: LunoraLocalization.text('Действия'),
                              onSelected: (value) {
                                if (value == 'edit') _editItem(item);
                                if (value == 'delete') _deleteItem(item);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(
                                    LunoraLocalization.text('Редактировать'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    LunoraLocalization.text('Удалить'),
                                  ),
                                ),
                              ],
                              icon: const Icon(Icons.more_horiz_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _metaChip(context, _itemTypeName(item.type)),
                            if (subject != null)
                              _metaChip(context, subject.name),
                            _metaChip(context, _statusName(item.status)),
                          ],
                        ),
                        if (item.scheduledAt != null || item.dueAt != null) ...[
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 14,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  [
                                    if (item.scheduledAt != null)
                                      _dateTimeLabel(item.scheduledAt!),
                                    if (item.dueAt != null)
                                      'Срок: ${_dateLabel(item.dueAt)}',
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _metaChip(BuildContext context, String label) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: colors.onSurfaceVariant),
      ),
    );
  }

  // ИКОНКИ СОБЫТИЙ

  // ИКОНКИ СОБЫТИЙ

  IconData _itemIcon(StudyItemType type) {
    switch (type) {
      case StudyItemType.lecture:
      case StudyItemType.onlineLecture:
        return Icons.menu_book_outlined;

      case StudyItemType.test:
        return Icons.quiz_outlined;

      case StudyItemType.writtenAssignment:
        return Icons.edit_note_outlined;

      case StudyItemType.exam:
        return Icons.school_outlined;

      case StudyItemType.credit:
        return Icons.assignment_turned_in_outlined;

      case StudyItemType.practice:
        return Icons.work_outline;

      case StudyItemType.coursework:
      case StudyItemType.diploma:
        return Icons.description_outlined;

      case StudyItemType.other:
        return Icons.event_note_outlined;
    }
  }

  // ПУСТЫЕ СОСТОЯНИЯ

  Widget _emptyCard(
    BuildContext context, {

    required IconData icon,

    required String message,

    required String hint,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),

        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 34, color: colors.onSurfaceVariant),

              const SizedBox(height: 10),

              Text(
                message,

                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),

                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 5),

              Text(
                hint,

                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),

                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
