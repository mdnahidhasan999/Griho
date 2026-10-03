import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/monthly_bill.dart';
import '../../domain/usecases/generate_monthly_bills.dart';
import '../providers/monthly_bill_generation_provider.dart';
import '../providers/monthly_bill_provider.dart';

final generateMonthlyBillsControllerProvider =
StateNotifierProvider<
    GenerateMonthlyBillsController,
    AsyncValue<List<MonthlyBill>>>(
      (ref) {
    return GenerateMonthlyBillsController(
      ref: ref,
    );
  },
);

class GenerateMonthlyBillsController
    extends StateNotifier<AsyncValue<List<MonthlyBill>>> {
  final Ref _ref;

  GenerateMonthlyBillsController({
    required this._ref,
  })  : super(const AsyncValue.data([]));

  // ==========================================================================
  // GENERATE
  // ==========================================================================

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
      final generateMonthlyBills =
      _ref.read(generateMonthlyBillsProvider);

      final bills = await generateMonthlyBills(
        ownerId: ownerId,
        propertyId: propertyId,
        targets: targets,
        billingPeriodStart: billingPeriodStart,
        billingPeriodEnd: billingPeriodEnd,
        dueDate: dueDate,
      );

      state = AsyncValue.data(bills);

      // Refresh property bill data after generation.
      _ref.invalidate(
        monthlyBillsByPropertyAndPeriodProvider(
          (
          ownerId: ownerId,
          propertyId: propertyId,
          billingPeriodStart: billingPeriodStart,
          ),
        ),
      );

      // Refresh property bill history.
      _ref.invalidate(
        propertyMonthlyBillHistoryProvider(
          (
          ownerId: ownerId,
          propertyId: propertyId,
          ),
        ),
      );

      return bills;
    } catch (error, stackTrace) {
      state = AsyncValue.error(
        error,
        stackTrace,
      );

      rethrow;
    }
  }

  // ==========================================================================
  // RESET
  // ==========================================================================

  void reset() {
    state = const AsyncValue.data([]);
  }
}