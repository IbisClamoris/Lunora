import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/localization/lunora_localization.dart';
import '../../core/tasks/models/task.dart';
import '../../core/tasks/repositories/task_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/lunora_design.dart';
import '../../core/theme/lunora_theme_assets.dart';
import '../../core/settings/settings_service.dart';

import '../../shared/widgets/lunora_visuals.dart';
import '../../shared/widgets/lunora_theme_decoration.dart';

import '../../features/books/models/book_entry.dart';
import '../../features/books/repositories/book_repository.dart';

import '../../features/diary/models/diary_entry.dart';
import '../../features/diary/repositories/diary_repository.dart';
import '../../features/diary/pages/diary_preview_page.dart';

import '../../features/finance/models/finance_models.dart';
import '../../features/finance/repositories/finance_repository.dart';

import '../../features/shopping/models/shopping_item.dart';
import '../../features/shopping/repositories/shopping_repository.dart';

class LunoraDashboard extends StatefulWidget {
  final ValueChanged<int> onNavigate;
  final VoidCallback onCreatePlannerNote;
  final VoidCallback onCreateDiaryEntry;
  final VoidCallback onCreateShoppingItem;
  final VoidCallback onCreateRecipe;
  final VoidCallback onOpenShopping;
  final VoidCallback onOpenDebts;

  const LunoraDashboard({
    super.key,
    required this.onNavigate,
    required this.onCreatePlannerNote,
    required this.onCreateDiaryEntry,
    required this.onCreateShoppingItem,
    required this.onCreateRecipe,
    required this.onOpenShopping,
    required this.onOpenDebts,
  });

  @override
  State<LunoraDashboard> createState() => _LunoraDashboardState();
}

class _LunoraDashboardState extends State<LunoraDashboard> {
  bool _loading = true;
  String? _error;

  List<Task> _tasks = [];
  List<DiaryEntry> _diaryEntries = [];
  List<BookEntry> _readingBooks = [];
  List<ShoppingItem> _shoppingItems = [];
  List<FinanceDebt> _activeDebts = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _openDiaryEntry(DiaryEntry entry) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => DiaryPreviewPage(entry: entry)),
    );

    if (mounted) {
      await _loadDashboard();
    }
  }

  Future<void> _loadDashboard() async {
    try {
      final results = await Future.wait<dynamic>([
        TaskRepository.instance.getAll(),
        DiaryRepository.instance.getAll(),
        BookRepository.instance.getByStatus('reading'),
        ShoppingRepository.instance.getAll(isPurchased: false),
        FinanceRepository.instance.getDebts(status: FinanceDebtStatus.active),
      ]);

      if (!mounted) return;

      setState(() {
        _tasks = results[0] as List<Task>;
        _diaryEntries = results[1] as List<DiaryEntry>;
        _readingBooks = results[2] as List<BookEntry>;
        _shoppingItems = results[3] as List<ShoppingItem>;
        _activeDebts = results[4] as List<FinanceDebt>;

        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  DateTime get _today => DateUtils.dateOnly(DateTime.now());

  bool _isSameDay(DateTime? date, DateTime day) {
    return date != null &&
        date.year == day.year &&
        date.month == day.month &&
        date.day == day.day;
  }

  List<Task> get _todayTasks {
    final result = _tasks.where((task) {
      return _isSameDay(task.dueDate, _today) &&
          task.status != TaskStatus.completed &&
          task.status != TaskStatus.cancelled;
    }).toList();

    result.sort(
      (a, b) => (a.dueTimeMinutes ?? 1440).compareTo(b.dueTimeMinutes ?? 1440),
    );

    return result;
  }

  List<Task> get _overdueTasks {
    return _tasks.where((task) => task.isOverdue).toList();
  }

  int get _completedToday {
    return _tasks.where((task) {
      return task.status == TaskStatus.completed &&
          _isSameDay(task.completedAt, _today);
    }).length;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final english = LunoraLocalization.isEnglish;
    if (hour >= 5 && hour < 12) return english ? 'Good morning' : 'Доброе утро';
    if (hour >= 12 && hour < 18) {
      return english ? 'Good afternoon' : 'Добрый день';
    }
    if (hour >= 18 && hour < 23) {
      return english ? 'Good evening' : 'Добрый вечер';
    }
    return english ? 'Good night' : 'Доброй ночи';
  }

  String _dateLabel() {
    final locale = LunoraLocalization.isEnglish ? 'en_US' : 'ru_RU';
    final value = DateFormat('EEEE, d MMMM', locale).format(DateTime.now());
    return value[0].toUpperCase() + value.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<LunoraPalette>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;

        return RefreshIndicator(
          onRefresh: _loadDashboard,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(compact ? 18 : 30),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DashboardHeader(
                      greeting: _greeting(),
                      date: _dateLabel(),
                      onCalendar: () => widget.onNavigate(1),
                    ),

                    const SizedBox(height: 24),

                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _ErrorPanel(message: _error!, onRetry: _loadDashboard)
                    else ...[
                      _DailyOverview(
                        todayCount: _todayTasks.length,
                        overdueCount: _overdueTasks.length,
                        completedCount: _completedToday,
                        shoppingCount: _shoppingItems.length,
                      ),

                      const SizedBox(height: 24),

                      if (compact) ...[
                        _TodayPanel(tasks: _todayTasks, overdue: _overdueTasks),
                        const SizedBox(height: 18),
                        _LifeInProgressPanel(
                          readingBooks: _readingBooks,
                          diaryEntries: _diaryEntries,
                          shoppingItems: _shoppingItems,
                          activeDebts: _activeDebts,
                          onNavigate: widget.onNavigate,
                          onOpenDiaryEntry: _openDiaryEntry,
                          onOpenShopping: widget.onOpenShopping,
                          onOpenDebts: widget.onOpenDebts,
                        ),
                      ] else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 6,
                              child: _TodayPanel(
                                tasks: _todayTasks,
                                overdue: _overdueTasks,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              flex: 5,
                              child: _LifeInProgressPanel(
                                readingBooks: _readingBooks,
                                diaryEntries: _diaryEntries,
                                shoppingItems: _shoppingItems,
                                activeDebts: _activeDebts,
                                onNavigate: widget.onNavigate,
                                onOpenDiaryEntry: _openDiaryEntry,
                                onOpenShopping: widget.onOpenShopping,
                                onOpenDebts: widget.onOpenDebts,
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 24),

                      _QuickActions(
                        onCreatePlannerNote: widget.onCreatePlannerNote,
                        onCreateDiaryEntry: widget.onCreateDiaryEntry,
                        onCreateShoppingItem: widget.onCreateShoppingItem,
                        onCreateRecipe: widget.onCreateRecipe,
                      ),
                    ],

                    const SizedBox(height: 20),

                    _DailyThought(
                      color: palette.accentSoft,
                      textColor: palette.text,
                      accentColor: palette.accent,
                    ),
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

// ============================================================
// HEADER
// ============================================================

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.greeting,
    required this.date,
    required this.onCalendar,
  });

  final String greeting;
  final String date;
  final VoidCallback onCalendar;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    return LunoraPaperSurface(
      padding: const EdgeInsets.fromLTRB(26, 24, 24, 22),
      borderRadius: LunoraRadius.xl,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: p.secondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  LunoraLocalization.text(
                    'Твой день в Lunora',
                    'Your day in Lunora',
                  ),
                  style: TextStyle(
                    color: p.text,
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(date, style: TextStyle(color: p.secondary, fontSize: 13)),
                const SizedBox(height: 10),
                const SizedBox(
                  width: 300,
                  child: LunoraThemeDivider(
                    height: 24,
                    opacity: 0.8,
                    horizontalPadding: 0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: onCalendar,
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(LunoraLocalization.text('Календарь')),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DAILY OVERVIEW
// ============================================================

class _DailyOverview extends StatelessWidget {
  const _DailyOverview({
    required this.todayCount,
    required this.overdueCount,
    required this.completedCount,
    required this.shoppingCount,
  });

  final int todayCount;
  final int overdueCount;
  final int completedCount;
  final int shoppingCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 520 ? 2 : 4;
        final p = Theme.of(context).extension<LunoraPalette>()!;

        final cards = [
          _StatData(
            title: LunoraLocalization.text('На сегодня', 'Today'),
            value: '$todayCount',
            icon: Icons.today_outlined,
            color: p.sagePanel,
            assetPath: LunoraThemeAssets.icon(
              SettingsService.instance.settings.colorTheme,
              'calendar',
            ),
          ),
          _StatData(
            title: LunoraLocalization.text('Просрочено', 'Overdue'),
            value: '$overdueCount',
            icon: Icons.schedule_outlined,
            color: p.rose,
            assetPath: LunoraThemeAssets.icon(
              SettingsService.instance.settings.colorTheme,
              'reminder',
            ),
          ),
          _StatData(
            title: LunoraLocalization.text(
              'Выполнено сегодня',
              'Completed today',
            ),
            value: '$completedCount',
            icon: Icons.check_circle_outline,
            color: p.lavender,
            assetPath: LunoraThemeAssets.icon(
              SettingsService.instance.settings.colorTheme,
              'check',
            ),
          ),
          _StatData(
            title: LunoraLocalization.text(
              'В списке покупок',
              'On shopping list',
            ),
            value: '$shoppingCount',
            icon: Icons.shopping_basket_outlined,
            color: p.accentSoft,
            assetPath: LunoraThemeAssets.icon(
              SettingsService.instance.settings.colorTheme,
              'shopping',
            ),
          ),
        ];

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cards.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 104,
          ),
          itemBuilder: (context, index) {
            return _StatCard(data: cards[index]);
          },
        );
      },
    );
  }
}

class _StatData {
  const _StatData({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.assetPath,
  });

  final String title;
  final String value;
  final String? assetPath;
  final IconData icon;
  final Color color;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    return Material(
      color: Colors.transparent,
      child: LunoraPaperSurface(
        borderRadius: LunoraRadius.lg,
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: data.color,
                borderRadius: BorderRadius.circular(13),
              ),
              child: data.assetPath == null
                  ? Icon(data.icon, color: p.text, size: 20)
                  : Padding(
                      padding: const EdgeInsets.all(10),
                      child: LunoraAssetIcon(data.assetPath!, size: 22),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    data.value,
                    style: TextStyle(
                      color: p.text,
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.secondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TODAY PANEL
// ============================================================

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.tasks, required this.overdue});

  final List<Task> tasks;
  final List<Task> overdue;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    return _Panel(
      title: LunoraLocalization.text('План на сегодня', "Today's plan"),
      subtitle: LunoraLocalization.text(
        'Ближайшие дела и то, что требует внимания',
        "Upcoming tasks and things that need attention",
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overdue.isNotEmpty) ...[
            _InlineNotice(
              icon: Icons.warning_amber_rounded,
              text: 'Просрочено: ${overdue.length}',
              color: p.rose,
            ),
            const SizedBox(height: 10),
          ],
          if (tasks.isEmpty)
            const _EmptyHint(
              icon: Icons.event_available_outlined,
              text:
                  'На сегодня пока ничего не запланировано. '
                  'Можно выдохнуть или добавить новое дело.',
            )
          else
            ...tasks.take(6).map((task) => _TaskRow(task: task)),
          if (tasks.length > 6)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                LunoraLocalization.text(
                  'И ещё ${tasks.length - 6} дел в календаре',
                ),
                style: TextStyle(color: p.secondary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    final time = task.dueTimeMinutes == null
        ? 'Весь день'
        : '${(task.dueTimeMinutes! ~/ 60).toString().padLeft(2, '0')}:'
              '${(task.dueTimeMinutes! % 60).toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: task.isOverdue ? p.rose : p.accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(time, style: TextStyle(color: p.secondary, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.circle_outlined, size: 17, color: p.secondary),
        ],
      ),
    );
  }
}

// ============================================================
// LIFE IN PROGRESS
// ============================================================

class _LifeInProgressPanel extends StatelessWidget {
  const _LifeInProgressPanel({
    required this.readingBooks,
    required this.diaryEntries,
    required this.shoppingItems,
    required this.activeDebts,
    required this.onNavigate,
    required this.onOpenDiaryEntry,
    required this.onOpenShopping,
    required this.onOpenDebts,
  });

  final List<BookEntry> readingBooks;
  final List<DiaryEntry> diaryEntries;
  final List<ShoppingItem> shoppingItems;
  final List<FinanceDebt> activeDebts;

  final ValueChanged<int> onNavigate;
  final ValueChanged<DiaryEntry> onOpenDiaryEntry;
  final VoidCallback onOpenShopping;
  final VoidCallback onOpenDebts;

  @override
  Widget build(BuildContext context) {
    final latestDiary = [...diaryEntries]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    return Column(
      children: [
        _Panel(
          title: LunoraLocalization.text('Сейчас в процессе', "In progress"),
          subtitle: LunoraLocalization.text(
            'То, к чему можно вернуться',
            "Things to return to",
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (readingBooks.isEmpty)
                _CompactLine(
                  icon: Icons.menu_book_outlined,
                  assetPath: LunoraThemeAssets.icon(
                    SettingsService.instance.settings.colorTheme,
                    'books',
                  ),
                  title: LunoraLocalization.text('Нет книги в процессе чтения'),
                  subtitle: LunoraLocalization.text(
                    'Книжный мир ждёт продолжения',
                  ),
                  onTap: () => onNavigate(10),
                )
              else
                ...readingBooks
                    .take(2)
                    .map(
                      (book) => _CompactLine(
                        icon: Icons.menu_book_outlined,
                        assetPath: LunoraThemeAssets.icon(
                          SettingsService.instance.settings.colorTheme,
                          'books',
                        ),
                        title: book.title,
                        subtitle: book.pageCount == null
                            ? 'Читаю сейчас'
                            : '${book.currentPage} из ${book.pageCount} страниц',
                        onTap: () => onNavigate(10),
                      ),
                    ),

              const LunoraThemeDivider(height: 28, opacity: 0.8),

              if (latestDiary.isEmpty)
                _CompactLine(
                  icon: Icons.edit_note_outlined,
                  assetPath: LunoraThemeAssets.icon(
                    SettingsService.instance.settings.colorTheme,
                    'diary',
                  ),
                  title: LunoraLocalization.text('Дневник пока пуст'),
                  subtitle: LunoraLocalization.text(
                    'Сохрани маленький момент дня',
                  ),
                  onTap: null,
                )
              else
                ...latestDiary
                    .take(2)
                    .map(
                      (entry) => _CompactLine(
                        icon: Icons.edit_note_outlined,
                        assetPath: LunoraThemeAssets.icon(
                          SettingsService.instance.settings.colorTheme,
                          'diary',
                        ),
                        title: entry.title.isEmpty
                            ? 'Запись без названия'
                            : entry.title,
                        subtitle: _shortDate(entry.entryDate),
                        onTap: () => onOpenDiaryEntry(entry),
                      ),
                    ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        _Panel(
          title: LunoraLocalization.text(
            'Небольшие напоминания',
            "Small reminders",
          ),
          subtitle: LunoraLocalization.text(
            'Сводка по другим делам',
            "A summary of other things",
          ),
          child: Column(
            children: [
              _CompactLine(
                icon: Icons.shopping_basket_outlined,
                assetPath: LunoraThemeAssets.icon(
                  SettingsService.instance.settings.colorTheme,
                  'shopping',
                ),
                title: LunoraLocalization.text('Покупки'),
                subtitle: shoppingItems.isEmpty
                    ? 'Список пуст'
                    : '${shoppingItems.length} пунктов ожидают покупки',
                onTap: onOpenShopping,
              ),

              const LunoraThemeDivider(height: 28, opacity: 0.8),

              _CompactLine(
                icon: Icons.account_balance_wallet_outlined,
                title: LunoraLocalization.text('Активные кредиты'),
                subtitle: activeDebts.isEmpty
                    ? 'Нет активных задолженностей'
                    : '${activeDebts.length} активных обязательств',
                onTap: onOpenDebts,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _shortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }
}

// ============================================================
// COMPACT LINE
// ============================================================

class _CompactLine extends StatelessWidget {
  const _CompactLine({
    required this.icon,
    this.assetPath,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: p.accentSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: assetPath == null
                    ? Icon(icon, size: 18, color: p.accent)
                    : Padding(
                        padding: const EdgeInsets.all(8),
                        child: LunoraAssetIcon(assetPath!, size: 20),
                      ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.secondary, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: p.secondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// QUICK ACTIONS
// ============================================================

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onCreatePlannerNote,
    required this.onCreateDiaryEntry,
    required this.onCreateShoppingItem,
    required this.onCreateRecipe,
  });

  final VoidCallback onCreatePlannerNote;
  final VoidCallback onCreateDiaryEntry;
  final VoidCallback onCreateShoppingItem;
  final VoidCallback onCreateRecipe;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    return _Panel(
      title: LunoraLocalization.text('Быстрые действия'),
      subtitle: LunoraLocalization.text(
        'Перейти сразу к тому, что хочешь добавить',
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _ActionChip(
            icon: Icons.calendar_view_day_outlined,
            assetPath: LunoraThemeAssets.icon(
              SettingsService.instance.settings.colorTheme,
              'planner',
            ),
            label: LunoraLocalization.text('Мой планер'),
            color: p.sagePanel,
            onTap: onCreatePlannerNote,
          ),
          _ActionChip(
            icon: Icons.edit_note_outlined,
            assetPath: LunoraThemeAssets.icon(
              SettingsService.instance.settings.colorTheme,
              'diary',
            ),
            label: LunoraLocalization.text('Запись в дневник'),
            color: p.lavender,
            onTap: onCreateDiaryEntry,
          ),
          _ActionChip(
            icon: Icons.add_shopping_cart_outlined,
            assetPath: LunoraThemeAssets.icon(
              SettingsService.instance.settings.colorTheme,
              'shopping',
            ),
            label: LunoraLocalization.text('Покупка'),
            color: p.rose,
            onTap: onCreateShoppingItem,
          ),
          _ActionChip(
            icon: Icons.menu_book_outlined,
            assetPath: LunoraThemeAssets.icon(
              SettingsService.instance.settings.colorTheme,
              'recipes',
            ),
            label: LunoraLocalization.text('Рецепты'),
            color: p.accentSoft,
            onTap: onCreateRecipe,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    this.assetPath,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String? assetPath;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    return ActionChip(
      avatar: assetPath == null
          ? Icon(icon, size: 17, color: p.text)
          : LunoraAssetIcon(assetPath!, size: 19),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: color,
      side: BorderSide(color: p.border),
      labelStyle: TextStyle(
        color: p.text,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
    );
  }
}

// ============================================================
// SHARED PANEL
// ============================================================

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    return LunoraPaperSurface(
      borderRadius: LunoraRadius.lg,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: p.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: p.secondary, fontSize: 11)),
          const SizedBox(height: 10),
          const LunoraThemeDivider(height: 36, opacity: 0.85),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ============================================================
// NOTICES AND EMPTY STATES
// ============================================================

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Text(
            LunoraLocalization.text(text),
            style: TextStyle(
              color: p.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: p.accent, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              LunoraLocalization.text(text),
              style: TextStyle(color: p.secondary, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DAILY THOUGHT
// ============================================================

class _DailyThought extends StatelessWidget {
  const _DailyThought({
    required this.color,
    required this.textColor,
    required this.accentColor,
  });

  final Color color;
  final Color textColor;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(LunoraRadius.lg),
      ),
      child: Row(
        children: [
          Icon(Icons.spa_outlined, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${LunoraLocalization.text('Не обязательно успеть всё. ')}Пусть сегодня найдётся место и для себя.',
              style: TextStyle(color: textColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ERROR PANEL
// ============================================================

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = Theme.of(context).extension<LunoraPalette>()!;

    return _Panel(
      title: LunoraLocalization.text('Не удалось загрузить сводку'),
      subtitle: LunoraLocalization.text('Данные разделов пока недоступны'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: TextStyle(color: p.secondary, fontSize: 11)),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(LunoraLocalization.text('Повторить')),
          ),
        ],
      ),
    );
  }
}
