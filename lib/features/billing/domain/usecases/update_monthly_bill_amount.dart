import '../entities/monthly_bill.dart';
import '../repositories/monthly_bill_repository.dart';

class UpdateMonthlyBillAmount {
  final MonthlyBillRepository _repository;

  const UpdateMonthlyBillAmount({
    required this._repository,
  });

  Future<MonthlyBill?> call({
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

    return _repository.updateMonthlyBillAmount(
      billId: normalizedBillId,
      amount: amount,
    );
  }
}