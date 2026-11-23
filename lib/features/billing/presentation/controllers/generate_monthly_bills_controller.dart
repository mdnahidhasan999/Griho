// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/monthly_bill.dart';
import '../../domain/usecases/generate_monthly_bills.dart';
import '../providers/monthly_bill_generation_provider.dart';
import '../providers/monthly_bill_provider.dart';

final generateMonthlyBillsControllerProvider =
NotifierProvider<
    GenerateMonthlyBillsController,
    AsyncValue<List<MonthlyBill>>
>(GenerateMonthlyBillsController.new);

class GenerateMonthlyBillsController
    extends Notifier<AsyncValue<List<MonthlyBill>>> {
  @override
  AsyncValue<List<MonthlyBill>> build() => const AsyncValue.data([]);

  Future<List<MonthlyBill>> generate({
    required String ownerId,
    required String propertyId,
    required List<MonthlyBillTarget> targets,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
    required DateTime dueDate,
  }) async {
    state = const AsyncValue.loading();

    try {
      final generateMonthlyBills = ref.read(generateMonthlyBillsProvider);

      final bills = await generateMonthlyBills(
        ownerId: ownerId,
        propertyId: propertyId,
        targets: targets,
        billingPeriodStart: billingPeriodStart,
        billingPeriodEnd: billingPeriodEnd,
        dueDate: dueDate,
      );

      state = AsyncValue.data(bills);

      if (bills.isNotEmpty) {
        ref.invalidate(
          monthlyBillsByPropertyAndPeriodProvider((
          ownerId: ownerId,
          propertyId: propertyId,
          billingPeriodStart: billingPeriodStart,
          )),
        );
        ref.invalidate(
          propertyMonthlyBillHistoryProvider((
          ownerId: ownerId,
          propertyId: propertyId,
          )),
        );
      }

      return bills;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
      rethrow;
    }
  }

  void reset() {
    state = const AsyncValue.data([]);
  }
}
