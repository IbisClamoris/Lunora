import 'package:lunora/core/settings/settings_service.dart';
import 'package:lunora/core/theme/lunora_theme_assets.dart';
import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

import 'package:lunora/features/finance/models/finance_models.dart';
import 'package:lunora/features/finance/repositories/finance_repository.dart';

class FinanceAnalyticsOverview extends StatefulWidget {
  const FinanceAnalyticsOverview({super.key});

  @override
  State<FinanceAnalyticsOverview> createState() =>
      _FinanceAnalyticsOverviewState();
}

class _FinanceAnalyticsOverviewState extends State<FinanceAnalyticsOverview> {
  final FinanceRepository _repository = FinanceRepository.instance;

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  bool _loading = true;
  String? _error;

  int _loadRequestId = 0;

  List<FinanceAccount> _accounts = [];
  List<FinanceCategory> _categories = [];
  List<FinanceDebt> _debts = [];

  List<FinanceTransaction> _selectedTransactions = [];
  List<List<FinanceTransaction>> _historyTransactions = [];

  Map<String, int> _accountBalances = {};

  static const double _pagePadding = 16;
  static const double _cardPadding = 14;
  static const double _sectionSpacing = 18;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final requestId = ++_loadRequestId;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final firstMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month - 5,
      );

      final months = List.generate(
        6,
        (index) => DateTime(firstMonth.year, firstMonth.month + index),
      );

      final selectedStart = DateTime(
        _selectedMonth.year,
        _selectedMonth.month,
        1,
      );

      final selectedEnd = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        0,
        23,
        59,
        59,
      );

      final results = await Future.wait<dynamic>([
        _repository.getAccounts(),
        _repository.getCategories(),
        _repository.getDebts(),
        _repository.getTransactions(from: selectedStart, to: selectedEnd),
        ...months.map(
          (month) => _repository.getTransactions(
            from: month,
            to: DateTime(month.year, month.month + 1, 0, 23, 59, 59),
          ),
        ),
      ]);

      final loadedAccounts = results[0] as List<FinanceAccount>;

      final balanceResults = await Future.wait(
        loadedAccounts.map(
          (account) => _repository.getAccountBalance(account.id),
        ),
      );

      final loadedBalances = <String, int>{};

      for (var i = 0; i < loadedAccounts.length; i++) {
        loadedBalances[loadedAccounts[i].id] = balanceResults[i];
      }

      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _accounts = loadedAccounts;
        _categories = results[1] as List<FinanceCategory>;
        _debts = results[2] as List<FinanceDebt>;

        _selectedTransactions = results[3] as List<FinanceTransaction>;

        _historyTransactions = results
            .skip(4)
            .map((item) => item as List<FinanceTransaction>)
            .toList();

        _accountBalances = loadedBalances;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String _currencySymbol(String currency) {
    return switch (currency) {
      'RUB' => '₽',
      'USD' => r'$',
      'EUR' => '€',
      _ => currency,
    };
  }

  String _money(int minor, String currency) {
    final amount = (minor.abs() / 100).toStringAsFixed(2);
    final parts = amount.split('.');
    final whole = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ' ',
    );

    final sign = minor < 0 ? '−' : '';

    return '$sign$whole,${parts[1]} ${_currencySymbol(currency)}';
  }

  String _date(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  String _monthName(DateTime date) {
    final locale = LunoraLocalization.isEnglish ? 'en_US' : 'ru_RU';
    return DateFormat('MMMM yyyy', locale).format(date);
  }

  FinanceAccount? _account(String? id) {
    if (id == null) return null;

    for (final account in _accounts) {
      if (account.id == id) return account;
    }

    return null;
  }

  FinanceCategory? _category(String? id) {
    if (id == null) return null;

    for (final category in _categories) {
      if (category.id == id) return category;
    }

    return null;
  }

  String _transactionCurrency(FinanceTransaction transaction) {
    return _account(transaction.accountId)?.currency ?? 'RUB';
  }

  Map<String, int> _totalsForType(
    List<FinanceTransaction> transactions,
    FinanceTransactionType type,
  ) {
    final result = <String, int>{};

    for (final transaction in transactions) {
      if (transaction.type != type) continue;

      final currency = _transactionCurrency(transaction);

      result[currency] = (result[currency] ?? 0) + transaction.amountMinor;
    }

    return result;
  }

  Map<String, int> _expensesByCategory(String currency) {
    final result = <String, int>{};

    for (final transaction in _selectedTransactions) {
      if (transaction.type != FinanceTransactionType.expense) {
        continue;
      }

      if (_transactionCurrency(transaction) != currency) continue;

      final category = _category(transaction.categoryId);
      final name = category?.name ?? 'Без категории';

      result[name] = (result[name] ?? 0) + transaction.amountMinor;
    }

    return result;
  }

  Map<String, Map<String, int>> _historyByCurrency() {
    final result = <String, Map<String, int>>{};

    for (final transactions in _historyTransactions) {
      for (final transaction in transactions) {
        if (transaction.type != FinanceTransactionType.income &&
            transaction.type != FinanceTransactionType.expense) {
          continue;
        }

        final currency = _transactionCurrency(transaction);

        final currencyData = result.putIfAbsent(
          currency,
          () => {'income': 0, 'expense': 0},
        );

        final key = transaction.type == FinanceTransactionType.income
            ? 'income'
            : 'expense';

        currencyData[key] = (currencyData[key] ?? 0) + transaction.amountMinor;
      }
    }

    return result;
  }

  int get _activeDebtTotal {
    return _debts
        .where((debt) => debt.status == FinanceDebtStatus.active)
        .fold<int>(0, (sum, debt) => sum + debt.currentBalanceMinor);
  }

  int get _monthlyDebtPayments {
    return _debts
        .where((debt) => debt.status == FinanceDebtStatus.active)
        .fold<int>(0, (sum, debt) => sum + debt.monthlyPaymentMinor);
  }

  List<FinanceDebt> get _upcomingDebts {
    final now = DateTime.now();

    return _debts
        .where(
          (debt) =>
              debt.status == FinanceDebtStatus.active &&
              debt.nextPaymentDate != null,
        )
        .where(
          (debt) => !debt.nextPaymentDate!.isBefore(
            DateTime(now.year, now.month, now.day),
          ),
        )
        .toList()
      ..sort((a, b) => a.nextPaymentDate!.compareTo(b.nextPaymentDate!));
  }

  void _changeMonth(int offset) {
    final now = DateTime.now();
    final next = DateTime(_selectedMonth.year, _selectedMonth.month + offset);

    if (next.isAfter(DateTime(now.year, now.month))) return;

    setState(() {
      _selectedMonth = next;
    });

    _loadAnalytics();
  }

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(_cardPadding),
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LunoraLocalization.text(title),
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 12),
            child: Opacity(
              opacity: 0.82,
              child: SvgPicture.asset(
                LunoraThemeAssets.divider(
                  SettingsService.instance.settings.colorTheme,
                ),
                width: double.infinity,
                height: 26,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              LunoraLocalization.text(subtitle),
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

  Widget _metricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return _card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 7),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        children: [
          IconButton(
            tooltip: LunoraLocalization.text('Предыдущий месяц'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _changeMonth(-1),
            icon: const Icon(Icons.chevron_left, size: 21),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _monthName(_selectedMonth),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Text(
                  LunoraLocalization.text('Финансовая сводка'),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: LunoraLocalization.text('Следующий месяц'),
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => _changeMonth(1),
            icon: const Icon(Icons.chevron_right, size: 21),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlySummary() {
    final incomes = _totalsForType(
      _selectedTransactions,
      FinanceTransactionType.income,
    );

    final expenses = _totalsForType(
      _selectedTransactions,
      FinanceTransactionType.expense,
    );

    final currencies = <String>{...incomes.keys, ...expenses.keys}.toList()
      ..sort();

    if (currencies.isEmpty) {
      return const _AnalyticsEmpty(
        text: 'За этот месяц пока нет доходов и расходов.',
      );
    }

    return Column(
      children: currencies.map((currency) {
        final income = incomes[currency] ?? 0;
        final expense = expenses[currency] ?? 0;
        final difference = income - expense;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      currency,
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    LunoraLocalization.text(
                      'Итого: ${_money(difference, currency)}',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: difference >= 0
                          ? Colors.green.shade700
                          : Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _metricCard(
                      title: LunoraLocalization.text('Доходы'),
                      value: _money(income, currency),
                      icon: Icons.trending_up,
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricCard(
                      title: LunoraLocalization.text('Расходы'),
                      value: _money(expense, currency),
                      icon: Icons.trending_down,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCategoryBreakdown() {
    final currencies =
        _selectedTransactions
            .where(
              (transaction) =>
                  transaction.type == FinanceTransactionType.expense,
            )
            .map(_transactionCurrency)
            .toSet()
            .toList()
          ..sort();

    if (currencies.isEmpty) {
      return const _AnalyticsEmpty(
        text: 'Расходов за выбранный месяц пока нет.',
      );
    }

    return Column(
      children: currencies.map((currency) {
        final categories = _expensesByCategory(currency);
        final sorted = categories.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        final total = sorted.fold<int>(0, (sum, entry) => sum + entry.value);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currency,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ...sorted.map((entry) {
                final fraction = total == 0 ? 0.0 : entry.value / total;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Text(
                            _money(entry.value, currency),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 7,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${(fraction * 100).toStringAsFixed(1)}%',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      LunoraLocalization.text('Всего расходов'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _money(total, currency),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHistoryChart() {
    final history = _historyByCurrency();

    if (history.isEmpty) {
      return const _AnalyticsEmpty(
        text: 'Для графика пока недостаточно операций.',
      );
    }

    final currencies = history.keys.toList()..sort();

    final firstMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 5);

    return Column(
      children: currencies.map((currency) {
        var maxValue = 0;

        for (final transactions in _historyTransactions) {
          var income = 0;
          var expense = 0;

          for (final transaction in transactions) {
            if (_transactionCurrency(transaction) != currency) {
              continue;
            }

            if (transaction.type == FinanceTransactionType.income) {
              income += transaction.amountMinor;
            } else if (transaction.type == FinanceTransactionType.expense) {
              expense += transaction.amountMinor;
            }
          }

          if (income > maxValue) maxValue = income;
          if (expense > maxValue) maxValue = expense;
        }

        final scale = maxValue == 0 ? 1 : maxValue;

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currency,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 9),
              ...List.generate(6, (index) {
                final month = DateTime(
                  firstMonth.year,
                  firstMonth.month + index,
                );

                final transactions = _historyTransactions[index];

                var income = 0;
                var expense = 0;

                for (final transaction in transactions) {
                  if (_transactionCurrency(transaction) != currency) {
                    continue;
                  }

                  if (transaction.type == FinanceTransactionType.income) {
                    income += transaction.amountMinor;
                  } else if (transaction.type ==
                      FinanceTransactionType.expense) {
                    expense += transaction.amountMinor;
                  }
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _monthName(month),
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(fontSize: 10),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: income / scale,
                                minHeight: 7,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          SizedBox(
                            width: 105,
                            child: Text(
                              '+${_money(income, currency)}',
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: expense / scale,
                                minHeight: 7,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          SizedBox(
                            width: 105,
                            child: Text(
                              '−${_money(expense, currency)}',
                              textAlign: TextAlign.end,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAccountBalances() {
    final activeAccounts = _accounts
        .where((account) => account.isActive)
        .toList();

    if (activeAccounts.isEmpty) {
      return const _AnalyticsEmpty(
        text: 'Добавь счёт, чтобы видеть здесь баланс.',
      );
    }

    final grouped = <String, List<FinanceAccount>>{};

    for (final account in activeAccounts) {
      grouped.putIfAbsent(account.currency, () => []).add(account);
    }

    final currencies = grouped.keys.toList()..sort();

    return Column(
      children: currencies.map((currency) {
        final accounts = grouped[currency]!;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currency,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              ...accounts.map((account) {
                final balance = _balanceForAccount(account);

                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -2,
                  ),
                  contentPadding: EdgeInsets.zero,
                  minLeadingWidth: 34,
                  horizontalTitleGap: 9,
                  leading: CircleAvatar(
                    radius: 17,
                    child: Icon(_accountIcon(account.type), size: 17),
                  ),
                  title: Text(
                    account.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    _accountTypeName(account.type),
                    style: const TextStyle(fontSize: 10),
                  ),
                  trailing: Text(
                    _money(balance, currency),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }),
              const Divider(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      LunoraLocalization.text('Итого'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _money(
                      accounts.fold<int>(
                        0,
                        (sum, account) => sum + _balanceForAccount(account),
                      ),
                      currency,
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  int _balanceForAccount(FinanceAccount account) {
    return _accountBalances[account.id] ?? account.openingBalanceMinor;
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
      FinanceAccountType.other => 'Другой счёт',
    };
  }

  Widget _buildDebtSummary() {
    final activeDebts = _debts
        .where((debt) => debt.status == FinanceDebtStatus.active)
        .toList();

    final upcoming = _upcomingDebts.take(5).toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricCard(
                title: LunoraLocalization.text('Остаток долга'),
                value: _money(_activeDebtTotal, 'RUB'),
                icon: Icons.credit_score_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricCard(
                title: LunoraLocalization.text('Платежи в месяц'),
                value: _money(_monthlyDebtPayments, 'RUB'),
                icon: Icons.calendar_month_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (activeDebts.isEmpty)
          const _AnalyticsEmpty(text: 'Активных задолженностей нет.')
        else if (upcoming.isEmpty)
          const _AnalyticsEmpty(text: 'Ближайшие даты платежей не указаны.')
        else
          _card(
            child: Column(
              children: upcoming.map((debt) {
                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(
                    horizontal: 0,
                    vertical: -2,
                  ),
                  contentPadding: EdgeInsets.zero,
                  minLeadingWidth: 34,
                  horizontalTitleGap: 9,
                  leading: const CircleAvatar(
                    radius: 17,
                    child: Icon(Icons.event_note_outlined, size: 17),
                  ),
                  title: Text(
                    debt.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    LunoraLocalization.text(
                      'Платёж ${_date(debt.nextPaymentDate!)}',
                    ),
                    style: const TextStyle(fontSize: 10),
                  ),
                  trailing: Text(
                    _money(debt.monthlyPaymentMinor, 'RUB'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _twoColumnSections({
    required double width,
    required String leftTitle,
    String? leftSubtitle,
    required Widget leftChild,
    required String rightTitle,
    String? rightSubtitle,
    required Widget rightChild,
  }) {
    Widget section(String title, String? subtitle, Widget child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, subtitle: subtitle),
          _card(child: child),
        ],
      );
    }

    if (width < 1050) {
      return Column(
        children: [
          section(leftTitle, leftSubtitle, leftChild),
          const SizedBox(height: _sectionSpacing),
          section(rightTitle, rightSubtitle, rightChild),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: section(leftTitle, leftSubtitle, leftChild)),
        const SizedBox(width: 16),
        Expanded(child: section(rightTitle, rightSubtitle, rightChild)),
      ],
    );
  }

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1050;
          return ListView(
            padding: const EdgeInsets.all(_pagePadding),
            children: [
              _buildMonthSelector(),
              const SizedBox(height: _sectionSpacing),
              _sectionTitle('Финансовый результат'),
              _buildMonthlySummary(),
              const SizedBox(height: _sectionSpacing),
              _twoColumnSections(
                width: constraints.maxWidth,
                leftTitle: 'Расходы по категориям',
                leftSubtitle: 'Распределение расходов за выбранный месяц',
                leftChild: _buildCategoryBreakdown(),
                rightTitle: 'Динамика за 6 месяцев',
                rightSubtitle: 'Зелёный — доходы, красный — расходы',
                rightChild: _buildHistoryChart(),
              ),
              SizedBox(height: wide ? _sectionSpacing : 0),
              if (wide)
                _twoColumnSections(
                  width: constraints.maxWidth,
                  leftTitle: 'Баланс счетов',
                  leftChild: _buildAccountBalances(),
                  rightTitle: 'Кредиты и рассрочки',
                  rightChild: _buildDebtSummary(),
                )
              else ...[
                _sectionTitle('Баланс счетов'),
                _card(child: _buildAccountBalances()),
                const SizedBox(height: _sectionSpacing),
                _sectionTitle('Кредиты и рассрочки'),
                _buildDebtSummary(),
              ],
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 30),
              const SizedBox(height: 8),
              Text(
                LunoraLocalization.text('Не удалось загрузить аналитику'),
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _loadAnalytics,
                icon: const Icon(Icons.refresh, size: 17),
                label: Text(LunoraLocalization.text('Повторить')),
              ),
            ],
          ),
        ),
      );
    }

    return _buildContent();
  }
}

class _AnalyticsEmpty extends StatelessWidget {
  const _AnalyticsEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        LunoraLocalization.text(text),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
      ),
    );
  }
}
