import 'package:lunora/core/localization/lunora_localization.dart';
import 'package:lunora/features/notifications/models/notification_item.dart';
import 'package:lunora/features/notifications/services/notification_service.dart';

import '../models/finance_models.dart';

class FinanceDebtNotificationService {
  FinanceDebtNotificationService._();

  static final FinanceDebtNotificationService instance =
      FinanceDebtNotificationService._();

  static const String _sourceModule = 'finance';

  String _eventKey(String debtId) => 'finance_debt_payment_$debtId';

  Future<void> syncDebt(FinanceDebt debt) async {
    final paymentDate = debt.nextPaymentDate;

    if (debt.status != FinanceDebtStatus.active ||
        paymentDate == null ||
        debt.monthlyPaymentMinor <= 0) {
      await cancelDebtNotification(debt.id);
      return;
    }

    final now = DateTime.now();

    final paymentDay = DateTime(
      paymentDate.year,
      paymentDate.month,
      paymentDate.day,
    );

    final today = DateTime(now.year, now.month, now.day);

    if (!paymentDay.isAfter(today)) {
      await cancelDebtNotification(debt.id);
      return;
    }

    final reminderDay = paymentDay.subtract(const Duration(days: 1));

    final scheduledAt = DateTime(
      reminderDay.year,
      reminderDay.month,
      reminderDay.day,
      9,
    );

    // Не отправляем просроченное напоминание сразу,
    // если пользователь создал или изменил задолженность
    // уже после времени напоминания.
    if (!scheduledAt.isAfter(now)) {
      await cancelDebtNotification(debt.id);
      return;
    }

    await NotificationService.instance.schedule(
      category: NotificationCategory.finance,
      type: NotificationType.reminder,
      eventType: 'debt_payment',
      eventKey: _eventKey(debt.id),
      title: LunoraLocalization.text(
        'Скоро платёж по кредиту',
        'Loan payment due soon',
      ),
      message: _buildMessage(debt, paymentDay),
      sourceModule: _sourceModule,
      sourceRecordId: debt.id,
      scheduledAt: scheduledAt,
    );
  }

  Future<void> cancelDebtNotification(String debtId) async {
    await NotificationService.instance.cancelBySource(
      sourceModule: _sourceModule,
      sourceRecordId: debtId,
    );
  }

  String _buildMessage(FinanceDebt debt, DateTime paymentDate) {
    final date =
        '${paymentDate.day.toString().padLeft(2, '0')}.'
        '${paymentDate.month.toString().padLeft(2, '0')}.'
        '${paymentDate.year}';

    final amount = (debt.monthlyPaymentMinor / 100)
        .toStringAsFixed(2)
        .replaceAll('.', ',');

    final creditor = debt.creditor.trim().isEmpty
        ? ''
        : '\n${LunoraLocalization.text('Кредитор: ', 'Lender: ')}${debt.creditor.trim()}';

    return '${debt.name}$creditor\n'
        '${LunoraLocalization.text('Дата платежа: ', 'Payment date: ')}$date\n'
        '${LunoraLocalization.text('Сумма платежа: ', 'Payment amount: ')}$amount';
  }
}
