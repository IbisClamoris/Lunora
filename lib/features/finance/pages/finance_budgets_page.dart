import 'package:lunora/core/settings/settings_service.dart';
import 'package:lunora/core/theme/lunora_theme_assets.dart';
import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:lunora/features/finance/models/finance_models.dart';
import 'package:lunora/features/finance/models/finance_budget.dart';
import 'package:lunora/features/finance/repositories/finance_repository.dart';

class FinanceBudgetsPage extends StatefulWidget {
  const FinanceBudgetsPage({super.key});

  @override
  State<FinanceBudgetsPage> createState() => _FinanceBudgetsPageState();
}

class _FinanceBudgetsPageState extends State<FinanceBudgetsPage> {
  final FinanceRepository _repository = FinanceRepository.instance;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  List<FinanceBudget> _budgets = [];
  List<FinanceCategory> _categories = [];

  Map<String, Map<String, Object>> _progress = {};

  bool _isLoading = true;
  String? _error;

  int get _year => _selectedMonth.year;
  int get _month => _selectedMonth.month;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.getBudgets(year: _year, month: _month),
        _repository.getCategories(type: FinanceCategoryType.expense),
        _repository.getBudgetsWithProgress(year: _year, month: _month),
      ]);

      final budgets = results[0] as List<FinanceBudget>;
      final categories = results[1] as List<FinanceCategory>;
      final progressRows = results[2] as List<Map<String, Object>>;

      final progress = <String, Map<String, Object>>{};

      for (final row in progressRows) {
        final budget = row['budget'] as FinanceBudget;
        progress[budget.id] = row;
      }

      if (!mounted) return;

      setState(() {
        _budgets = budgets;
        _categories = categories;
        _progress = progress;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });

    _loadData();
  }

  String _monthName(DateTime date) {
    final months = LunoraLocalization.isEnglish
        ? const ['January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December']
        : const ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
            'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatMoney(int minor) {
    final amount = (minor.abs() / 100).toStringAsFixed(2);
    final parts = amount.split('.');
    final integerPart = parts[0];

    final buffer = StringBuffer();

    for (var i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        buffer.write(' ');
      }

      buffer.write(integerPart[i]);
    }

    final sign = minor < 0 ? '−' : '';

    return '$sign${buffer.toString()},${parts[1]} ₽';
  }

  FinanceCategory? _categoryById(String id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }

    return null;
  }

  int get _totalLimit {
    return _budgets.fold(0, (sum, budget) => sum + budget.limitMinor);
  }

  int get _totalSpent {
    return _budgets.fold(0, (sum, budget) {
      final row = _progress[budget.id];
      final spent = row?['spent'] as int? ?? 0;

      return sum + spent;
    });
  }

  int get _totalRemaining => _totalLimit - _totalSpent;

  Future<void> _openBudgetDialog({FinanceBudget? budget}) async {
    final activeCategories = _categories
        .where((category) => category.isActive)
        .toList();

    if (activeCategories.isEmpty) {
      _showMessage('Сначала создай активную категорию расходов.');
      return;
    }

    final existingCategory = budget == null
        ? null
        : _categoryById(budget.categoryId);

    final availableCategories = [...activeCategories];

    if (existingCategory != null &&
        !availableCategories.any(
          (category) => category.id == existingCategory.id,
        )) {
      availableCategories.add(existingCategory);
    }

    final result = await showDialog<_BudgetDialogResult>(
      context: context,
      builder: (context) {
        return _BudgetDialog(
          categories: availableCategories,
          initialCategoryId: budget?.categoryId,
          initialAmountMinor: budget?.limitMinor,
          title: budget == null ? LunoraLocalization.text('Новый бюджет') : LunoraLocalization.text('Изменить бюджет'),
        );
      },
    );

    if (result == null) return;

    try {
      if (budget == null) {
        await _repository.createBudget(
          categoryId: result.categoryId,
          year: _year,
          month: _month,
          limitMinor: result.limitMinor,
        );
      } else {
        await _repository.updateBudget(
          budget.copyWith(
            categoryId: result.categoryId,
            limitMinor: result.limitMinor,
            updatedAt: DateTime.now(),
          ),
        );
      }

      await _loadData();

      if (!mounted) return;

      _showMessage(budget == null ? 'Бюджет создан.' : 'Бюджет обновлён.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Не удалось сохранить бюджет: $e');
    }
  }

  Future<void> _deleteBudget(FinanceBudget budget) async {
    final category = _categoryById(budget.categoryId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            LunoraLocalization.text('Удалить бюджет?'),
            style: TextStyle(fontSize: 17),
          ),
          content: Text(
            '${LunoraLocalization.text('Бюджет категории ')}«${category?.name ?? 'Неизвестная категория'}» за ${_monthName(_selectedMonth)} будет удалён.',
            style: const TextStyle(fontSize: 13),
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
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _repository.deleteBudget(budget.id);
      await _loadData();

      if (!mounted) return;
      _showMessage('Бюджет удалён.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Не удалось удалить бюджет: $e');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: const TextStyle(fontSize: 12))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final twoColumns = constraints.maxWidth >= 650;

          return ListView(
            padding: EdgeInsets.all(compact ? 12 : 16),
            children: [
              _buildMonthSelector(compact),
              Padding(
                padding: const EdgeInsets.only(
                  top: 8,
                  bottom: 5,
                  left: 8,
                  right: 8,
                ),
                child: Opacity(
                  opacity: 0.82,
                  child: SvgPicture.asset(
                    LunoraThemeAssets.divider(
                      SettingsService.instance.settings.colorTheme,
                    ),
                    width: double.infinity,
                    height: 34,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _buildError()
              else ...[
                _buildSummary(compact),
                const SizedBox(height: 14),
                _buildBudgetHeader(),
                const SizedBox(height: 9),
                if (_budgets.isEmpty)
                  _buildEmpty()
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _budgets.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: twoColumns ? 2 : 1,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 8,
                      mainAxisExtent: twoColumns ? 145 : 145,
                    ),
                    itemBuilder: (context, index) {
                      return _buildBudgetCard(_budgets[index]);
                    },
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthSelector(bool compact) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: LunoraLocalization.text('Предыдущий месяц'),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: () => _changeMonth(-1),
              icon: const Icon(Icons.chevron_left, size: 21),
            ),
            Expanded(
              child: Text(
                _monthName(_selectedMonth),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              tooltip: LunoraLocalization.text('Следующий месяц'),
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
              onPressed: () => _changeMonth(1),
              icon: const Icon(Icons.chevron_right, size: 21),
            ),
            if (!compact)
              IconButton(
                tooltip: LunoraLocalization.text('Текущий месяц'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () {
                  final now = DateTime.now();

                  setState(() {
                    _selectedMonth = DateTime(now.year, now.month);
                  });

                  _loadData();
                },
                icon: const Icon(Icons.today, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(bool compact) {
    final exceeded = _budgets.where((budget) {
      final row = _progress[budget.id];
      return row?['is_exceeded'] == true;
    }).length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LunoraLocalization.text('Сводка за месяц'),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (compact)
              Column(
                children: [
                  _summaryItem(
                    'Установлено лимитов',
                    _formatMoney(_totalLimit),
                    Icons.account_balance_wallet_outlined,
                  ),
                  const SizedBox(height: 10),
                  _summaryItem(
                    'Потрачено',
                    _formatMoney(_totalSpent),
                    Icons.shopping_bag_outlined,
                  ),
                  const SizedBox(height: 10),
                  _summaryItem(
                    'Осталось',
                    _formatMoney(_totalRemaining),
                    Icons.savings_outlined,
                    negative: _totalRemaining < 0,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _summaryItem(
                      'Лимиты',
                      _formatMoney(_totalLimit),
                      Icons.account_balance_wallet_outlined,
                    ),
                  ),
                  Expanded(
                    child: _summaryItem(
                      'Потрачено',
                      _formatMoney(_totalSpent),
                      Icons.shopping_bag_outlined,
                    ),
                  ),
                  Expanded(
                    child: _summaryItem(
                      'Осталось',
                      _formatMoney(_totalRemaining),
                      Icons.savings_outlined,
                      negative: _totalRemaining < 0,
                    ),
                  ),
                ],
              ),
            if (exceeded > 0) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error,
                    size: 18,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${LunoraLocalization.text('Превышен лимит в $exceeded ')}${_budgetWord(exceeded)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _budgetWord(int count) {
    final lastTwo = count % 100;

    if (lastTwo >= 11 && lastTwo <= 14) {
      return LunoraLocalization.isEnglish ? 'categories' : 'категориях';
    }

    switch (count % 10) {
      case 1:
        return LunoraLocalization.isEnglish ? 'category' : 'категории';
      case 2:
      case 3:
      case 4:
        return 'категориях';
      default:
        return 'категориях';
    }
  }

  Widget _summaryItem(
    String title,
    String value,
    IconData icon, {
    bool negative = false,
  }) {
    final color = negative ? Theme.of(context).colorScheme.error : null;

    return Row(
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBudgetHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            LunoraLocalization.text('Лимиты по категориям'),
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            minimumSize: const Size(0, 34),
            textStyle: const TextStyle(fontSize: 12),
          ),
          onPressed: () => _openBudgetDialog(),
          icon: const Icon(Icons.add, size: 17),
          label: Text(LunoraLocalization.text('Добавить')),
        ),
      ],
    );
  }

  Widget _buildBudgetCard(FinanceBudget budget) {
    final category = _categoryById(budget.categoryId);
    final row = _progress[budget.id];

    final spent = row?['spent'] as int? ?? 0;
    final remaining = row?['remaining'] as int? ?? budget.limitMinor - spent;
    final percent = row?['percent'] as int? ?? 0;
    final exceeded = row?['is_exceeded'] == true;

    final progressValue = (percent / 100).clamp(0.0, 1.0);

    final color = exceeded
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    category?.name ?? 'Неизвестная категория',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: LunoraLocalization.text('Действия'),
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openBudgetDialog(budget: budget);
                    } else if (value == 'delete') {
                      _deleteBudget(budget);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 9),
                          Text(
                            LunoraLocalization.text('Изменить'),
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18),
                          SizedBox(width: 9),
                          Text(
                            LunoraLocalization.text('Удалить'),
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              _formatMoney(spent),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              LunoraLocalization.text('из ${_formatMoney(budget.limitMinor)}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progressValue,
                minHeight: 6,
                color: color,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '$percent%',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    exceeded
                        ? 'Превышение: ${_formatMoney(remaining.abs())}'
                        : 'Осталось: ${_formatMoney(remaining)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 10,
                      color: exceeded
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 9),
            Text(
              LunoraLocalization.text('На этот месяц бюджетов пока нет'),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${LunoraLocalization.text('Установи лимиты расходов по категориям, ')}чтобы отслеживать траты.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: const Size(0, 34),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: () => _openBudgetDialog(),
              icon: const Icon(Icons.add, size: 17),
              label: Text(LunoraLocalization.text('Создать бюджет')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 30),
            const SizedBox(height: 9),
            Text(
              LunoraLocalization.text('Не удалось загрузить бюджеты'),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 34),
                textStyle: const TextStyle(fontSize: 12),
              ),
              onPressed: _loadData,
              child: Text(LunoraLocalization.text('Повторить')),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetDialogResult {
  const _BudgetDialogResult({
    required this.categoryId,
    required this.limitMinor,
  });

  final String categoryId;
  final int limitMinor;
}

class _BudgetDialog extends StatefulWidget {
  const _BudgetDialog({
    required this.categories,
    required this.title,
    this.initialCategoryId,
    this.initialAmountMinor,
  });

  final List<FinanceCategory> categories;
  final String title;
  final String? initialCategoryId;
  final int? initialAmountMinor;

  @override
  State<_BudgetDialog> createState() => _BudgetDialogState();
}

class _BudgetDialogState extends State<_BudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;

  String? _categoryId;

  @override
  void initState() {
    super.initState();

    _categoryId =
        widget.initialCategoryId ??
        (widget.categories.isNotEmpty ? widget.categories.first.id : null);

    _amountController = TextEditingController(
      text: widget.initialAmountMinor == null
          ? ''
          : (widget.initialAmountMinor! / 100)
                .toStringAsFixed(2)
                .replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  int? _parseAmount(String value) {
    final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');

    final amount = double.tryParse(normalized);

    if (amount == null || !amount.isFinite || amount <= 0) {
      return null;
    }

    return (amount * 100).round();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountController.text);

    if (amount == null || _categoryId == null) return;

    Navigator.pop(
      context,
      _BudgetDialogResult(categoryId: _categoryId!, limitMinor: amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      content: Form(
        key: _formKey,
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                isExpanded: true,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: LunoraLocalization.text('Категория расходов'),
                  labelStyle: TextStyle(fontSize: 12),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 11,
                  ),
                ),
                items: widget.categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Text(
                      category.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _categoryId = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Выбери категорию.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: LunoraLocalization.text('Месячный лимит'),
                  labelStyle: TextStyle(fontSize: 12),
                  suffixText: '₽',
                  hintText: LunoraLocalization.text('Например, 15000'),
                  hintStyle: TextStyle(fontSize: 12),
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 11,
                  ),
                ),
                validator: (value) {
                  if (_parseAmount(value ?? '') == null) {
                    return 'Введи сумму больше нуля.';
                  }

                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            LunoraLocalization.text('Отмена'),
            style: TextStyle(fontSize: 12),
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            LunoraLocalization.text('Сохранить'),
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
