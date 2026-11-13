import 'package:uuid/uuid.dart';

import 'package:lunora/core/database/database.dart';
import 'package:lunora/core/import_export/models/spreadsheet_document.dart';

class FinanceExcelImportResult {
  final int accounts;
  final int categories;
  final int transactions;
  final int debts;
  final int budgets;
  final int savingsGoals;
  final int skippedTransactions;

  const FinanceExcelImportResult({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.debts,
    required this.budgets,
    required this.savingsGoals,
    required this.skippedTransactions,
  });
}

class FinanceExcelImportService {
  FinanceExcelImportService._();

  static final FinanceExcelImportService instance =
      FinanceExcelImportService._();

  static const Uuid _uuid = Uuid();

  Future<FinanceExcelImportResult> importWorkbook(
    SpreadsheetDocument document, {
    DateTime? budgetPeriod,
  }) async {
    final sheets = {
      for (final sheet in document.sheets) _normalize(sheet.name): sheet,
    };

    final accountsSheet = sheets['счета'];
    final transactionsSheet = sheets['операции'];
    final debtsSheet = sheets['кредиты'];
    final budgetsSheet = sheets['бюджет'];
    final savingsSheet = sheets['накопления'];

    if (accountsSheet == null && transactionsSheet == null) {
      throw Exception('В книге не найдены листы «Счета» или «Операции».');
    }

    final budgetRows = budgetsSheet == null
        ? <Map<String, Object?>>[]
        : _readRows(budgetsSheet);

    if (budgetRows.isNotEmpty && budgetPeriod == null) {
      throw Exception('Для импорта бюджета необходимо указать месяц и год.');
    }

    final accountRows = accountsSheet == null
        ? <Map<String, Object?>>[]
        : _readRows(accountsSheet);

    final transactionRows = transactionsSheet == null
        ? <Map<String, Object?>>[]
        : _readRows(transactionsSheet);

    final debtRows = debtsSheet == null
        ? <Map<String, Object?>>[]
        : _readRows(debtsSheet);

    final savingsRows = savingsSheet == null
        ? <Map<String, Object?>>[]
        : _readRows(savingsSheet);

    final db = await LunoraDatabase.instance.database;

    var importedAccounts = 0;
    var importedCategories = 0;
    var importedTransactions = 0;
    var importedDebts = 0;
    var importedBudgets = 0;
    var importedSavings = 0;
    var skippedTransactions = 0;

    await db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();

      // 1. Счета

      final accountMap = <String, String>{};

      final existingAccounts = await txn.query('finance_accounts');

      for (final account in existingAccounts) {
        final key = _accountKey(
          account['name']?.toString() ?? '',
          account['currency']?.toString() ?? 'RUB',
        );

        accountMap[key] = account['id'] as String;
      }

      for (final row in accountRows) {
        final name = _string(row, ['Название счёта', 'Название счета']);

        if (name.isEmpty) continue;

        final currency = _currency(_string(row, ['Валюта']));

        final key = _accountKey(name, currency);

        if (accountMap.containsKey(key)) continue;

        final id = _uuid.v4();

        await txn.insert('finance_accounts', {
          'id': id,
          'name': name,
          'account_type': _accountType(_string(row, ['Тип'])),
          'currency': currency,
          'opening_balance_minor': _amount(_value(row, ['Начальный баланс'])),
          'is_active': _boolean(_value(row, ['Активен']), defaultValue: true)
              ? 1
              : 0,
          'sort_order': importedAccounts,
          'notes': '',
          'created_at': now,
          'updated_at': now,
        });

        accountMap[key] = id;
        importedAccounts++;
      }

      // 2. Категории и операции

      final categoryMap = <String, String>{};

      final existingCategories = await txn.query('finance_categories');

      for (final category in existingCategories) {
        final key = _categoryKey(
          category['name']?.toString() ?? '',
          category['category_type']?.toString() ?? '',
        );

        categoryMap[key] = category['id'] as String;
      }

      final transactionSignatures = <String>{};

      final existingTransactions = await txn.query('finance_transactions');

      for (final transaction in existingTransactions) {
        transactionSignatures.add(
          _transactionSignature(
            date: transaction['transaction_date']?.toString() ?? '',
            type: transaction['transaction_type']?.toString() ?? '',
            accountId: transaction['account_id']?.toString() ?? '',
            destinationId:
                transaction['destination_account_id']?.toString() ?? '',
            categoryId: transaction['category_id']?.toString() ?? '',
            amount: (transaction['amount_minor'] as num?)?.toInt() ?? 0,
            description: transaction['description']?.toString() ?? '',
          ),
        );
      }

      for (final row in transactionRows) {
        final type = _transactionType(_string(row, ['Тип']));

        final accountName = _string(row, ['Счёт', 'Счет']);
        final destinationName = _string(row, [
          'Счёт назначения',
          'Счет назначения',
        ]);

        final accountId =
            accountMap[_accountKey(
              accountName,
              _findCurrency(accountName, accountMap),
            )];

        if (accountId == null) {
          throw Exception('Не найден счёт «$accountName» в операциях.');
        }

        String? destinationId;

        if (type == 'transfer') {
          destinationId =
              accountMap[_accountKey(
                destinationName,
                _findCurrency(destinationName, accountMap),
              )];

          if (destinationId == null) {
            throw Exception('Не найден счёт назначения «$destinationName».');
          }
        }

        final categoryName = _string(row, ['Категория']);
        String? categoryId;

        if (categoryName.isNotEmpty && type != 'transfer') {
          final categoryType = type == 'income' ? 'income' : 'expense';

          final key = _categoryKey(categoryName, categoryType);

          categoryId = categoryMap[key];

          if (categoryId == null) {
            categoryId = _uuid.v4();

            await txn.insert('finance_categories', {
              'id': categoryId,
              'name': categoryName,
              'category_type': categoryType,
              'parent_id': null,
              'is_active': 1,
              'sort_order': categoryMap.length,
              'created_at': now,
              'updated_at': now,
            });

            categoryMap[key] = categoryId;
            importedCategories++;
          }
        }

        final amount = _amount(_value(row, ['Сумма']));

        if (amount <= 0) continue;

        final date = _date(_value(row, ['Дата']));
        final description = _string(row, ['Описание']);

        final signature = _transactionSignature(
          date: date,
          type: type,
          accountId: accountId,
          destinationId: destinationId ?? '',
          categoryId: categoryId ?? '',
          amount: amount,
          description: description,
        );

        if (!transactionSignatures.add(signature)) {
          skippedTransactions++;
          continue;
        }

        await txn.insert('finance_transactions', {
          'id': _uuid.v4(),
          'title': categoryName.isNotEmpty
              ? categoryName
              : _transactionTitle(type),
          'transaction_type': type,
          'amount_minor': amount,
          'account_id': accountId,
          'destination_account_id': destinationId,
          'category_id': categoryId,
          'debt_id': null,
          'transaction_date': date,
          'description': description,
          'created_at': now,
          'updated_at': now,
        });

        importedTransactions++;
      }

      // 3. Кредиты

      final existingDebts = await txn.query('finance_debts');

      final debtSignatures = existingDebts.map((item) {
        return _debtSignature(
          bank: item['creditor']?.toString() ?? item['name']?.toString() ?? '',
          initialAmount: (item['initial_amount_minor'] as num?)?.toInt() ?? 0,
          endDate: item['end_date']?.toString() ?? '',
          monthlyPayment: (item['monthly_payment_minor'] as num?)?.toInt() ?? 0,
        );
      }).toSet();

      for (final row in debtRows) {
        final bank = _string(row, ['Банк']);

        if (bank.isEmpty) continue;

        final initialAmount = _amount(_value(row, ['Сумма кредита']));

        final currentBalance = _amount(_value(row, ['Остаток долга']));

        final monthlyPayment = _amount(
          _value(row, ['Ежемесячный платёж', 'Ежемесячный платеж']),
        );

        final endDate = _optionalDate(_value(row, ['Дата окончания']));

        final signature = _debtSignature(
          bank: bank,
          initialAmount: initialAmount,
          endDate: endDate ?? '',
          monthlyPayment: monthlyPayment,
        );

        if (!debtSignatures.add(signature)) continue;

        final status = _debtStatus(_string(row, ['Статус']), currentBalance);

        await txn.insert('finance_debts', {
          'id': _uuid.v4(),
          'name': bank,
          'debt_type': 'loan',
          'creditor': bank,
          'initial_amount_minor': initialAmount,
          'current_balance_minor': currentBalance,
          'interest_rate': _number(_value(row, ['Процентная ставка'])),
          'monthly_payment_minor': monthlyPayment,
          'payment_day': _integer(_value(row, ['День платежа'])),
          'next_payment_date': _optionalDate(
            _value(row, ['Ближайший платёж', 'Ближайший платеж']),
          ),
          'start_date': null,
          'end_date': endDate,
          'status': status,
          'notes': '',
          'sort_order': importedDebts,
          'created_at': now,
          'updated_at': now,
        });

        importedDebts++;
      }

      // 4. Бюджеты

      if (budgetPeriod != null) {
        for (final row in budgetRows) {
          final categoryName = _string(row, ['Категория']);

          if (categoryName.isEmpty) continue;

          final categoryId = categoryMap[_categoryKey(categoryName, 'expense')];

          if (categoryId == null) continue;

          final limit = _amount(_value(row, ['Бюджет']));

          final existing = await txn.query(
            'finance_budgets',
            where: 'category_id = ? AND year = ? AND month = ?',
            whereArgs: [categoryId, budgetPeriod.year, budgetPeriod.month],
            limit: 1,
          );

          if (existing.isNotEmpty) {
            await txn.update(
              'finance_budgets',
              {'limit_minor': limit, 'updated_at': now},
              where: 'id = ?',
              whereArgs: [existing.first['id']],
            );
          } else {
            await txn.insert('finance_budgets', {
              'id': _uuid.v4(),
              'category_id': categoryId,
              'year': budgetPeriod.year,
              'month': budgetPeriod.month,
              'limit_minor': limit,
              'created_at': now,
              'updated_at': now,
            });
          }

          importedBudgets++;
        }
      }

      // 5. Накопления

      final existingGoals = await txn.query('finance_savings_goals');

      final goalTitles = existingGoals
          .map((item) => _normalize(item['title']?.toString() ?? ''))
          .toSet();

      for (final row in savingsRows) {
        final title = _string(row, ['Цель']);

        if (title.isEmpty) continue;

        final key = _normalize(title);

        if (goalTitles.contains(key)) continue;

        final targetAmount = _amount(_value(row, ['Сумма цели']));

        final savedAmount = _amount(_value(row, ['Накоплено']));

        final status = savedAmount >= targetAmount ? 'completed' : 'active';

        await txn.insert('finance_savings_goals', {
          'id': _uuid.v4(),
          'title': title,
          'target_amount_minor': targetAmount,
          'saved_amount_minor': savedAmount,
          'currency': 'RUB',
          'target_date': _optionalDate(_value(row, ['Дата цели'])),
          'status': status,
          'sort_order': importedSavings,
          'created_at': now,
          'updated_at': now,
        });

        goalTitles.add(key);
        importedSavings++;
      }
    });

    return FinanceExcelImportResult(
      accounts: importedAccounts,
      categories: importedCategories,
      transactions: importedTransactions,
      debts: importedDebts,
      budgets: importedBudgets,
      savingsGoals: importedSavings,
      skippedTransactions: skippedTransactions,
    );
  }

  static List<Map<String, Object?>> _readRows(SpreadsheetSheetData sheet) {
    if (sheet.rows.isEmpty) return [];

    final headers = sheet.rows.first
        .map((value) => _normalize(value?.toString() ?? ''))
        .toList();

    final result = <Map<String, Object?>>[];

    for (final row in sheet.rows.skip(1)) {
      final values = <String, Object?>{};

      for (var i = 0; i < headers.length; i++) {
        if (headers[i].isEmpty) continue;

        values[headers[i]] = i < row.length ? row[i] : null;
      }

      if (values.values.every(
        (value) => value == null || value.toString().trim().isEmpty,
      )) {
        continue;
      }

      result.add(values);
    }

    return result;
  }

  static Object? _value(Map<String, Object?> row, List<String> names) {
    for (final name in names) {
      final key = _normalize(name);

      if (row.containsKey(key)) return row[key];
    }

    return null;
  }

  static String _string(Map<String, Object?> row, List<String> names) {
    return _value(row, names)?.toString().trim() ?? '';
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  static int _amount(Object? value) {
    if (value == null) return 0;

    if (value is num) {
      return (value * 100).round();
    }

    var text = value
        .toString()
        .replaceAll('\u00A0', '')
        .replaceAll(' ', '')
        .replaceAll('₽', '')
        .replaceAll('руб.', '')
        .replaceAll('руб', '')
        .replaceAll('%', '')
        .trim();

    if (text.isEmpty) return 0;

    final comma = text.lastIndexOf(',');
    final dot = text.lastIndexOf('.');

    if (comma > dot) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else if (dot > comma) {
      text = text.replaceAll(',', '');
    } else {
      text = text.replaceAll(',', '.');
    }

    final number = double.tryParse(text.replaceAll(RegExp(r'[^0-9.\-]'), ''));

    return number == null ? 0 : (number * 100).round();
  }

  static double _number(Object? value) {
    if (value == null) return 0;

    final text = value
        .toString()
        .replaceAll('\u00A0', '')
        .replaceAll(' ', '')
        .replaceAll('%', '')
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.\-]'), '');

    return double.tryParse(text) ?? 0;
  }

  static int? _integer(Object? value) {
    if (value == null) return null;

    return int.tryParse(value.toString().replaceAll(RegExp(r'[^0-9\-]'), ''));
  }

  static bool _boolean(Object? value, {required bool defaultValue}) {
    if (value == null) return defaultValue;

    final text = _normalize(value.toString());

    if (['да', 'true', '1', 'активен', 'активна'].contains(text)) {
      return true;
    }

    if (['нет', 'false', '0', 'неактивен', 'неактивна'].contains(text)) {
      return false;
    }

    return defaultValue;
  }

  static String _currency(String value) {
    final text = value.trim().toUpperCase();

    if (text.contains('€') || text == 'EUR') return 'EUR';
    if (text.contains('\$') || text == 'USD') return 'USD';

    return 'RUB';
  }

  static String _accountType(String value) {
    final text = _normalize(value);

    if (text.contains('карт')) return 'card';
    if (text.contains('банк')) return 'bankAccount';
    if (text.contains('налич')) return 'cash';

    return 'other';
  }

  static String _transactionType(String value) {
    final text = _normalize(value);

    if (text.contains('перев')) return 'transfer';
    if (text.contains('доход')) return 'income';
    if (text.contains('расход')) return 'expense';

    throw Exception('Неизвестный тип операции: «$value».');
  }

  static String _transactionTitle(String type) {
    switch (type) {
      case 'income':
        return 'Доход';
      case 'expense':
        return 'Расход';
      default:
        return 'Перевод';
    }
  }

  static String _debtStatus(String value, int currentBalance) {
    if (currentBalance <= 0) return 'paidOff';

    final text = _normalize(value);

    if (text.contains('приостанов')) return 'paused';

    return 'active';
  }

  static String _accountKey(String name, String currency) {
    return '${_normalize(name)}|${currency.toUpperCase()}';
  }

  static String _categoryKey(String name, String type) {
    return '${_normalize(name)}|$type';
  }

  static String _findCurrency(
    String accountName,
    Map<String, String> accountMap,
  ) {
    final prefix = '${_normalize(accountName)}|';

    for (final key in accountMap.keys) {
      if (key.startsWith(prefix)) {
        return key.split('|').last;
      }
    }

    return 'RUB';
  }

  static String _transactionSignature({
    required String date,
    required String type,
    required String accountId,
    required String destinationId,
    required String categoryId,
    required int amount,
    required String description,
  }) {
    return [
      date,
      type,
      accountId,
      destinationId,
      categoryId,
      amount,
      _normalize(description),
    ].join('|');
  }

  static String _debtSignature({
    required String bank,
    required int initialAmount,
    required String endDate,
    required int monthlyPayment,
  }) {
    final parsedDate = DateTime.tryParse(endDate);

    final normalizedDate = parsedDate == null
        ? _normalize(endDate)
        : '${parsedDate.year}-'
              '${parsedDate.month.toString().padLeft(2, '0')}-'
              '${parsedDate.day.toString().padLeft(2, '0')}';

    return [
      _normalize(bank),
      initialAmount,
      normalizedDate,
      monthlyPayment,
    ].join('|');
  }

  static String _date(Object? value) {
    final parsed = _parseDate(value);

    if (parsed == null) {
      throw Exception('Не удалось распознать дату операции: $value');
    }

    return parsed.toIso8601String();
  }

  static String? _optionalDate(Object? value) {
    if (value == null || value.toString().trim().isEmpty) {
      return null;
    }

    return _parseDate(value)?.toIso8601String();
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is num) {
      final milliseconds = (value * Duration.millisecondsPerDay).round();

      return DateTime(1899, 12, 30).add(Duration(milliseconds: milliseconds));
    }

    final text = value.toString().trim();

    final iso = DateTime.tryParse(text);
    if (iso != null) return iso;

    final match = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$')
        .firstMatch(text);

    if (match != null) {
      return DateTime(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
    }

    return null;
  }
}
