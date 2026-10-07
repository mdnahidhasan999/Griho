import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../tenants/domain/entities/tenancy_billing_target.dart';
import '../../domain/entities/generate_monthly_charges_result.dart';
import '../providers/monthly_bill_provider.dart';
import '../providers/monthly_charge_generation_provider.dart';

final generateMonthlyChargesControllerProvider =
    StateNotifierProvider<
      GenerateMonthlyChargesController,
      AsyncValue<GenerateMonthlyChargesResult?>
    >((ref) {
      return GenerateMonthlyChargesController(ref: ref);
    });

class GenerateMonthlyChargesController
    extends StateNotifier<AsyncValue<GenerateMonthlyChargesResult?>> {
  final Ref _ref;

  GenerateMonthlyChargesController({required this._ref})
    : super(const AsyncValue.data(null));

  Future<GenerateMonthlyChargesResult> generate({
    required String ownerId,
    required String propertyId,
    required List<TenancyBillingTarget> tenancyTargets,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
    required DateTime dueDate,
  }) async {
    state = const AsyncValue.loading();

    try {
      final generateMonthlyCharges = _ref.read(generateMonthlyChargesProvider);

      final result = await generateMonthlyCharges(
        ownerId: ownerId,
        propertyId: propertyId,
        tenancyTargets: tenancyTargets,
        billingPeriodStart: billingPeriodStart,
        billingPeriodEnd: billingPeriodEnd,
        dueDate: dueDate,
      );

      state = AsyncValue.data(result);

      _ref.invalidate(
        propertyMonthlyBillHistoryProvider((
          ownerId: ownerId,
          propertyId: propertyId,
        )),
      );

      return result;
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);

      rethrow;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}
