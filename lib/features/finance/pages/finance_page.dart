import 'package:lunora/core/settings/settings_service.dart';
import 'package:lunora/core/theme/lunora_theme_assets.dart';
import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:lunora/features/finance/models/finance_models.dart';
import 'package:lunora/features/finance/repositories/finance_repository.dart';
import 'package:lunora/features/finance/services/finance_excel_import_service.dart';

import 'finance_analytics_overview.dart';
import 'finance_budgets_page.dart';
import 'finance_excel_import_page.dart';

enum _TransactionSort { dateNewest, dateOldest, amountHighest, amountLowest }

class FinancePage extends StatefulWidget {
  final int initialTabIndex;

  const FinancePage({super.key, this.initialTabIndex = 0});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage>
    with SingleTickerProviderStateMixin {
  final FinanceRepository _repository = FinanceRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  late final TabController _tabs;

  bool _loading = true;
  String? _error;

  List<FinanceAccount> _accounts = [];
  List<FinanceCategory> _categories = [];
  List<FinanceTransaction> _transactions = [];
  List<FinanceDebt> _debts = [];

  FinanceTransactionType? _typeFilter;
  String? _accountFilter;
  String? _categoryFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  _TransactionSort _sort = _TransactionSort.dateNewest;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 6,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 5).toInt(),
    );
    _loadData();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _repository.getAccounts(),
        _repository.getCategories(),
        _repository.getTransactions(),
        _repository.getDebts(),
      ]);

      if (!mounted) return;

      setState(() {
        _accounts = results[0] as List<FinanceAccount>;
        _categories = results[1] as List<FinanceCategory>;
        _transactions = results[2] as List<FinanceTransaction>;
        _debts = results[3] as List<FinanceDebt>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _importExcel() async {
    try {
      final result = await Navigator.of(context).push<FinanceExcelImportResult>(
        MaterialPageRoute(builder: (_) => const FinanceExcelImportPage()),
      );

      if (!mounted || result == null) return;

      await _loadData();

      if (!mounted) return;

      await _showMessage(
        'Импорт завершён.\n'
        'Счета: ${result.accounts}\n'
        'Категории: ${result.categories}\n'
        'Операции: ${result.transactions}\n'
        'Кредиты: ${result.debts}\n'
        'Бюджеты: ${result.budgets}\n'
        'Накопления: ${result.savingsGoals}\n'
        'Пропущено дубликатов операций: ${result.skippedTransactions}',
      );
    } catch (error) {
      await _showError(error);
    }
  }

  String _money(int minor, [String currency = 'RUB']) {
    final amount = (minor.abs() / 100).toStringAsFixed(2);
    final parts = amount.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    final sign = minor < 0 ? '−' : '';
    final symbol = switch (currency) {
      'RUB' => '₽',
      'USD' => r'$',
      'EUR' => '€',
      _ => currency,
    };

    return '$sign$whole,${parts[1]} $symbol';
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  FinanceAccount? _account(String? id) {
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  FinanceCategory? _category(String? id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  int _parseMinor(String value) {
    final normalized = value.trim().replaceAll(' ', '').replaceAll(',', '.');
    final amount = double.tryParse(normalized);

    if (amount == null) {
      throw const FormatException('Проверь введённую сумму.');
    }

    return (amount * 100).round();
  }

  Future<void> _showError(Object error) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showMessage(String message) async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LunoraLocalization.text(message)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    String successMessage = 'Изменения сохранены.',
  }) async {
    try {
      await action();
      await _loadData();
      await _showMessage(successMessage);
    } catch (error) {
      await _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 17,
                ),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.65),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.045),
                      blurRadius: 20,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.account_balance_wallet_outlined,
                        color: colors.onPrimaryContainer,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LunoraLocalization.text('МОЁ ПРОСТРАНСТВО'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            LunoraLocalization.text('Мои финансы'),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            LunoraLocalization.text(
                              'Счета, планы, накопления и финансовые решения.',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: LunoraLocalization.text('Импорт из Excel'),
                      onPressed: _importExcel,
                      icon: const Icon(Icons.file_upload_outlined),
                    ),
                    IconButton(
                      tooltip: LunoraLocalization.text('Обновить'),
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.65),
                  ),
                ),
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  labelColor: colors.onPrimaryContainer,
                  unselectedLabelColor: colors.onSurfaceVariant,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: [
                    Tab(
                      text: LunoraLocalization.text('Обзор'),
                      icon: Icon(Icons.dashboard_outlined),
                    ),
                    Tab(
                      text: LunoraLocalization.text('Счета'),
                      icon: Icon(Icons.wallet_outlined),
                    ),
                    Tab(
                      text: LunoraLocalization.text('Операции'),
                      icon: Icon(Icons.receipt_long_outlined),
                    ),
                    Tab(
                      text: LunoraLocalization.text('Кредиты'),
                      icon: Icon(Icons.credit_card_outlined),
                    ),
                    Tab(
                      text: LunoraLocalization.text('Категории'),
                      icon: Icon(Icons.category_outlined),
                    ),
                    Tab(
                      text: LunoraLocalization.text('Бюджеты'),
                      icon: Icon(Icons.account_balance_outlined),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _ErrorView(message: _error!, onRetry: _loadData)
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _buildOverview(),
                        _buildAccounts(),
                        _buildTransactions(),
                        _buildDebts(),
                        _buildCategories(),
                        const FinanceBudgetsPage(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page({
    required Widget child,
    Widget? action,
    bool showDivider = true,
  }) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Stack(
        children: [
          ..._pageBotanicalDecorations(),
          ListView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
            children: [
              if (action != null) ...[
                Align(alignment: Alignment.centerRight, child: action),
                const SizedBox(height: 10),
              ],
              if (showDivider) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Center(
                    child: Opacity(
                      opacity: 0.72,
                      child: SizedBox(
                        width: 210,
                        height: 30,
                        child: SvgPicture.asset(
                          LunoraThemeAssets.divider(
                            SettingsService.instance.settings.colorTheme,
                            compact: true,
                          ),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              child,
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _pageBotanicalDecorations() {
    return [
      Positioned(
        top: 48,
        right: 10,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.105,
            child: SvgPicture.asset(
              LunoraThemeAssets.decoration(
                SettingsService.instance.settings.colorTheme,
              ),
              width: 118,
              height: 174,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 34,
        left: 24,
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.11,
            child: SvgPicture.asset(
              LunoraThemeAssets.extra(
                SettingsService.instance.settings.colorTheme,
              ),
              width: 92,
              height: 126,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _sectionTitle(
    String title, {
    String? subtitle,
    String? dividerAsset,
    double dividerWidth = 220,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 19,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (dividerAsset != null)
            Padding(
              padding: const EdgeInsets.only(left: 10, top: 5, bottom: 3),
              child: Opacity(
                opacity: 0.82,
                child: SvgPicture.asset(
                  dividerAsset,
                  width: dividerWidth,
                  height: 24,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
              ),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.72),
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(15), child: child),
    );
  }

  Widget _buildOverview() {
    return const FinanceAnalyticsOverview();
  }

  IconData _accountIcon(FinanceAccountType type) {
    return switch (type) {
      FinanceAccountType.card => Icons.credit_card,
      FinanceAccountType.bankAccount => Icons.account_balance,
      FinanceAccountType.cash => Icons.payments_outlined,
      FinanceAccountType.other => Icons.wallet_outlined,
    };
  }

  String _accountTypeName(FinanceAccountType type) {
    return switch (type) {
      FinanceAccountType.card => 'Банковская карта',
      FinanceAccountType.bankAccount => 'Банковский счёт',
      FinanceAccountType.cash => 'Наличные',
      FinanceAccountType.other => 'Другое',
    };
  }

  Widget _accountCardContent(FinanceAccount account) {
    return FutureBuilder<int>(
      future: _repository.getAccountBalance(account.id),
      builder: (context, snapshot) {
        return Row(
          children: [
            CircleAvatar(radius: 24, child: Icon(_accountIcon(account.type))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${_accountTypeName(account.type)} · ${account.currency}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (!account.isActive)
                    Text(
                      LunoraLocalization.text('Неактивен'),
                      style: TextStyle(color: Colors.orange),
                    ),
                ],
              ),
            ),
            Text(
              snapshot.hasData ? _money(snapshot.data!, account.currency) : '…',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAccounts() {
    return _page(
      action: FilledButton.icon(
        onPressed: _addAccount,
        icon: const Icon(Icons.add),
        label: Text(LunoraLocalization.text('Добавить счёт')),
      ),
      child: _accounts.isEmpty
          ? const _EmptyView(text: 'Счетов пока нет.')
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 760 ? 2 : 1;
                final gap = 12.0;
                final itemWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: _accounts.map((account) {
                    return SizedBox(
                      width: itemWidth,
                      child: _card(
                        child: Column(
                          children: [
                            _accountCardContent(account),
                            const Divider(height: 20),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 4,
                              children: [
                                TextButton.icon(
                                  onPressed: () => _editAccount(account),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 17,
                                  ),
                                  label: Text(
                                    LunoraLocalization.text('Изменить'),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _deleteAccount(account),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 17,
                                  ),
                                  label: Text(
                                    LunoraLocalization.text('Удалить'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }

  Future<void> _addAccount() async {
    final name = TextEditingController();
    final balance = TextEditingController(text: '0');
    final notes = TextEditingController();

    var type = FinanceAccountType.card;
    var currency = 'RUB';

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LunoraLocalization.text('Новый счёт')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Название'),
                      hintText: LunoraLocalization.text(
                        'Например, Основная карта',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<FinanceAccountType>(
                    initialValue: type,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Тип счёта'),
                    ),
                    items: FinanceAccountType.values.map((value) {
                      return DropdownMenuItem(
                        value: value,
                        child: Text(_accountTypeName(value)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => type = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Валюта'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'RUB',
                        child: Text(LunoraLocalization.text('RUB · Рубль')),
                      ),
                      DropdownMenuItem(
                        value: 'USD',
                        child: Text(LunoraLocalization.text('USD · Доллар')),
                      ),
                      DropdownMenuItem(
                        value: 'EUR',
                        child: Text(LunoraLocalization.text('EUR · Евро')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => currency = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: balance,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Начальный баланс'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notes,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Заметки'),
                    ),
                    maxLines: 2,
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(LunoraLocalization.text('Создать')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _runAction(() async {
        await _repository.createAccount(
          name: name.text,
          type: type,
          currency: currency,
          openingBalanceMinor: _parseMinor(balance.text),
          notes: notes.text,
        );
      });
    }

    name.dispose();
    balance.dispose();
    notes.dispose();
  }

  Future<void> _editAccount(FinanceAccount account) async {
    final name = TextEditingController(text: account.name);
    final notes = TextEditingController(text: account.notes);
    var active = account.isActive;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LunoraLocalization.text('Изменить счёт')),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: LunoraLocalization.text('Название'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  decoration: InputDecoration(
                    labelText: LunoraLocalization.text('Заметки'),
                  ),
                  maxLines: 2,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(LunoraLocalization.text('Активен')),
                  value: active,
                  onChanged: (value) {
                    setDialogState(() => active = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(LunoraLocalization.text('Сохранить')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _runAction(() async {
        await _repository.updateAccount(
          FinanceAccount(
            id: account.id,
            name: name.text.trim(),
            type: account.type,
            currency: account.currency,
            openingBalanceMinor: account.openingBalanceMinor,
            isActive: active,
            sortOrder: account.sortOrder,
            notes: notes.text.trim(),
            createdAt: account.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      });
    }

    name.dispose();
    notes.dispose();
  }

  Future<void> _deleteAccount(FinanceAccount account) async {
    final confirmed = await _confirm(
      'Удалить счёт «${account.name}»?',
      'Если к счёту привязаны операции, база данных не позволит его удалить.',
    );

    if (!confirmed) return;

    await _runAction(
      () => _repository.deleteAccount(account.id),
      successMessage: 'Счёт удалён.',
    );
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(LunoraLocalization.text(message)),
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
        ) ??
        false;
  }

  Widget _buildTransactions() {
    final query = _searchController.text.trim().toLowerCase();

    final from = _dateFrom == null
        ? null
        : DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day);

    final to = _dateTo == null
        ? null
        : DateTime(
            _dateTo!.year,
            _dateTo!.month,
            _dateTo!.day,
            23,
            59,
            59,
            999,
          );

    final filtered = _transactions.where((transaction) {
      if (query.isNotEmpty &&
          !transaction.title.toLowerCase().contains(query) &&
          !transaction.description.toLowerCase().contains(query)) {
        return false;
      }

      if (_typeFilter != null && transaction.type != _typeFilter) {
        return false;
      }

      if (_accountFilter != null &&
          transaction.accountId != _accountFilter &&
          transaction.destinationAccountId != _accountFilter) {
        return false;
      }

      if (_categoryFilter != null &&
          transaction.categoryId != _categoryFilter) {
        return false;
      }

      if (from != null && transaction.transactionDate.isBefore(from)) {
        return false;
      }

      if (to != null && transaction.transactionDate.isAfter(to)) {
        return false;
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      return switch (_sort) {
        _TransactionSort.dateNewest => b.transactionDate.compareTo(
          a.transactionDate,
        ),
        _TransactionSort.dateOldest => a.transactionDate.compareTo(
          b.transactionDate,
        ),
        _TransactionSort.amountHighest => b.amountMinor.compareTo(
          a.amountMinor,
        ),
        _TransactionSort.amountLowest => a.amountMinor.compareTo(b.amountMinor),
      };
    });

    return _page(
      showDivider: false,
      action: FilledButton.icon(
        onPressed: _addTransaction,
        icon: const Icon(Icons.add),
        label: Text(LunoraLocalization.text('Новая операция')),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(LunoraLocalization.text('Поиск и фильтры')),
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration:
                      InputDecoration(
                        labelText: LunoraLocalization.text('Поиск операций'),
                        hintText: LunoraLocalization.text(
                          'Название или описание',
                        ),
                        prefixIcon: Icon(Icons.search),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 11,
                        ),
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: LunoraLocalization.text('Очистить поиск'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(_searchController.clear),
                          icon: const Icon(Icons.close, size: 19),
                        ),
                      ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 620 ? 2 : 1;
                    final gap = 10.0;
                    final fieldWidth =
                        (constraints.maxWidth - gap * (columns - 1)) / columns;

                    Widget filterField(Widget child) =>
                        SizedBox(width: fieldWidth, child: child);

                    return Wrap(
                      spacing: gap,
                      runSpacing: 8,
                      children: [
                        filterField(
                          DropdownButtonFormField<FinanceTransactionType?>(
                            initialValue: _typeFilter,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: LunoraLocalization.text(
                                'Тип операции',
                              ),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(
                                  LunoraLocalization.text('Все типы'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: FinanceTransactionType.income,
                                child: Text(LunoraLocalization.text('Доходы')),
                              ),
                              DropdownMenuItem(
                                value: FinanceTransactionType.expense,
                                child: Text(LunoraLocalization.text('Расходы')),
                              ),
                              DropdownMenuItem(
                                value: FinanceTransactionType.transfer,
                                child: Text(
                                  LunoraLocalization.text('Переводы'),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _typeFilter = value),
                          ),
                        ),
                        filterField(
                          DropdownButtonFormField<String?>(
                            initialValue: _accountFilter,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: LunoraLocalization.text('Счёт'),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(
                                  LunoraLocalization.text('Все счета'),
                                ),
                              ),
                              ..._accounts.map(
                                (account) => DropdownMenuItem(
                                  value: account.id,
                                  child: Text(account.name),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _accountFilter = value),
                          ),
                        ),
                        filterField(
                          DropdownButtonFormField<String?>(
                            initialValue: _categoryFilter,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: LunoraLocalization.text('Категория'),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(
                                  LunoraLocalization.text('Все категории'),
                                ),
                              ),
                              ..._categories.map(
                                (category) => DropdownMenuItem(
                                  value: category.id,
                                  child: Text(category.name),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _categoryFilter = value),
                          ),
                        ),
                        filterField(
                          DropdownButtonFormField<_TransactionSort>(
                            initialValue: _sort,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: LunoraLocalization.text('Сортировка'),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: _TransactionSort.dateNewest,
                                child: Text(
                                  LunoraLocalization.text('Сначала новые'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: _TransactionSort.dateOldest,
                                child: Text(
                                  LunoraLocalization.text('Сначала старые'),
                                ),
                              ),
                              DropdownMenuItem(
                                value: _TransactionSort.amountHighest,
                                child: Text(
                                  LunoraLocalization.text(
                                    'Сначала крупные суммы',
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: _TransactionSort.amountLowest,
                                child: Text(
                                  LunoraLocalization.text(
                                    'Сначала маленькие суммы',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              if (value != null) setState(() => _sort = value);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 7),
                  child: Divider(height: 1),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final half = (constraints.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      children: [
                        SizedBox(
                          width: half,
                          child: _datePickerTile(
                            title: LunoraLocalization.text('Дата с'),
                            date: _dateFrom,
                            onChanged: (value) =>
                                setState(() => _dateFrom = value),
                          ),
                        ),
                        SizedBox(
                          width: half,
                          child: _datePickerTile(
                            title: LunoraLocalization.text('Дата по'),
                            date: _dateTo,
                            onChanged: (value) =>
                                setState(() => _dateTo = value),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _resetTransactionFilters,
                    icon: const Icon(Icons.filter_alt_off, size: 17),
                    label: Text(LunoraLocalization.text('Сбросить фильтры')),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _sectionTitle(
            'Операции',
            subtitle: LunoraLocalization.text('Найдено: ${filtered.length}'),
          ),
          if (filtered.isEmpty)
            const _EmptyView(text: 'Операций по выбранным условиям не найдено.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                Widget transactionCard(FinanceTransaction transaction) {
                  final isIncome =
                      transaction.type == FinanceTransactionType.income;
                  final accent = isIncome
                      ? const Color(0xFF668D69)
                      : const Color(0xFFB96F72);
                  return _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isIncome
                                  ? Icons.south_west_rounded
                                  : Icons.north_east_rounded,
                              size: 17,
                              color: accent,
                            ),
                            const SizedBox(width: 7),
                            Expanded(child: _transactionCard(transaction)),
                          ],
                        ),
                        const Divider(height: 14),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Wrap(
                            spacing: 2,
                            children: [
                              if (transaction.debtId == null)
                                IconButton(
                                  tooltip: LunoraLocalization.text('Изменить'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _editTransaction(transaction),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 17,
                                  ),
                                ),
                              if (transaction.debtId == null)
                                IconButton(
                                  tooltip: LunoraLocalization.text('Удалить'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () =>
                                      _deleteTransaction(transaction),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 17,
                                  ),
                                ),
                              if (transaction.debtId != null)
                                Chip(
                                  avatar: Icon(Icons.lock_outline, size: 15),
                                  label: Text(
                                    LunoraLocalization.text(
                                      'Платёж по кредиту',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final incomes = filtered
                    .where((item) => item.type == FinanceTransactionType.income)
                    .toList();
                final expenses = filtered
                    .where(
                      (item) => item.type == FinanceTransactionType.expense,
                    )
                    .toList();
                final transfers = filtered
                    .where(
                      (item) => item.type == FinanceTransactionType.transfer,
                    )
                    .toList();
                final columns = constraints.maxWidth >= 900 ? 2 : 1;
                final gap = 12.0;
                final width =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;

                Widget transactionColumn(
                  String title,
                  List<FinanceTransaction> items,
                ) {
                  return SizedBox(
                    width: width,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('$title · ${items.length}'),
                        if (items.isEmpty)
                          const _EmptyView(text: 'Пока нет операций.')
                        else
                          ...items.map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(bottom: 9),
                              child: transactionCard(item),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: gap,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        transactionColumn('Доходы', incomes),
                        transactionColumn('Расходы', expenses),
                      ],
                    ),
                    if (transfers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _sectionTitle(LunoraLocalization.text('Переводы · ${transfers.length}')),
                      ...transfers.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: transactionCard(item),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  void _resetTransactionFilters() {
    setState(() {
      _searchController.clear();
      _typeFilter = null;
      _accountFilter = null;
      _categoryFilter = null;
      _dateFrom = null;
      _dateTo = null;
      _sort = _TransactionSort.dateNewest;
    });
  }

  Widget _transactionCard(FinanceTransaction transaction) {
    final account = _account(transaction.accountId);
    final destination = _account(transaction.destinationAccountId);
    final category = _category(transaction.categoryId);

    final isIncome = transaction.type == FinanceTransactionType.income;
    final isTransfer = transaction.type == FinanceTransactionType.transfer;

    final color = isTransfer
        ? Theme.of(context).colorScheme.primary
        : isIncome
        ? Colors.green.shade700
        : Theme.of(context).colorScheme.error;

    final prefix = isTransfer
        ? ''
        : isIncome
        ? '+'
        : '−';

    final details = <String>[
      _date(transaction.transactionDate),
      if (isTransfer)
        '${account?.name ?? 'Счёт'} → ${destination?.name ?? 'Получатель'}'
      else
        account?.name ?? 'Счёт',
      if (!isTransfer && category != null) category.name,
    ];

    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            isTransfer
                ? Icons.swap_horiz
                : isIncome
                ? Icons.arrow_downward
                : Icons.arrow_upward,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                details.join(' · '),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$prefix${_money(transaction.amountMinor, account?.currency ?? 'RUB')}',
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Future<void> _addTransaction() async {
    if (_accounts.where((account) => account.isActive).isEmpty) {
      await _showMessage('Сначала создай активный счёт.');
      return;
    }

    final title = TextEditingController();
    final amount = TextEditingController();
    final description = TextEditingController();

    var type = FinanceTransactionType.expense;
    var accountId = _accounts.firstWhere((a) => a.isActive).id;
    String? destinationId;
    String? categoryId;
    var date = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableCategories = _categories.where((category) {
            return category.isActive &&
                category.type ==
                    (type == FinanceTransactionType.income
                        ? FinanceCategoryType.income
                        : FinanceCategoryType.expense);
          }).toList();

          final activeAccounts = _accounts
              .where((account) => account.isActive)
              .toList();

          return AlertDialog(
            title: Text(LunoraLocalization.text('Новая операция')),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<FinanceTransactionType>(
                      initialValue: type,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Тип операции'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: FinanceTransactionType.income,
                          child: Text(LunoraLocalization.text('Доход')),
                        ),
                        DropdownMenuItem(
                          value: FinanceTransactionType.expense,
                          child: Text(LunoraLocalization.text('Расход')),
                        ),
                        DropdownMenuItem(
                          value: FinanceTransactionType.transfer,
                          child: Text(LunoraLocalization.text('Перевод')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            type = value;
                            categoryId = null;
                            destinationId = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Название'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Сумма'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: accountId,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Счёт'),
                      ),
                      items: activeAccounts.map((account) {
                        return DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            accountId = value;
                            if (destinationId == accountId) {
                              destinationId = null;
                            }
                          });
                        }
                      },
                    ),
                    if (type == FinanceTransactionType.transfer) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: destinationId,
                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Счёт получателя'),
                        ),
                        items: activeAccounts
                            .where((account) => account.id != accountId)
                            .map(
                              (account) => DropdownMenuItem(
                                value: account.id,
                                child: Text(account.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => destinationId = value);
                        },
                      ),
                    ],
                    if (type != FinanceTransactionType.transfer) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: categoryId,
                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Категория'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              LunoraLocalization.text('Без категории'),
                            ),
                          ),
                          ...availableCategories.map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => categoryId = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(LunoraLocalization.text('Дата операции')),
                      subtitle: Text(_date(date)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => date = selected);
                          }
                        },
                      ),
                    ),
                    TextField(
                      controller: description,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Описание'),
                      ),
                      maxLines: 2,
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
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(LunoraLocalization.text('Сохранить')),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      await _runAction(() async {
        await _repository.createTransaction(
          title: title.text,
          type: type,
          amountMinor: _parseMinor(amount.text),
          accountId: accountId,
          destinationAccountId: type == FinanceTransactionType.transfer
              ? destinationId
              : null,
          categoryId: categoryId,
          transactionDate: date,
          description: description.text,
        );
      });
    }

    title.dispose();
    amount.dispose();
    description.dispose();
  }

  Future<void> _editTransaction(FinanceTransaction transaction) async {
    final title = TextEditingController(text: transaction.title);
    final amount = TextEditingController(
      text: (transaction.amountMinor / 100).toStringAsFixed(2),
    );
    final description = TextEditingController(text: transaction.description);

    var type = transaction.type;
    var accountId = transaction.accountId;
    String? destinationId = transaction.destinationAccountId;
    String? categoryId = transaction.categoryId;
    var date = transaction.transactionDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final availableCategories = _categories.where((category) {
            return category.isActive &&
                category.type ==
                    (type == FinanceTransactionType.income
                        ? FinanceCategoryType.income
                        : FinanceCategoryType.expense);
          }).toList();

          final availableAccounts = _accounts.where((account) {
            return account.isActive ||
                account.id == transaction.accountId ||
                account.id == transaction.destinationAccountId;
          }).toList();

          return AlertDialog(
            title: Text(LunoraLocalization.text('Изменить операцию')),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<FinanceTransactionType>(
                      initialValue: type,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Тип операции'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: FinanceTransactionType.income,
                          child: Text(LunoraLocalization.text('Доход')),
                        ),
                        DropdownMenuItem(
                          value: FinanceTransactionType.expense,
                          child: Text(LunoraLocalization.text('Расход')),
                        ),
                        DropdownMenuItem(
                          value: FinanceTransactionType.transfer,
                          child: Text(LunoraLocalization.text('Перевод')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          type = value;
                          categoryId = null;
                          destinationId = null;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Название'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amount,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Сумма'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: accountId,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Счёт'),
                      ),
                      items: availableAccounts.map((account) {
                        return DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            accountId = value;
                            if (destinationId == accountId) {
                              destinationId = null;
                            }
                          });
                        }
                      },
                    ),
                    if (type == FinanceTransactionType.transfer) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: destinationId,
                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Счёт получателя'),
                        ),
                        items: availableAccounts
                            .where((account) => account.id != accountId)
                            .map(
                              (account) => DropdownMenuItem(
                                value: account.id,
                                child: Text(account.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setDialogState(() => destinationId = value);
                        },
                      ),
                    ],
                    if (type != FinanceTransactionType.transfer) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: categoryId,
                        decoration: InputDecoration(
                          labelText: LunoraLocalization.text('Категория'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              LunoraLocalization.text('Без категории'),
                            ),
                          ),
                          ...availableCategories.map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setDialogState(() => categoryId = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(LunoraLocalization.text('Дата операции')),
                      subtitle: Text(_date(date)),
                      trailing: IconButton(
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setDialogState(() => date = selected);
                          }
                        },
                      ),
                    ),
                    TextField(
                      controller: description,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Описание'),
                      ),
                      maxLines: 2,
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
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(LunoraLocalization.text('Сохранить')),
              ),
            ],
          );
        },
      ),
    );

    if (result == true) {
      await _runAction(() async {
        await _repository.updateTransaction(
          FinanceTransaction(
            id: transaction.id,
            title: title.text.trim(),
            type: type,
            amountMinor: _parseMinor(amount.text),
            accountId: accountId,
            destinationAccountId: type == FinanceTransactionType.transfer
                ? destinationId
                : null,
            categoryId: type == FinanceTransactionType.transfer
                ? null
                : categoryId,
            debtId: transaction.debtId,
            transactionDate: date,
            description: description.text.trim(),
            createdAt: transaction.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      });
    }

    title.dispose();
    amount.dispose();
    description.dispose();
  }

  Future<void> _deleteTransaction(FinanceTransaction transaction) async {
    final confirmed = await _confirm(
      'Удалить операцию?',
      'Операция «${transaction.title}» будет удалена.',
    );

    if (!confirmed) return;

    await _runAction(
      () => _repository.deleteTransaction(transaction.id),
      successMessage: 'Операция удалена.',
    );
  }

  Widget _buildDebts() {
    return _page(
      action: FilledButton.icon(
        onPressed: _addDebt,
        icon: const Icon(Icons.add),
        label: Text(LunoraLocalization.text('Добавить задолженность')),
      ),
      child: _debts.isEmpty
          ? const _EmptyView(text: 'Кредитов и рассрочек пока нет.')
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 2 : 1;
                final gap = 12.0;
                final cardWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: _debts.map((debt) {
                    final progress = debt.initialAmountMinor == 0
                        ? 0.0
                        : (1 -
                                  debt.currentBalanceMinor /
                                      debt.initialAmountMinor)
                              .clamp(0.0, 1.0);

                    return SizedBox(
                      width: cardWidth,
                      child: _card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.credit_score_outlined,
                                  size: 19,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    debt.name,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _debtStatus(debt.status),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                            if (debt.creditor.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                debt.creditor,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontSize: 10),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Text(
                              _money(debt.currentBalanceMinor),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              LunoraLocalization.text(
                                'из ${_money(debt.initialAmountMinor)}',
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 10),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 5,
                              children: [
                                Text(
                                  LunoraLocalization.text(
                                    'Ставка: ${debt.interestRate}%',
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                Text(
                                  LunoraLocalization.text(
                                    'Платёж: ${_money(debt.monthlyPaymentMinor)}',
                                  ),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                if (debt.paymentDay != null)
                                  Text(
                                    LunoraLocalization.text(
                                      'День платежа: ${debt.paymentDay}',
                                    ),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                if (debt.nextPaymentDate != null)
                                  Text(
                                    LunoraLocalization.text(
                                      'Следующий: ${_date(debt.nextPaymentDate!)}',
                                    ),
                                    style: const TextStyle(fontSize: 11),
                                  ),
                              ],
                            ),
                            const Divider(height: 16),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                if (debt.status != FinanceDebtStatus.paidOff)
                                  FilledButton.tonalIcon(
                                    onPressed: () => _addDebtPayment(debt),
                                    icon: const Icon(
                                      Icons.payments_outlined,
                                      size: 17,
                                    ),
                                    label: Text(
                                      LunoraLocalization.text('Внести платёж'),
                                    ),
                                  ),
                                TextButton.icon(
                                  onPressed: () => _editDebt(debt),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 17,
                                  ),
                                  label: Text(
                                    LunoraLocalization.text('Изменить'),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _showDebtHistory(debt),
                                  icon: const Icon(Icons.history, size: 17),
                                  label: Text(
                                    LunoraLocalization.text('История'),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => _deleteDebt(debt),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 17,
                                  ),
                                  label: Text(
                                    LunoraLocalization.text('Удалить'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }

  String _debtStatus(FinanceDebtStatus status) {
    return switch (status) {
      FinanceDebtStatus.active => 'Активен',
      FinanceDebtStatus.paidOff => 'Погашен',
      FinanceDebtStatus.paused => 'На паузе',
    };
  }

  Widget _datePickerTile({
    required String title,
    required DateTime? date,
    required ValueChanged<DateTime?> onChanged,
  }) {
    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -3),
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 0,
      title: Text(title, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(date == null ? LunoraLocalization.text('Не указана') : _date(date)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: LunoraLocalization.text('Выбрать дату'),
            icon: const Icon(Icons.calendar_month),
            onPressed: () async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                initialDate: date ?? now,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (selected != null) onChanged(selected);
            },
          ),
          if (date != null)
            IconButton(
              tooltip: LunoraLocalization.text('Очистить дату'),
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            ),
        ],
      ),
    );
  }

  Future<void> _addDebt() async {
    final name = TextEditingController();
    final creditor = TextEditingController();
    final initial = TextEditingController();
    final current = TextEditingController();
    final rate = TextEditingController(text: '0');
    final payment = TextEditingController(text: '0');
    final day = TextEditingController();

    var type = FinanceDebtType.loan;
    DateTime? nextPaymentDate;
    DateTime? startDate;
    DateTime? endDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LunoraLocalization.text('Новая задолженность')),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Название'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<FinanceDebtType>(
                    initialValue: type,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Тип'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: FinanceDebtType.loan,
                        child: Text(LunoraLocalization.text('Кредит')),
                      ),
                      DropdownMenuItem(
                        value: FinanceDebtType.installment,
                        child: Text(LunoraLocalization.text('Рассрочка')),
                      ),
                      DropdownMenuItem(
                        value: FinanceDebtType.other,
                        child: Text(LunoraLocalization.text('Другое')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => type = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: creditor,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Кредитор'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: initial,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text(
                        'Первоначальная сумма',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: current,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text(
                        'Текущий остаток (необязательно)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Ставка, %'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: payment,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Ежемесячный платёж'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: day,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('День платежа (1–31)'),
                    ),
                  ),
                  _datePickerTile(
                    title: LunoraLocalization.text('Следующий платёж'),
                    date: nextPaymentDate,
                    onChanged: (value) {
                      setDialogState(() => nextPaymentDate = value);
                    },
                  ),
                  _datePickerTile(
                    title: LunoraLocalization.text('Дата оформления'),
                    date: startDate,
                    onChanged: (value) {
                      setDialogState(() => startDate = value);
                    },
                  ),
                  _datePickerTile(
                    title: LunoraLocalization.text('Дата окончания'),
                    date: endDate,
                    onChanged: (value) {
                      setDialogState(() => endDate = value);
                    },
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(LunoraLocalization.text('Создать')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _runAction(() async {
        final rateValue = double.tryParse(
          rate.text.trim().replaceAll(',', '.'),
        );

        if (rateValue == null || rateValue < 0) {
          throw const FormatException('Укажи корректную процентную ставку.');
        }

        await _repository.createDebt(
          name: name.text,
          type: type,
          creditor: creditor.text,
          initialAmountMinor: _parseMinor(initial.text),
          currentBalanceMinor: current.text.trim().isEmpty
              ? null
              : _parseMinor(current.text),
          interestRate: rateValue,
          monthlyPaymentMinor: _parseMinor(payment.text),
          paymentDay: day.text.trim().isEmpty
              ? null
              : int.parse(day.text.trim()),
          nextPaymentDate: nextPaymentDate,
          startDate: startDate,
          endDate: endDate,
        );
      });
    }

    for (final controller in [
      name,
      creditor,
      initial,
      current,
      rate,
      payment,
      day,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _editDebt(FinanceDebt debt) async {
    final name = TextEditingController(text: debt.name);
    final creditor = TextEditingController(text: debt.creditor);
    final initial = TextEditingController(
      text: (debt.initialAmountMinor / 100).toStringAsFixed(2),
    );
    final current = TextEditingController(
      text: (debt.currentBalanceMinor / 100).toStringAsFixed(2),
    );
    final rate = TextEditingController(text: debt.interestRate.toString());
    final payment = TextEditingController(
      text: (debt.monthlyPaymentMinor / 100).toStringAsFixed(2),
    );
    final day = TextEditingController(text: debt.paymentDay?.toString() ?? '');
    final notes = TextEditingController(text: debt.notes);

    var type = debt.type;
    var status = debt.status;
    var nextPaymentDate = debt.nextPaymentDate;
    var startDate = debt.startDate;
    var endDate = debt.endDate;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LunoraLocalization.text('Изменить задолженность')),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Название'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<FinanceDebtType>(
                    initialValue: type,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Тип'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: FinanceDebtType.loan,
                        child: Text(LunoraLocalization.text('Кредит')),
                      ),
                      DropdownMenuItem(
                        value: FinanceDebtType.installment,
                        child: Text(LunoraLocalization.text('Рассрочка')),
                      ),
                      DropdownMenuItem(
                        value: FinanceDebtType.other,
                        child: Text(LunoraLocalization.text('Другое')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => type = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: creditor,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Кредитор'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: initial,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text(
                        'Первоначальная сумма',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: current,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Текущий остаток'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rate,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Ставка, %'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: payment,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Ежемесячный платёж'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: day,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('День платежа (1–31)'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<FinanceDebtStatus>(
                    initialValue: status,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Статус'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: FinanceDebtStatus.active,
                        child: Text(LunoraLocalization.text('Активен')),
                      ),
                      DropdownMenuItem(
                        value: FinanceDebtStatus.paused,
                        child: Text(LunoraLocalization.text('На паузе')),
                      ),
                      DropdownMenuItem(
                        value: FinanceDebtStatus.paidOff,
                        child: Text(LunoraLocalization.text('Погашен')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => status = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  _datePickerTile(
                    title: LunoraLocalization.text('Следующий платёж'),
                    date: nextPaymentDate,
                    onChanged: (value) {
                      setDialogState(() => nextPaymentDate = value);
                    },
                  ),
                  _datePickerTile(
                    title: LunoraLocalization.text('Дата оформления'),
                    date: startDate,
                    onChanged: (value) {
                      setDialogState(() => startDate = value);
                    },
                  ),
                  _datePickerTile(
                    title: LunoraLocalization.text('Дата окончания'),
                    date: endDate,
                    onChanged: (value) {
                      setDialogState(() => endDate = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Заметки'),
                    ),
                    maxLines: 3,
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(LunoraLocalization.text('Сохранить')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _runAction(() async {
        final initialMinor = _parseMinor(initial.text);
        final currentMinor = _parseMinor(current.text);
        final paymentMinor = _parseMinor(payment.text);
        final rateValue = double.tryParse(
          rate.text.trim().replaceAll(',', '.'),
        );

        if (rateValue == null || rateValue < 0) {
          throw const FormatException('Укажи корректную процентную ставку.');
        }

        if (initialMinor <= 0 ||
            currentMinor < 0 ||
            currentMinor > initialMinor) {
          throw const FormatException(
            'Проверь первоначальную сумму и текущий остаток.',
          );
        }

        if (paymentMinor < 0) {
          throw const FormatException(
            'Ежемесячный платёж не может быть отрицательным.',
          );
        }

        if (status == FinanceDebtStatus.paidOff && currentMinor != 0) {
          throw const FormatException(
            'У погашенной задолженности остаток должен быть равен нулю.',
          );
        }

        if (currentMinor == 0 && status != FinanceDebtStatus.paidOff) {
          throw const FormatException(
            'При нулевом остатке задолженность должна иметь статус «Погашен».',
          );
        }

        await _repository.updateDebt(
          FinanceDebt(
            id: debt.id,
            name: name.text.trim(),
            type: type,
            creditor: creditor.text.trim(),
            initialAmountMinor: initialMinor,
            currentBalanceMinor: currentMinor,
            interestRate: rateValue,
            monthlyPaymentMinor: paymentMinor,
            paymentDay: day.text.trim().isEmpty
                ? null
                : int.parse(day.text.trim()),
            nextPaymentDate: nextPaymentDate,
            startDate: startDate,
            endDate: endDate,
            status: status,
            notes: notes.text.trim(),
            sortOrder: debt.sortOrder,
            createdAt: debt.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      });
    }

    for (final controller in [
      name,
      creditor,
      initial,
      current,
      rate,
      payment,
      day,
      notes,
    ]) {
      controller.dispose();
    }
  }

  Future<void> _addDebtPayment(FinanceDebt debt) async {
    final activeAccounts = _accounts
        .where((account) => account.isActive)
        .toList();

    if (activeAccounts.isEmpty) {
      await _showMessage('Сначала создай активный счёт.');
      return;
    }

    final principal = TextEditingController();
    final interest = TextEditingController(text: '0');
    final notes = TextEditingController();

    var accountId = activeAccounts.first.id;
    String? categoryId;
    var paidAt = DateTime.now();

    final expenseCategories = _categories.where((category) {
      return category.isActive && category.type == FinanceCategoryType.expense;
    }).toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LunoraLocalization.text('Платёж: ${debt.name}')),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    LunoraLocalization.text(
                      'Остаток долга: ${_money(debt.currentBalanceMinor)}',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: accountId,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Счёт списания'),
                    ),
                    items: activeAccounts.map((account) {
                      return DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => accountId = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: principal,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text(
                        'Погашение основного долга',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: interest,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Проценты'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    initialValue: categoryId,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Категория расходов'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(LunoraLocalization.text('Без категории')),
                      ),
                      ...expenseCategories.map(
                        (category) => DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() => categoryId = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(LunoraLocalization.text('Дата платежа')),
                    subtitle: Text(_date(paidAt)),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_month),
                      onPressed: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: paidAt,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null) {
                          setDialogState(() => paidAt = selected);
                        }
                      },
                    ),
                  ),
                  TextField(
                    controller: notes,
                    decoration: InputDecoration(
                      labelText: LunoraLocalization.text('Заметки'),
                    ),
                    maxLines: 2,
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
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(LunoraLocalization.text('Сохранить платёж')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _runAction(() async {
        await _repository.createDebtPayment(
          debtId: debt.id,
          accountId: accountId,
          principalMinor: _parseMinor(principal.text),
          interestMinor: _parseMinor(interest.text),
          paidAt: paidAt,
          categoryId: categoryId,
          notes: notes.text,
        );
      });
    }

    principal.dispose();
    interest.dispose();
    notes.dispose();
  }

  Future<void> _editDebtPayment(
    FinanceDebt debt,
    FinanceDebtPayment payment,
  ) async {
    FinanceTransaction? linkedTransaction;

    for (final transaction in _transactions) {
      if (transaction.id == payment.transactionId) {
        linkedTransaction = transaction;
        break;
      }
    }

    if (linkedTransaction == null) {
      await _showError(
        Exception('Не найдена связанная операция этого платежа.'),
      );
      return;
    }

    final title = TextEditingController(text: linkedTransaction.title);
    final principal = TextEditingController(
      text: (payment.principalMinor / 100).toStringAsFixed(2),
    );
    final interest = TextEditingController(
      text: (payment.interestMinor / 100).toStringAsFixed(2),
    );
    final notes = TextEditingController(text: payment.notes);

    var accountId = linkedTransaction.accountId;
    String? categoryId = linkedTransaction.categoryId;
    var paidAt = payment.paidAt;

    final availableAccounts = _accounts.where((account) {
      return account.isActive || account.id == accountId;
    }).toList();

    final availableCategories = _categories.where((category) {
      return category.type == FinanceCategoryType.expense &&
          (category.isActive || category.id == categoryId);
    }).toList();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(
              LunoraLocalization.text('Изменить платёж: ${debt.name}'),
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Название операции'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: accountId,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Счёт списания'),
                      ),
                      items: availableAccounts.map((account) {
                        return DropdownMenuItem(
                          value: account.id,
                          child: Text(account.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => accountId = value);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: principal,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text(
                          'Погашение основного долга',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: interest,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Проценты'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: categoryId,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text(
                          'Категория расходов',
                        ),
                      ),
                      items: [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(LunoraLocalization.text('Без категории')),
                        ),
                        ...availableCategories.map(
                          (category) => DropdownMenuItem<String?>(
                            value: category.id,
                            child: Text(category.name),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() => categoryId = value);
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(LunoraLocalization.text('Дата платежа')),
                      subtitle: Text(_date(paidAt)),
                      trailing: IconButton(
                        tooltip: LunoraLocalization.text('Изменить дату'),
                        icon: const Icon(Icons.calendar_month),
                        onPressed: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: paidAt,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );

                          if (selected != null) {
                            setDialogState(() => paidAt = selected);
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notes,
                      decoration: InputDecoration(
                        labelText: LunoraLocalization.text('Заметки'),
                      ),
                      maxLines: 3,
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
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(LunoraLocalization.text('Сохранить')),
              ),
            ],
          ),
        ),
      );

      if (result == true) {
        var saved = false;

        await _runAction(() async {
          final principalMinor = _parseMinor(principal.text);
          final interestMinor = _parseMinor(interest.text);

          if (title.text.trim().isEmpty) {
            throw const FormatException('Укажи название операции.');
          }

          if (principalMinor < 0 || interestMinor < 0) {
            throw const FormatException('Суммы не могут быть отрицательными.');
          }

          if (principalMinor + interestMinor <= 0) {
            throw const FormatException(
              'Сумма платежа должна быть больше нуля.',
            );
          }

          await _repository.updateDebtPayment(
            payment: FinanceDebtPayment(
              id: payment.id,
              debtId: payment.debtId,
              transactionId: payment.transactionId,
              amountMinor: principalMinor + interestMinor,
              principalMinor: principalMinor,
              interestMinor: interestMinor,
              paidAt: paidAt,
              notes: notes.text.trim(),
              createdAt: payment.createdAt,
            ),
            accountId: accountId,
            title: title.text.trim(),
            categoryId: categoryId,
          );

          saved = true;
        }, successMessage: 'Платёж обновлён.');

        if (saved && mounted) {
          await _showDebtHistory(debt);
        }
      }
    } finally {
      title.dispose();
      principal.dispose();
      interest.dispose();
      notes.dispose();
    }
  }

  Future<void> _showDebtHistory(FinanceDebt debt) async {
    try {
      final payments = await _repository.getDebtPayments(debt.id);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(LunoraLocalization.text('История: ${debt.name}')),
          content: SizedBox(
            width: 500,
            child: payments.isEmpty
                ? const _EmptyView(text: 'Платежей пока нет.')
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: payments.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (context, index) {
                      final payment = payments[index];

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _money(payment.amountMinor),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${_date(payment.paidAt)}\n'
                          'Основной долг: '
                          '${_money(payment.principalMinor)}\n'
                          'Проценты: ${_money(payment.interestMinor)}'
                          '${payment.notes.trim().isNotEmpty ? '\n${payment.notes}' : ''}',
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            IconButton(
                              tooltip: LunoraLocalization.text(
                                'Изменить платёж',
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () async {
                                Navigator.pop(dialogContext);

                                await _editDebtPayment(debt, payment);
                              },
                            ),
                            IconButton(
                              tooltip: LunoraLocalization.text(
                                'Удалить платёж',
                              ),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final confirmed = await _confirm(
                                  'Удалить платёж?',
                                  'Остаток задолженности будет восстановлен.',
                                );

                                if (!confirmed) return;

                                await _runAction(
                                  () =>
                                      _repository.deleteDebtPayment(payment.id),
                                  successMessage: 'Платёж удалён.',
                                );

                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext);
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(LunoraLocalization.text('Закрыть')),
            ),
          ],
        ),
      );
    } catch (error) {
      await _showError(error);
    }
  }

  Future<void> _deleteDebt(FinanceDebt debt) async {
    final confirmed = await _confirm(
      'Удалить задолженность?',
      'Удалить «${debt.name}»? Задолженность с историей платежей удалить нельзя.',
    );

    if (!confirmed) return;

    await _runAction(
      () => _repository.deleteDebt(debt.id),
      successMessage: 'Задолженность удалена.',
    );
  }

  Widget _buildCategories() {
    Widget categoryColumn(FinanceCategoryType type) {
      final isIncome = type == FinanceCategoryType.income;
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(isIncome ? LunoraLocalization.text('Доходы') : LunoraLocalization.text('Расходы')),
            ..._categoryList(type),
          ],
        ),
      );
    }

    return _page(
      action: FilledButton.icon(
        onPressed: _addCategory,
        icon: const Icon(Icons.add),
        label: Text(LunoraLocalization.text('Добавить категорию')),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(LunoraLocalization.text('Доходы')),
                ..._categoryList(FinanceCategoryType.income),
                const SizedBox(height: 14),
                _sectionTitle(LunoraLocalization.text('Расходы')),
                ..._categoryList(FinanceCategoryType.expense),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              categoryColumn(FinanceCategoryType.income),
              const SizedBox(width: 16),
              categoryColumn(FinanceCategoryType.expense),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _categoryList(FinanceCategoryType type) {
    final items = _categories.where((category) => category.type == type);

    if (items.isEmpty) {
      return [const _EmptyView(text: 'Категорий пока нет.')];
    }

    return items.map((category) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _card(
          child: Row(
            children: [
              Icon(
                type == FinanceCategoryType.income
                    ? Icons.add_circle_outline
                    : Icons.remove_circle_outline,
                size: 19,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  category.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!category.isActive)
                Text(
                  LunoraLocalization.text('Неактивна'),
                  style: TextStyle(color: Colors.orange, fontSize: 11),
                ),
              IconButton(
                tooltip: LunoraLocalization.text('Удалить'),
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                onPressed: () => _deleteCategory(category),
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Future<void> _addCategory() async {
    final name = TextEditingController();
    var type = FinanceCategoryType.expense;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(LunoraLocalization.text('Новая категория')),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: LunoraLocalization.text('Название'),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FinanceCategoryType>(
                  initialValue: type,
                  decoration: InputDecoration(
                    labelText: LunoraLocalization.text('Тип'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: FinanceCategoryType.income,
                      child: Text(LunoraLocalization.text('Доходы')),
                    ),
                    DropdownMenuItem(
                      value: FinanceCategoryType.expense,
                      child: Text(LunoraLocalization.text('Расходы')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => type = value);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(LunoraLocalization.text('Отмена')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(LunoraLocalization.text('Создать')),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _runAction(() async {
        await _repository.createCategory(name: name.text, type: type);
      });
    }

    name.dispose();
  }

  Future<void> _deleteCategory(FinanceCategory category) async {
    final confirmed = await _confirm(
      'Удалить категорию?',
      'Категория «${category.name}» будет удалена. Операции сохранятся без категории.',
    );

    if (!confirmed) return;

    await _runAction(
      () => _repository.deleteCategory(category.id),
      successMessage: 'Категория удалена.',
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 30,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            LunoraLocalization.text(text),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 38),
            const SizedBox(height: 12),
            Text(
              LunoraLocalization.text('Не удалось загрузить финансы'),
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(LunoraLocalization.text('Повторить')),
            ),
          ],
        ),
      ),
    );
  }
}
