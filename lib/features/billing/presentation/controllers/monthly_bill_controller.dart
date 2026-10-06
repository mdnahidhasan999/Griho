import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/monthly_bill.dart';
import '../../domain/usecases/update_monthly_bill_amount.dart';
import '../providers/monthly_bill_provider.dart';

class MonthlyBillController {
  final UpdateMonthlyBillAmount _updateMonthlyBillAmount;

  const MonthlyBillController({required this._updateMonthlyBillAmount});

  Future<MonthlyBill?> updateAmount({
    required String billId,
    required double amount,
  }) async {
    final normalizedBillId = billId.trim();

    if (normalizedBillId.isEmpty) {
      throw ArgumentError('Bill ID is required.');
    }

    if (amount.isNaN || amount.isInfinite) {
      throw ArgumentError('Bill amount must be a valid number.');
    }

    if (amount < 0) {
      throw ArgumentError('Bill amount cannot be negative.');
    }

    return _updateMonthlyBillAmount(billId: normalizedBillId, amount: amount);
  }
}

final monthlyBillControllerProvider = Provider<MonthlyBillController>((ref) {
  return MonthlyBillController(
    updateMonthlyBillAmount: UpdateMonthlyBillAmount(
      repository: ref.read(monthlyBillRepositoryProvider),
    ),
  );
});
