enum FinanceAccountType { card, bankAccount, cash, other }

enum FinanceCategoryType { income, expense }

enum FinanceTransactionType { income, expense, transfer }

enum FinanceDebtType { loan, installment, other }

enum FinanceDebtStatus { active, paidOff, paused }

String _dateToString(DateTime? date) => date?.toIso8601String() ?? '';

DateTime _dateFromString(Object? value) {
  return DateTime.parse(value as String);
}

DateTime? _nullableDateFromString(Object? value) {
  if (value == null || value == '') return null;
  return DateTime.parse(value as String);
}

String _enumValue<T extends Enum>(T value) => value.name;

T _enumFromString<T extends Enum>(List<T> values, Object? value, T fallback) {
  return values.firstWhere(
    (item) => item.name == value,
    orElse: () => fallback,
  );
}

// --------------------------------------------------
// Счета
// --------------------------------------------------

class FinanceAccount {
  const FinanceAccount({
    required this.id,
    required this.name,
    required this.type,
    this.currency = 'RUB',
    this.openingBalanceMinor = 0,
    this.isActive = true,
    this.sortOrder = 0,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final FinanceAccountType type;
  final String currency;
  final int openingBalanceMinor;
  final bool isActive;
  final int sortOrder;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'account_type': _enumValue(type),
      'currency': currency,
      'opening_balance_minor': openingBalanceMinor,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
      'notes': notes,
      'created_at': _dateToString(createdAt),
      'updated_at': _dateToString(updatedAt),
    };
  }

  factory FinanceAccount.fromMap(Map<String, Object?> map) {
    return FinanceAccount(
      id: map['id'] as String,
      name: map['name'] as String,
      type: _enumFromString(
        FinanceAccountType.values,
        map['account_type'],
        FinanceAccountType.other,
      ),
      currency: map['currency'] as String? ?? 'RUB',
      openingBalanceMinor: map['opening_balance_minor'] as int? ?? 0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      notes: map['notes'] as String? ?? '',
      createdAt: _dateFromString(map['created_at']),
      updatedAt: _dateFromString(map['updated_at']),
    );
  }
}

// --------------------------------------------------
// Категории
// --------------------------------------------------

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
    this.isActive = true,
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final FinanceCategoryType type;
  final String? parentId;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'category_type': _enumValue(type),
      'parent_id': parentId,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
      'created_at': _dateToString(createdAt),
      'updated_at': _dateToString(updatedAt),
    };
  }

  factory FinanceCategory.fromMap(Map<String, Object?> map) {
    return FinanceCategory(
      id: map['id'] as String,
      name: map['name'] as String,
      type: _enumFromString(
        FinanceCategoryType.values,
        map['category_type'],
        FinanceCategoryType.expense,
      ),
      parentId: map['parent_id'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: _dateFromString(map['created_at']),
      updatedAt: _dateFromString(map['updated_at']),
    );
  }
}

// --------------------------------------------------
// Финансовые операции
// --------------------------------------------------

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.title,
    required this.type,
    required this.amountMinor,
    required this.accountId,
    this.destinationAccountId,
    this.categoryId,
    this.debtId,
    required this.transactionDate,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final FinanceTransactionType type;
  final int amountMinor;
  final String accountId;
  final String? destinationAccountId;
  final String? categoryId;
  final String? debtId;
  final DateTime transactionDate;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'title': title,
      'transaction_type': _enumValue(type),
      'amount_minor': amountMinor,
      'account_id': accountId,
      'destination_account_id': destinationAccountId,
      'category_id': categoryId,
      'debt_id': debtId,
      'transaction_date': _dateToString(transactionDate),
      'description': description,
      'created_at': _dateToString(createdAt),
      'updated_at': _dateToString(updatedAt),
    };
  }

  factory FinanceTransaction.fromMap(Map<String, Object?> map) {
    return FinanceTransaction(
      id: map['id'] as String,
      title: map['title'] as String,
      type: _enumFromString(
        FinanceTransactionType.values,
        map['transaction_type'],
        FinanceTransactionType.expense,
      ),
      amountMinor: map['amount_minor'] as int,
      accountId: map['account_id'] as String,
      destinationAccountId: map['destination_account_id'] as String?,
      categoryId: map['category_id'] as String?,
      debtId: map['debt_id'] as String?,
      transactionDate: _dateFromString(map['transaction_date']),
      description: map['description'] as String? ?? '',
      createdAt: _dateFromString(map['created_at']),
      updatedAt: _dateFromString(map['updated_at']),
    );
  }
}

// --------------------------------------------------
// Кредиты и рассрочки
// --------------------------------------------------

class FinanceDebt {
  const FinanceDebt({
    required this.id,
    required this.name,
    this.type = FinanceDebtType.loan,
    this.creditor = '',
    required this.initialAmountMinor,
    required this.currentBalanceMinor,
    this.interestRate = 0,
    this.monthlyPaymentMinor = 0,
    this.paymentDay,
    this.nextPaymentDate,
    this.startDate,
    this.endDate,
    this.status = FinanceDebtStatus.active,
    this.notes = '',
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final FinanceDebtType type;
  final String creditor;
  final int initialAmountMinor;
  final int currentBalanceMinor;
  final double interestRate;
  final int monthlyPaymentMinor;
  final int? paymentDay;
  final DateTime? nextPaymentDate;
  final DateTime? startDate;
  final DateTime? endDate;
  final FinanceDebtStatus status;
  final String notes;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'debt_type': _enumValue(type),
      'creditor': creditor,
      'initial_amount_minor': initialAmountMinor,
      'current_balance_minor': currentBalanceMinor,
      'interest_rate': interestRate,
      'monthly_payment_minor': monthlyPaymentMinor,
      'payment_day': paymentDay,
      'next_payment_date': nextPaymentDate?.toIso8601String(),
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': _enumValue(status),
      'notes': notes,
      'sort_order': sortOrder,
      'created_at': _dateToString(createdAt),
      'updated_at': _dateToString(updatedAt),
    };
  }

  factory FinanceDebt.fromMap(Map<String, Object?> map) {
    return FinanceDebt(
      id: map['id'] as String,
      name: map['name'] as String,
      type: _enumFromString(
        FinanceDebtType.values,
        map['debt_type'],
        FinanceDebtType.loan,
      ),
      creditor: map['creditor'] as String? ?? '',
      initialAmountMinor: map['initial_amount_minor'] as int? ?? 0,
      currentBalanceMinor: map['current_balance_minor'] as int? ?? 0,
      interestRate: (map['interest_rate'] as num?)?.toDouble() ?? 0,
      monthlyPaymentMinor: map['monthly_payment_minor'] as int? ?? 0,
      paymentDay: map['payment_day'] as int?,
      nextPaymentDate: _nullableDateFromString(map['next_payment_date']),
      startDate: _nullableDateFromString(map['start_date']),
      endDate: _nullableDateFromString(map['end_date']),
      status: _enumFromString(
        FinanceDebtStatus.values,
        map['status'],
        FinanceDebtStatus.active,
      ),
      notes: map['notes'] as String? ?? '',
      sortOrder: map['sort_order'] as int? ?? 0,
      createdAt: _dateFromString(map['created_at']),
      updatedAt: _dateFromString(map['updated_at']),
    );
  }
}

// --------------------------------------------------
// Платежи по кредитам
// --------------------------------------------------

class FinanceDebtPayment {
  const FinanceDebtPayment({
    required this.id,
    required this.debtId,
    required this.transactionId,
    required this.amountMinor,
    required this.principalMinor,
    required this.interestMinor,
    required this.paidAt,
    this.notes = '',
    required this.createdAt,
  });

  final String id;
  final String debtId;
  final String transactionId;
  final int amountMinor;
  final int principalMinor;
  final int interestMinor;
  final DateTime paidAt;
  final String notes;
  final DateTime createdAt;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'debt_id': debtId,
      'transaction_id': transactionId,
      'amount_minor': amountMinor,
      'principal_minor': principalMinor,
      'interest_minor': interestMinor,
      'paid_at': _dateToString(paidAt),
      'notes': notes,
      'created_at': _dateToString(createdAt),
    };
  }

  factory FinanceDebtPayment.fromMap(Map<String, Object?> map) {
    return FinanceDebtPayment(
      id: map['id'] as String,
      debtId: map['debt_id'] as String,
      transactionId: map['transaction_id'] as String,
      amountMinor: map['amount_minor'] as int,
      principalMinor: map['principal_minor'] as int,
      interestMinor: map['interest_minor'] as int,
      paidAt: _dateFromString(map['paid_at']),
      notes: map['notes'] as String? ?? '',
      createdAt: _dateFromString(map['created_at']),
    );
  }
}
