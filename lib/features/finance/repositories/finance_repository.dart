import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import 'package:lunora/core/database/database.dart';
import 'package:lunora/features/finance/services/finance_debt_notification_service.dart';

import '../models/finance_models.dart';
import '../models/finance_budget.dart';
import '../models/finance_savings_goal.dart';

typedef FinanceDatabaseProvider = Future<Database> Function();

class FinanceRepository {
  FinanceRepository._({FinanceDatabaseProvider? databaseProvider})
    : _databaseProvider =
          databaseProvider ?? (() => LunoraDatabase.instance.database);

  static final FinanceRepository instance = FinanceRepository._();

  factory FinanceRepository.forTesting(
    FinanceDatabaseProvider databaseProvider,
  ) {
    return FinanceRepository._(databaseProvider: databaseProvider);
  }

  final FinanceDatabaseProvider _databaseProvider;

  static const Uuid _uuid = Uuid();

  Future<Database> get _db => _databaseProvider();

  String get _now => DateTime.now().toIso8601String();

  Future<void> _syncDebtNotification(String debtId) async {
    final debt = await getDebtById(debtId);

    if (debt == null) {
      await FinanceDebtNotificationService.instance.cancelDebtNotification(
        debtId,
      );
      return;
    }

    await FinanceDebtNotificationService.instance.syncDebt(debt);
  }

  // ==================================================
  // ОБЩИЕ ПРОВЕРКИ
  // ==================================================

  void _validateName(String name) {
    if (name.trim().isEmpty) {
      throw ArgumentError('Название не может быть пустым.');
    }
  }

  void _validateAmount(int amount) {
    if (amount <= 0) {
      throw ArgumentError('Сумма должна быть больше нуля.');
    }
  }

  void _validateNonNegative(int amount, String field) {
    if (amount < 0) {
      throw ArgumentError('$field не может быть отрицательным.');
    }
  }

  void _validateRate(double rate) {
    if (!rate.isFinite || rate < 0) {
      throw ArgumentError(
        'Процентная ставка должна быть конечным неотрицательным числом.',
      );
    }
  }

  void _validatePaymentDay(int? day) {
    if (day != null && (day < 1 || day > 31)) {
      throw ArgumentError('День платежа должен быть от 1 до 31.');
    }
  }

  void _validatePeriod({required int year, required int month}) {
    if (year < 2000) {
      throw ArgumentError('Год должен быть не меньше 2000.');
    }

    if (month < 1 || month > 12) {
      throw ArgumentError('Месяц должен быть от 1 до 12.');
    }
  }

  void _validateDebtDates({
    DateTime? startDate,
    DateTime? nextPaymentDate,
    DateTime? endDate,
  }) {
    if (startDate != null && endDate != null && endDate.isBefore(startDate)) {
      throw ArgumentError('Дата окончания не может быть раньше даты начала.');
    }

    if (startDate != null &&
        nextPaymentDate != null &&
        nextPaymentDate.isBefore(startDate)) {
      throw ArgumentError(
        'Дата следующего платежа не может быть раньше даты начала.',
      );
    }
  }

  void _validateDebtBalance({
    required int initialAmountMinor,
    required int currentBalanceMinor,
    required FinanceDebtStatus status,
  }) {
    _validateAmount(initialAmountMinor);
    _validateNonNegative(currentBalanceMinor, 'Остаток задолженности');

    if (currentBalanceMinor > initialAmountMinor) {
      throw ArgumentError('Остаток не может превышать первоначальную сумму.');
    }

    if (currentBalanceMinor == 0 && status != FinanceDebtStatus.paidOff) {
      throw ArgumentError(
        'При нулевом остатке задолженность должна иметь статус «Погашен».',
      );
    }

    if (currentBalanceMinor > 0 && status == FinanceDebtStatus.paidOff) {
      throw ArgumentError(
        'Нельзя отметить задолженность погашенной при ненулевом остатке.',
      );
    }
  }

  Future<FinanceAccount> _requireAccount(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'finance_accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Финансовый счёт не найден.');
    }

    return FinanceAccount.fromMap(rows.first);
  }

  Future<FinanceCategory> _requireCategory(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.query(
      'finance_categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Категория не найдена.');
    }

    return FinanceCategory.fromMap(rows.first);
  }

  Future<void> _validateCategory({
    required DatabaseExecutor db,
    required String? categoryId,
    required FinanceCategoryType expectedType,
  }) async {
    if (categoryId == null) return;

    final category = await _requireCategory(db, categoryId);

    if (!category.isActive) {
      throw StateError('Выбранная категория неактивна.');
    }

    if (category.type != expectedType) {
      throw ArgumentError('Тип категории не соответствует типу операции.');
    }
  }

  Future<void> _validateBudgetCategory({
    required DatabaseExecutor db,
    required String categoryId,
  }) async {
    final category = await _requireCategory(db, categoryId);

    if (!category.isActive) {
      throw StateError('Выбранная категория неактивна.');
    }

    if (category.type != FinanceCategoryType.expense) {
      throw ArgumentError(
        'Бюджет можно создать только для категории расходов.',
      );
    }
  }

  Future<void> _validateCategoryParent({
    required DatabaseExecutor db,
    required String categoryId,
    required FinanceCategoryType type,
    required String? parentId,
  }) async {
    if (parentId == null) return;

    if (parentId == categoryId) {
      throw ArgumentError('Категория не может быть родителем самой себе.');
    }

    final visited = <String>{categoryId};
    String? currentId = parentId;

    while (currentId != null) {
      if (!visited.add(currentId)) {
        throw ArgumentError('Обнаружена циклическая вложенность категорий.');
      }

      final parent = await _requireCategory(db, currentId);

      if (!parent.isActive) {
        throw StateError(
          'Нельзя использовать неактивную родительскую категорию.',
        );
      }

      if (parent.type != type) {
        throw ArgumentError('Тип родительской категории не совпадает.');
      }

      currentId = parent.parentId;
    }
  }

  // ==================================================
  // СЧЕТА
  // ==================================================

  Future<FinanceAccount> createAccount({
    required String name,
    required FinanceAccountType type,
    String currency = 'RUB',
    int openingBalanceMinor = 0,
    String notes = '',
    int sortOrder = 0,
  }) async {
    _validateName(name);

    if (currency.trim().isEmpty) {
      throw ArgumentError('Укажи валюту счёта.');
    }

    final now = DateTime.now();

    final account = FinanceAccount(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      currency: currency.trim().toUpperCase(),
      openingBalanceMinor: openingBalanceMinor,
      notes: notes.trim(),
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db;

    await db.insert('finance_accounts', account.toMap());

    return account;
  }

  Future<List<FinanceAccount>> getAccounts({bool activeOnly = false}) async {
    final db = await _db;

    final rows = await db.query(
      'finance_accounts',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );

    return rows.map(FinanceAccount.fromMap).toList();
  }

  Future<FinanceAccount?> getAccountById(String id) async {
    final db = await _db;

    final rows = await db.query(
      'finance_accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return FinanceAccount.fromMap(rows.first);
  }

  Future<void> updateAccount(FinanceAccount account) async {
    _validateName(account.name);

    if (account.currency.trim().isEmpty) {
      throw ArgumentError('Укажи валюту счёта.');
    }

    final db = await _db;
    final existing = await _requireAccount(db, account.id);

    final newCurrency = account.currency.trim().toUpperCase();

    if (existing.currency.toUpperCase() != newCurrency) {
      final transactionRows = await db.query(
        'finance_transactions',
        columns: ['id'],
        where: 'account_id = ? OR destination_account_id = ?',
        whereArgs: [account.id, account.id],
        limit: 1,
      );

      if (transactionRows.isNotEmpty) {
        throw StateError(
          'Нельзя менять валюту счёта, по которому уже есть операции.',
        );
      }
    }

    final map = account.toMap();

    map['currency'] = newCurrency;
    map['updated_at'] = _now;

    final count = await db.update(
      'finance_accounts',
      map,
      where: 'id = ?',
      whereArgs: [account.id],
    );

    if (count == 0) {
      throw StateError('Счёт для изменения не найден.');
    }
  }

  Future<void> deleteAccount(String id) async {
    final db = await _db;

    await db.delete('finance_accounts', where: 'id = ?', whereArgs: [id]);
  }

  // ==================================================
  // БАЛАНСЫ СЧЕТОВ
  // ==================================================

  Future<int> getAccountBalance(String accountId) async {
    final db = await _db;
    final account = await _requireAccount(db, accountId);

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(
          CASE
            WHEN transaction_type = 'income'
              AND account_id = ?
            THEN amount_minor ELSE 0
          END
        ), 0) AS income,

        COALESCE(SUM(
          CASE
            WHEN transaction_type = 'expense'
              AND account_id = ?
            THEN amount_minor ELSE 0
          END
        ), 0) AS expense,

        COALESCE(SUM(
          CASE
            WHEN transaction_type = 'transfer'
              AND account_id = ?
            THEN amount_minor ELSE 0
          END
        ), 0) AS transfer_out,

        COALESCE(SUM(
          CASE
            WHEN transaction_type = 'transfer'
              AND destination_account_id = ?
            THEN amount_minor ELSE 0
          END
        ), 0) AS transfer_in

      FROM finance_transactions
      WHERE account_id = ?
         OR destination_account_id = ?
    ''',
      [accountId, accountId, accountId, accountId, accountId, accountId],
    );

    final row = result.first;

    final income = row['income'] as int? ?? 0;
    final expense = row['expense'] as int? ?? 0;
    final transferOut = row['transfer_out'] as int? ?? 0;
    final transferIn = row['transfer_in'] as int? ?? 0;

    return account.openingBalanceMinor +
        income -
        expense -
        transferOut +
        transferIn;
  }

  // ==================================================
  // КАТЕГОРИИ
  // ==================================================

  Future<FinanceCategory> createCategory({
    required String name,
    required FinanceCategoryType type,
    String? parentId,
    int sortOrder = 0,
  }) async {
    _validateName(name);

    final db = await _db;

    if (parentId != null) {
      final parent = await _requireCategory(db, parentId);

      if (!parent.isActive) {
        throw StateError(
          'Нельзя использовать неактивную родительскую категорию.',
        );
      }

      if (parent.type != type) {
        throw ArgumentError('Родительская категория должна иметь тот же тип.');
      }
    }

    final now = DateTime.now();

    final category = FinanceCategory(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      parentId: parentId,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('finance_categories', category.toMap());

    return category;
  }

  Future<List<FinanceCategory>> getCategories({
    FinanceCategoryType? type,
    bool activeOnly = false,
  }) async {
    final db = await _db;

    final conditions = <String>[];
    final args = <Object?>[];

    if (type != null) {
      conditions.add('category_type = ?');
      args.add(type.name);
    }

    if (activeOnly) {
      conditions.add('is_active = 1');
    }

    final rows = await db.query(
      'finance_categories',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'sort_order ASC, name COLLATE NOCASE ASC',
    );

    return rows.map(FinanceCategory.fromMap).toList();
  }

  Future<FinanceCategory?> getCategoryById(String id) async {
    final db = await _db;

    final rows = await db.query(
      'finance_categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return FinanceCategory.fromMap(rows.first);
  }

  Future<void> updateCategory(FinanceCategory category) async {
    _validateName(category.name);

    final db = await _db;

    final existing = await getCategoryById(category.id);

    if (existing == null) {
      throw StateError('Категория для изменения не найдена.');
    }

    await _validateCategoryParent(
      db: db,
      categoryId: category.id,
      type: category.type,
      parentId: category.parentId,
    );

    if (existing.type != category.type) {
      final childRows = await db.query(
        'finance_categories',
        columns: ['id'],
        where: 'parent_id = ?',
        whereArgs: [category.id],
        limit: 1,
      );

      if (childRows.isNotEmpty) {
        throw StateError(
          'Нельзя менять тип категории, у которой есть подкатегории.',
        );
      }

      final transactionRows = await db.query(
        'finance_transactions',
        columns: ['id'],
        where: 'category_id = ?',
        whereArgs: [category.id],
        limit: 1,
      );

      if (transactionRows.isNotEmpty) {
        throw StateError(
          'Нельзя менять тип категории, которая используется в операциях.',
        );
      }

      final budgetRows = await db.query(
        'finance_budgets',
        columns: ['id'],
        where: 'category_id = ?',
        whereArgs: [category.id],
        limit: 1,
      );

      if (budgetRows.isNotEmpty) {
        throw StateError(
          'Нельзя менять тип категории, для которой созданы бюджеты.',
        );
      }
    }

    final map = category.toMap();
    map['updated_at'] = _now;

    final count = await db.update(
      'finance_categories',
      map,
      where: 'id = ?',
      whereArgs: [category.id],
    );

    if (count == 0) {
      throw StateError('Категория для изменения не найдена.');
    }
  }

  Future<void> deleteCategory(String id) async {
    final db = await _db;

    await db.delete('finance_categories', where: 'id = ?', whereArgs: [id]);
  }

  // ==================================================
  // ДОХОДЫ, РАСХОДЫ И ПЕРЕВОДЫ
  // ==================================================

  Future<FinanceTransaction> createTransaction({
    required String title,
    required FinanceTransactionType type,
    required int amountMinor,
    required String accountId,
    String? destinationAccountId,
    String? categoryId,
    required DateTime transactionDate,
    String description = '',
  }) async {
    _validateName(title);
    _validateAmount(amountMinor);

    final db = await _db;
    final account = await _requireAccount(db, accountId);

    if (!account.isActive) {
      throw StateError('Выбранный счёт неактивен.');
    }

    if (type == FinanceTransactionType.transfer) {
      if (destinationAccountId == null) {
        throw ArgumentError('Для перевода нужен счёт получателя.');
      }

      if (destinationAccountId == accountId) {
        throw ArgumentError('Нельзя переводить деньги на тот же счёт.');
      }

      final destination = await _requireAccount(db, destinationAccountId);

      if (!destination.isActive) {
        throw StateError('Счёт получателя неактивен.');
      }

      if (destination.currency != account.currency) {
        throw ArgumentError(
          'Перевод между разными валютами пока не поддерживается.',
        );
      }

      if (categoryId != null) {
        throw ArgumentError(
          'Переводу нельзя назначить категорию доходов или расходов.',
        );
      }
    } else {
      if (destinationAccountId != null) {
        throw ArgumentError('Получатель указывается только для переводов.');
      }

      await _validateCategory(
        db: db,
        categoryId: categoryId,
        expectedType: type == FinanceTransactionType.income
            ? FinanceCategoryType.income
            : FinanceCategoryType.expense,
      );
    }

    final now = DateTime.now();

    final transaction = FinanceTransaction(
      id: _uuid.v4(),
      title: title.trim(),
      type: type,
      amountMinor: amountMinor,
      accountId: accountId,
      destinationAccountId: destinationAccountId,
      categoryId: categoryId,
      transactionDate: transactionDate,
      description: description.trim(),
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('finance_transactions', transaction.toMap());

    return transaction;
  }

  Future<List<FinanceTransaction>> getTransactions({
    FinanceTransactionType? type,
    String? accountId,
    String? categoryId,
    DateTime? from,
    DateTime? to,
    String? searchQuery,
    int? limit,
  }) async {
    final db = await _db;

    final conditions = <String>[];
    final args = <Object?>[];

    if (type != null) {
      conditions.add('transaction_type = ?');
      args.add(type.name);
    }

    if (accountId != null) {
      conditions.add('(account_id = ? OR destination_account_id = ?)');
      args.addAll([accountId, accountId]);
    }

    if (categoryId != null) {
      conditions.add('category_id = ?');
      args.add(categoryId);
    }

    if (from != null) {
      conditions.add('transaction_date >= ?');
      args.add(from.toIso8601String());
    }

    if (to != null) {
      conditions.add('transaction_date <= ?');
      args.add(to.toIso8601String());
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(title LIKE ? OR description LIKE ?)');

      final query = '%${searchQuery.trim()}%';
      args.addAll([query, query]);
    }

    final rows = await db.query(
      'finance_transactions',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'transaction_date DESC, created_at DESC',
      limit: limit,
    );

    return rows.map(FinanceTransaction.fromMap).toList();
  }

  Future<FinanceTransaction?> getTransactionById(String id) async {
    final db = await _db;

    final rows = await db.query(
      'finance_transactions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return FinanceTransaction.fromMap(rows.first);
  }

  Future<void> updateTransaction(FinanceTransaction transaction) async {
    _validateName(transaction.title);
    _validateAmount(transaction.amountMinor);

    if (transaction.debtId != null) {
      throw StateError(
        'Операцию, связанную с задолженностью, нельзя редактировать напрямую.',
      );
    }

    final db = await _db;
    final existing = await getTransactionById(transaction.id);

    if (existing == null) {
      throw StateError('Операция для изменения не найдена.');
    }

    if (existing.debtId != null) {
      throw StateError(
        'Платёж по кредиту нельзя редактировать как обычную операцию.',
      );
    }

    final account = await _requireAccount(db, transaction.accountId);

    if (!account.isActive) {
      throw StateError('Выбранный счёт неактивен.');
    }

    if (transaction.type == FinanceTransactionType.transfer) {
      final destinationId = transaction.destinationAccountId;

      if (destinationId == null || destinationId == transaction.accountId) {
        throw ArgumentError('Некорректный счёт получателя.');
      }

      final destination = await _requireAccount(db, destinationId);

      if (!destination.isActive) {
        throw StateError('Счёт получателя неактивен.');
      }

      if (account.currency != destination.currency) {
        throw ArgumentError('Валюты счетов должны совпадать.');
      }

      if (transaction.categoryId != null) {
        throw ArgumentError('У перевода не может быть категории.');
      }
    } else {
      if (transaction.destinationAccountId != null) {
        throw ArgumentError(
          'У обычной операции не должно быть счёта получателя.',
        );
      }

      await _validateCategory(
        db: db,
        categoryId: transaction.categoryId,
        expectedType: transaction.type == FinanceTransactionType.income
            ? FinanceCategoryType.income
            : FinanceCategoryType.expense,
      );
    }

    final map = transaction.toMap();
    map['updated_at'] = _now;

    await db.update(
      'finance_transactions',
      map,
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _db;
    final transaction = await getTransactionById(id);

    if (transaction == null) return;

    if (transaction.debtId != null) {
      throw StateError(
        'Платёж по кредиту нужно удалять через deleteDebtPayment.',
      );
    }

    await db.delete('finance_transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ==================================================
  // КРЕДИТЫ И РАССРОЧКИ
  // ==================================================

  Future<FinanceDebt> createDebt({
    required String name,
    required FinanceDebtType type,
    String creditor = '',
    required int initialAmountMinor,
    int? currentBalanceMinor,
    double interestRate = 0,
    int monthlyPaymentMinor = 0,
    int? paymentDay,
    DateTime? nextPaymentDate,
    DateTime? startDate,
    DateTime? endDate,
    String notes = '',
    int sortOrder = 0,
  }) async {
    _validateName(name);
    _validateAmount(initialAmountMinor);
    _validateNonNegative(monthlyPaymentMinor, 'Ежемесячный платёж');
    _validateRate(interestRate);
    _validatePaymentDay(paymentDay);
    _validateDebtDates(
      startDate: startDate,
      nextPaymentDate: nextPaymentDate,
      endDate: endDate,
    );

    final balance = currentBalanceMinor ?? initialAmountMinor;

    if (balance < 0 || balance > initialAmountMinor) {
      throw ArgumentError('Некорректный остаток задолженности.');
    }

    final now = DateTime.now();

    final debt = FinanceDebt(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      creditor: creditor.trim(),
      initialAmountMinor: initialAmountMinor,
      currentBalanceMinor: balance,
      interestRate: interestRate,
      monthlyPaymentMinor: monthlyPaymentMinor,
      paymentDay: paymentDay,
      nextPaymentDate: nextPaymentDate,
      startDate: startDate,
      endDate: endDate,
      status: balance == 0
          ? FinanceDebtStatus.paidOff
          : FinanceDebtStatus.active,
      notes: notes.trim(),
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db;

    await db.insert('finance_debts', debt.toMap());

    await FinanceDebtNotificationService.instance.syncDebt(debt);

    return debt;
  }

  Future<List<FinanceDebt>> getDebts({
    FinanceDebtStatus? status,
    FinanceDebtType? type,
  }) async {
    final db = await _db;

    final conditions = <String>[];
    final args = <Object?>[];

    if (status != null) {
      conditions.add('status = ?');
      args.add(status.name);
    }

    if (type != null) {
      conditions.add('debt_type = ?');
      args.add(type.name);
    }

    final rows = await db.query(
      'finance_debts',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'sort_order ASC, created_at DESC',
    );

    return rows.map(FinanceDebt.fromMap).toList();
  }

  Future<FinanceDebt?> getDebtById(String id) async {
    final db = await _db;

    final rows = await db.query(
      'finance_debts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return FinanceDebt.fromMap(rows.first);
  }

  Future<void> updateDebt(FinanceDebt debt) async {
    _validateName(debt.name);
    _validateNonNegative(debt.monthlyPaymentMinor, 'Ежемесячный платёж');
    _validateRate(debt.interestRate);
    _validatePaymentDay(debt.paymentDay);
    _validateDebtDates(
      startDate: debt.startDate,
      nextPaymentDate: debt.nextPaymentDate,
      endDate: debt.endDate,
    );
    _validateDebtBalance(
      initialAmountMinor: debt.initialAmountMinor,
      currentBalanceMinor: debt.currentBalanceMinor,
      status: debt.status,
    );

    final db = await _db;

    final existing = await getDebtById(debt.id);

    if (existing == null) {
      throw StateError('Задолженность для изменения не найдена.');
    }

    final paymentRows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(principal_minor), 0) AS total
      FROM finance_debt_payments
      WHERE debt_id = ?
      ''',
      [debt.id],
    );

    final paidPrincipal = paymentRows.first['total'] as int? ?? 0;

    final balanceAfterRecordedPayments =
        debt.initialAmountMinor - paidPrincipal;

    if (balanceAfterRecordedPayments < 0) {
      throw StateError(
        'Первоначальная сумма не может быть меньше уже зарегистрированных погашений основного долга.',
      );
    }

    if (debt.currentBalanceMinor > balanceAfterRecordedPayments) {
      throw StateError(
        'Остаток задолженности не может превышать первоначальную сумму за вычетом зарегистрированных погашений основного долга.',
      );
    }

    final map = debt.toMap();
    map['updated_at'] = _now;

    final count = await db.update(
      'finance_debts',
      map,
      where: 'id = ?',
      whereArgs: [debt.id],
    );

    if (count == 0) {
      throw StateError('Задолженность для изменения не найдена.');
    }

    await FinanceDebtNotificationService.instance.syncDebt(debt);
  }

  Future<void> deleteDebt(String id) async {
    final db = await _db;

    final paymentCount = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM finance_debt_payments
      WHERE debt_id = ?
      ''',
      [id],
    );

    final count = paymentCount.first['total'] as int? ?? 0;

    if (count > 0) {
      throw StateError('Нельзя удалить задолженность с историей платежей.');
    }

    await db.delete('finance_debts', where: 'id = ?', whereArgs: [id]);

    await FinanceDebtNotificationService.instance.cancelDebtNotification(id);
  }

  // ==================================================
  // ПЛАТЕЖИ ПО КРЕДИТАМ
  // ==================================================

  Future<FinanceDebtPayment> createDebtPayment({
    required String debtId,
    required String accountId,
    required int principalMinor,
    required int interestMinor,
    required DateTime paidAt,
    String title = 'Платёж по кредиту',
    String? categoryId,
    String notes = '',
  }) async {
    _validateName(title);
    _validateNonNegative(principalMinor, 'Основной долг');
    _validateNonNegative(interestMinor, 'Проценты');

    final amountMinor = principalMinor + interestMinor;
    _validateAmount(amountMinor);

    final db = await _db;

    final payment = await db.transaction((txn) async {
      final debtRows = await txn.query(
        'finance_debts',
        where: 'id = ?',
        whereArgs: [debtId],
        limit: 1,
      );

      if (debtRows.isEmpty) {
        throw StateError('Задолженность не найдена.');
      }

      final debt = FinanceDebt.fromMap(debtRows.first);

      if (debt.status == FinanceDebtStatus.paidOff) {
        throw StateError(
          'Нельзя добавить платёж по уже погашенной задолженности.',
        );
      }

      if (debt.status == FinanceDebtStatus.paused) {
        throw StateError(
          'Нельзя добавить платёж по приостановленной задолженности.',
        );
      }

      final accountRows = await txn.query(
        'finance_accounts',
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );

      if (accountRows.isEmpty) {
        throw StateError('Счёт не найден.');
      }

      final account = FinanceAccount.fromMap(accountRows.first);

      if (!account.isActive) {
        throw StateError('Счёт неактивен.');
      }

      if (principalMinor > debt.currentBalanceMinor) {
        throw ArgumentError(
          'Погашение основного долга превышает остаток задолженности.',
        );
      }

      await _validateCategory(
        db: txn,
        categoryId: categoryId,
        expectedType: FinanceCategoryType.expense,
      );

      final now = DateTime.now();
      final transactionId = _uuid.v4();
      final paymentId = _uuid.v4();

      final transaction = FinanceTransaction(
        id: transactionId,
        title: title.trim(),
        type: FinanceTransactionType.expense,
        amountMinor: amountMinor,
        accountId: accountId,
        categoryId: categoryId,
        debtId: debtId,
        transactionDate: paidAt,
        description: notes.trim(),
        createdAt: now,
        updatedAt: now,
      );

      await txn.insert('finance_transactions', transaction.toMap());

      final payment = FinanceDebtPayment(
        id: paymentId,
        debtId: debtId,
        transactionId: transactionId,
        amountMinor: amountMinor,
        principalMinor: principalMinor,
        interestMinor: interestMinor,
        paidAt: paidAt,
        notes: notes.trim(),
        createdAt: now,
      );

      await txn.insert('finance_debt_payments', payment.toMap());

      final newBalance = debt.currentBalanceMinor - principalMinor;

      await txn.update(
        'finance_debts',
        {
          'current_balance_minor': newBalance,
          'status': newBalance == 0
              ? FinanceDebtStatus.paidOff.name
              : debt.status.name,
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [debtId],
      );

      return payment;
    });

    await _syncDebtNotification(debtId);

    return payment;
  }

  Future<List<FinanceDebtPayment>> getDebtPayments(String debtId) async {
    final db = await _db;

    final rows = await db.query(
      'finance_debt_payments',
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'paid_at DESC, created_at DESC',
    );

    return rows.map(FinanceDebtPayment.fromMap).toList();
  }

  Future<FinanceDebtPayment?> getDebtPaymentById(String id) async {
    final db = await _db;

    final rows = await db.query(
      'finance_debt_payments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return FinanceDebtPayment.fromMap(rows.first);
  }

  Future<void> updateDebtPayment({
    required FinanceDebtPayment payment,
    required String accountId,
    required String title,
    String? categoryId,
  }) async {
    _validateName(title);

    _validateNonNegative(payment.principalMinor, 'Основной долг');

    _validateNonNegative(payment.interestMinor, 'Проценты');

    final amountMinor = payment.principalMinor + payment.interestMinor;

    _validateAmount(amountMinor);

    final db = await _db;

    await db.transaction((txn) async {
      final paymentRows = await txn.query(
        'finance_debt_payments',
        where: 'id = ?',
        whereArgs: [payment.id],
        limit: 1,
      );

      if (paymentRows.isEmpty) {
        throw StateError('Платёж не найден.');
      }

      final existingPayment = FinanceDebtPayment.fromMap(paymentRows.first);

      if (existingPayment.debtId != payment.debtId ||
          existingPayment.transactionId != payment.transactionId) {
        throw StateError(
          'Нельзя менять принадлежность платежа к задолженности.',
        );
      }

      final debtRows = await txn.query(
        'finance_debts',
        where: 'id = ?',
        whereArgs: [existingPayment.debtId],
        limit: 1,
      );

      if (debtRows.isEmpty) {
        throw StateError('Задолженность не найдена.');
      }

      final debt = FinanceDebt.fromMap(debtRows.first);

      final transactionRows = await txn.query(
        'finance_transactions',
        where: 'id = ?',
        whereArgs: [existingPayment.transactionId],
        limit: 1,
      );

      if (transactionRows.isEmpty) {
        throw StateError('Связанная финансовая операция не найдена.');
      }

      final linkedTransaction = FinanceTransaction.fromMap(
        transactionRows.first,
      );

      if (linkedTransaction.type != FinanceTransactionType.expense ||
          linkedTransaction.debtId != existingPayment.debtId) {
        throw StateError(
          'Связанная операция не соответствует платежу по задолженности.',
        );
      }

      final accountRows = await txn.query(
        'finance_accounts',
        where: 'id = ?',
        whereArgs: [accountId],
        limit: 1,
      );

      if (accountRows.isEmpty) {
        throw StateError('Счёт не найден.');
      }

      final account = FinanceAccount.fromMap(accountRows.first);

      if (!account.isActive) {
        throw StateError('Выбранный счёт неактивен.');
      }

      await _validateCategory(
        db: txn,
        categoryId: categoryId,
        expectedType: FinanceCategoryType.expense,
      );

      final newBalance =
          debt.currentBalanceMinor +
          existingPayment.principalMinor -
          payment.principalMinor;

      if (newBalance < 0 || newBalance > debt.initialAmountMinor) {
        throw ArgumentError(
          'После изменения платежа получится некорректный остаток задолженности.',
        );
      }

      final now = _now;

      await txn.update(
        'finance_transactions',
        {
          'title': title.trim(),
          'amount_minor': amountMinor,
          'account_id': accountId,
          'category_id': categoryId,
          'transaction_date': payment.paidAt.toIso8601String(),
          'description': payment.notes.trim(),
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existingPayment.transactionId],
      );

      await txn.update(
        'finance_debt_payments',
        {
          'amount_minor': amountMinor,
          'principal_minor': payment.principalMinor,
          'interest_minor': payment.interestMinor,
          'paid_at': payment.paidAt.toIso8601String(),
          'notes': payment.notes.trim(),
        },
        where: 'id = ?',
        whereArgs: [payment.id],
      );

      await txn.update(
        'finance_debts',
        {
          'current_balance_minor': newBalance,
          'status': newBalance == 0
              ? FinanceDebtStatus.paidOff.name
              : debt.status == FinanceDebtStatus.paidOff
              ? FinanceDebtStatus.active.name
              : debt.status.name,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [debt.id],
      );
    });

    await _syncDebtNotification(payment.debtId);
  }

  Future<void> deleteDebtPayment(String paymentId) async {
    final db = await _db;

    String? affectedDebtId;

    await db.transaction((txn) async {
      // 1. Находим платёж.
      final rows = await txn.query(
        'finance_debt_payments',
        where: 'id = ?',
        whereArgs: [paymentId],
        limit: 1,
      );

      if (rows.isEmpty) return;

      final payment = FinanceDebtPayment.fromMap(rows.first);
      affectedDebtId = payment.debtId;

      // 2. Находим задолженность.
      final debtRows = await txn.query(
        'finance_debts',
        where: 'id = ?',
        whereArgs: [payment.debtId],
        limit: 1,
      );

      if (debtRows.isEmpty) {
        throw StateError(
          'Задолженность для восстановления платежа не найдена.',
        );
      }

      final debt = FinanceDebt.fromMap(debtRows.first);

      // 3. Проверяем связанную финансовую операцию.
      final transactionRows = await txn.query(
        'finance_transactions',
        where: 'id = ?',
        whereArgs: [payment.transactionId],
        limit: 1,
      );

      if (transactionRows.isEmpty) {
        throw StateError('Связанная финансовая операция не найдена.');
      }

      final linkedTransaction = FinanceTransaction.fromMap(
        transactionRows.first,
      );

      if (linkedTransaction.type != FinanceTransactionType.expense ||
          linkedTransaction.debtId != payment.debtId) {
        throw StateError(
          'Связанная операция не соответствует платежу по задолженности.',
        );
      }

      // 4. Восстанавливаем основной долг.
      final restoredBalance = debt.currentBalanceMinor + payment.principalMinor;

      if (restoredBalance > debt.initialAmountMinor) {
        throw StateError(
          'Восстановленный остаток превышает первоначальную сумму задолженности.',
        );
      }

      // 5. Обновляем задолженность.
      await txn.update(
        'finance_debts',
        {
          'current_balance_minor': restoredBalance,
          'status': restoredBalance == 0
              ? FinanceDebtStatus.paidOff.name
              : debt.status == FinanceDebtStatus.paidOff
              ? FinanceDebtStatus.active.name
              : debt.status.name,
          'updated_at': _now,
        },
        where: 'id = ?',
        whereArgs: [payment.debtId],
      );

      // 6. Удаляем сам платёж из истории.
      await txn.delete(
        'finance_debt_payments',
        where: 'id = ?',
        whereArgs: [paymentId],
      );

      // 7. Удаляем связанную финансовую операцию.
      await txn.delete(
        'finance_transactions',
        where: 'id = ?',
        whereArgs: [payment.transactionId],
      );
    });

    if (affectedDebtId != null) {
      await _syncDebtNotification(affectedDebtId!);
    }
  }

  // ==================================================
  // БЮДЖЕТЫ
  // ==================================================

  Future<FinanceBudget> createBudget({
    required String categoryId,
    required int year,
    required int month,
    required int limitMinor,
  }) async {
    _validatePeriod(year: year, month: month);
    _validateAmount(limitMinor);

    final db = await _db;

    await _validateBudgetCategory(db: db, categoryId: categoryId);

    final now = DateTime.now();

    final budget = FinanceBudget(
      id: _uuid.v4(),
      categoryId: categoryId,
      year: year,
      month: month,
      limitMinor: limitMinor,
      createdAt: now,
      updatedAt: now,
    );

    await db.insert('finance_budgets', budget.toMap());

    return budget;
  }

  Future<List<FinanceBudget>> getBudgets({
    required int year,
    required int month,
  }) async {
    _validatePeriod(year: year, month: month);

    final db = await _db;

    final rows = await db.query(
      'finance_budgets',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
      orderBy: 'created_at ASC',
    );

    return rows.map(FinanceBudget.fromMap).toList();
  }

  Future<FinanceBudget?> getBudgetById(String id) async {
    final db = await _db;

    final rows = await db.query(
      'finance_budgets',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return FinanceBudget.fromMap(rows.first);
  }

  Future<FinanceBudget?> getBudgetForCategory({
    required String categoryId,
    required int year,
    required int month,
  }) async {
    _validatePeriod(year: year, month: month);

    final db = await _db;

    final rows = await db.query(
      'finance_budgets',
      where: 'category_id = ? AND year = ? AND month = ?',
      whereArgs: [categoryId, year, month],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return FinanceBudget.fromMap(rows.first);
  }

  Future<void> updateBudget(FinanceBudget budget) async {
    _validatePeriod(year: budget.year, month: budget.month);
    _validateAmount(budget.limitMinor);

    final db = await _db;

    await _validateBudgetCategory(db: db, categoryId: budget.categoryId);

    final map = budget.toMap();
    map['updated_at'] = _now;

    final count = await db.update(
      'finance_budgets',
      map,
      where: 'id = ?',
      whereArgs: [budget.id],
    );

    if (count == 0) {
      throw StateError('Бюджет для изменения не найден.');
    }
  }

  Future<void> deleteBudget(String id) async {
    final db = await _db;

    await db.delete('finance_budgets', where: 'id = ?', whereArgs: [id]);
  }

  /// Возвращает фактические расходы по категории за указанный месяц.
  ///
  /// Учитываются только операции типа expense.
  /// Доходы и переводы не включаются.
  Future<int> getBudgetSpending({
    required String categoryId,
    required int year,
    required int month,
  }) async {
    _validatePeriod(year: year, month: month);

    final db = await _db;

    final period = '$year-${month.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_minor), 0) AS total
      FROM finance_transactions
      WHERE transaction_type = 'expense'
        AND category_id = ?
        AND substr(transaction_date, 1, 7) = ?
      ''',
      [categoryId, period],
    );

    return result.first['total'] as int? ?? 0;
  }

  /// Возвращает сумму расходов по всем бюджетным категориям месяца.
  Future<Map<String, int>> getBudgetSpendingForMonth({
    required int year,
    required int month,
  }) async {
    _validatePeriod(year: year, month: month);

    final db = await _db;

    final period = '$year-${month.toString().padLeft(2, '0')}';

    final rows = await db.rawQuery(
      '''
      SELECT
        category_id,
        COALESCE(SUM(amount_minor), 0) AS total
      FROM finance_transactions
      WHERE transaction_type = 'expense'
        AND category_id IS NOT NULL
        AND substr(transaction_date, 1, 7) = ?
      GROUP BY category_id
      ''',
      [period],
    );

    return {
      for (final row in rows)
        row['category_id'] as String: row['total'] as int? ?? 0,
    };
  }

  /// Возвращает показатели одного бюджета:
  /// limit, spent, remaining и percent.
  ///
  /// percent ограничивается сверху значением 100.
  /// При превышении лимита remaining становится отрицательным.
  Future<Map<String, int>> getBudgetProgress(FinanceBudget budget) async {
    final spent = await getBudgetSpending(
      categoryId: budget.categoryId,
      year: budget.year,
      month: budget.month,
    );

    final remaining = budget.limitMinor - spent;

    final rawPercent = budget.limitMinor > 0
        ? (spent * 100 / budget.limitMinor).round()
        : 0;

    final percent = rawPercent.clamp(0, 100);

    return {
      'limit': budget.limitMinor,
      'spent': spent,
      'remaining': remaining,
      'percent': percent,
      'is_exceeded': spent > budget.limitMinor ? 1 : 0,
    };
  }

  /// Возвращает бюджеты месяца вместе с расходами и остатками.
  ///
  /// Ключи каждой записи:
  /// budget, spent, remaining, percent, is_exceeded.
  Future<List<Map<String, Object>>> getBudgetsWithProgress({
    required int year,
    required int month,
  }) async {
    final budgets = await getBudgets(year: year, month: month);

    final spending = await getBudgetSpendingForMonth(year: year, month: month);

    final result = <Map<String, Object>>[];

    for (final budget in budgets) {
      final spent = spending[budget.categoryId] ?? 0;
      final remaining = budget.limitMinor - spent;

      final rawPercent = budget.limitMinor > 0
          ? (spent * 100 / budget.limitMinor).round()
          : 0;

      result.add({
        'budget': budget,
        'spent': spent,
        'remaining': remaining,
        'percent': rawPercent.clamp(0, 100),
        'is_exceeded': spent > budget.limitMinor,
      });
    }

    return result;
  }

  // ==================================================
  // НАКОПЛЕНИЯ
  // ==================================================

  Future<FinanceSavingsGoal> createSavingsGoal({
    required String title,
    required int targetAmountMinor,
    int savedAmountMinor = 0,
    String currency = 'RUB',
    DateTime? targetDate,
    String status = 'active',
    int sortOrder = 0,
  }) async {
    _validateName(title);
    _validateAmount(targetAmountMinor);
    _validateNonNegative(savedAmountMinor, 'Накопленная сумма');

    if (currency.trim().isEmpty) {
      throw ArgumentError('Укажи валюту накопления.');
    }

    final now = DateTime.now();

    final goal = FinanceSavingsGoal(
      id: _uuid.v4(),
      title: title.trim(),
      targetAmountMinor: targetAmountMinor,
      savedAmountMinor: savedAmountMinor,
      currency: currency.trim().toUpperCase(),
      targetDate: targetDate,
      status: status,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );

    final db = await _db;

    await db.insert('finance_savings_goals', goal.toMap());

    return goal;
  }

  Future<List<FinanceSavingsGoal>> getSavingsGoals({String? status}) async {
    final db = await _db;

    final rows = await db.query(
      'finance_savings_goals',
      where: status == null ? null : 'status = ?',
      whereArgs: status == null ? null : [status],
      orderBy: 'sort_order ASC, created_at DESC',
    );

    return rows.map(FinanceSavingsGoal.fromMap).toList();
  }

  Future<FinanceSavingsGoal?> getSavingsGoalById(String id) async {
    final db = await _db;

    final rows = await db.query(
      'finance_savings_goals',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    return FinanceSavingsGoal.fromMap(rows.first);
  }

  Future<void> updateSavingsGoal(FinanceSavingsGoal goal) async {
    _validateName(goal.title);
    _validateAmount(goal.targetAmountMinor);
    _validateNonNegative(goal.savedAmountMinor, 'Накопленная сумма');

    if (goal.currency.trim().isEmpty) {
      throw ArgumentError('Укажи валюту накопления.');
    }

    final db = await _db;

    final map = goal.toMap();
    map['currency'] = goal.currency.trim().toUpperCase();
    map['updated_at'] = _now;

    final count = await db.update(
      'finance_savings_goals',
      map,
      where: 'id = ?',
      whereArgs: [goal.id],
    );

    if (count == 0) {
      throw StateError('Цель накопления не найдена.');
    }
  }

  Future<void> deleteSavingsGoal(String id) async {
    final db = await _db;

    await db.delete('finance_savings_goals', where: 'id = ?', whereArgs: [id]);
  }

  // ==================================================
  // СТАТИСТИКА
  // ==================================================

  Future<Map<String, int>> getMonthlySummary({
    required int year,
    required int month,
  }) async {
    _validatePeriod(year: year, month: month);

    final db = await _db;

    final period = '$year-${month.toString().padLeft(2, '0')}';

    final result = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(
          CASE
            WHEN transaction_type = 'income'
            THEN amount_minor ELSE 0
          END
        ), 0) AS income,

        COALESCE(SUM(
          CASE
            WHEN transaction_type = 'expense'
            THEN amount_minor ELSE 0
          END
        ), 0) AS expense

      FROM finance_transactions
      WHERE substr(transaction_date, 1, 7) = ?
      ''',
      [period],
    );

    final row = result.first;

    final income = row['income'] as int? ?? 0;
    final expense = row['expense'] as int? ?? 0;

    return {'income': income, 'expense': expense, 'balance': income - expense};
  }
}
