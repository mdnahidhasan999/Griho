// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tenants/domain/entities/tenancy_billing_target.dart';
import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/generate_monthly_charges_result.dart';
import '../providers/monthly_bill_provider.dart';
import '../providers/monthly_charge_generation_provider.dart';

final generateMonthlyChargesControllerProvider =
NotifierProvider<
    GenerateMonthlyChargesController,
    AsyncValue<GenerateMonthlyChargesResult?>
>(GenerateMonthlyChargesController.new);

class GenerateMonthlyChargesController
    extends Notifier<AsyncValue<GenerateMonthlyChargesResult?>> {
  /// Keeps track of `{ownerId}_{propertyId}_{YYYY-MM}` so we never
  /// re-read or re-check Firebase when switching tabs or re-opening screens.
  final Set<String> _syncedPropertyMonthKeys = <String>{};

  @override
  AsyncValue<GenerateMonthlyChargesResult?> build() =>
      const AsyncValue.data(null);

  String _buildCycleKey({
    required String ownerId,
    required String propertyId,
    required DateTime billingPeriodStart,
  }) {
    final monthStr = billingPeriodStart.month.toString().padLeft(2, '0');
    return '${ownerId.trim()}_${propertyId.trim()}_${billingPeriodStart.year}-$monthStr';
  }

  bool isPropertySyncedForMonth({
    required String ownerId,
    required String propertyId,
    required DateTime billingPeriodStart,
  }) {
    final key = _buildCycleKey(
      ownerId: ownerId,
      propertyId: propertyId,
      billingPeriodStart: billingPeriodStart,
    );
    return _syncedPropertyMonthKeys.contains(key);
  }

  void invalidateMonthSyncLock({
    required String ownerId,
    required String propertyId,
    DateTime? billingPeriodStart,
  }) {
    if (billingPeriodStart != null) {
      final key = _buildCycleKey(
        ownerId: ownerId,
        propertyId: propertyId,
        billingPeriodStart: billingPeriodStart,
      );
      _syncedPropertyMonthKeys.remove(key);
      return;
    }

    final prefix = '${ownerId.trim()}_${propertyId.trim()}_';
    _syncedPropertyMonthKeys.removeWhere((k) => k.startsWith(prefix));
  }

  List<TenancyBillingTarget> _deduplicateTargets(
      List<TenancyBillingTarget> targets,
      ) {
    final seen = <String>{};
    final uniqueTargets = <TenancyBillingTarget>[];

    for (final target in targets) {
      final key = '${target.unitId.trim()}_${target.tenantId.trim()}';
      if (seen.add(key)) {
        uniqueTargets.add(target);
      }
    }

    return uniqueTargets;
  }

  Future<GenerateMonthlyChargesResult> generate({
    required String ownerId,
    required String propertyId,
    required List<TenancyBillingTarget> tenancyTargets,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
    required DateTime dueDate,
    bool generateRent = true,
    BillingValueType? onlyBillValueType,
  }) async {
    state = const AsyncValue.loading();

    try {
      final cleanTargets = _deduplicateTargets(tenancyTargets);
      final generateMonthlyCharges = ref.read(generateMonthlyChargesProvider);

      final result = await generateMonthlyCharges(
        ownerId: ownerId,
        propertyId: propertyId,
        tenancyTargets: cleanTargets,
        billingPeriodStart: billingPeriodStart,
        billingPeriodEnd: billingPeriodEnd,
        dueDate: dueDate,
        generateRent: generateRent,
        onlyBillValueType: onlyBillValueType,
      );

      final cycleKey = _buildCycleKey(
        ownerId: ownerId,
        propertyId: propertyId,
        billingPeriodStart: billingPeriodStart,
      );
      _syncedPropertyMonthKeys.add(cycleKey);

      state = AsyncValue.data(result);

      if (result.generatedRents.isNotEmpty ||
          result.generatedBills.isNotEmpty) {
        ref.invalidate(
          propertyMonthlyBillHistoryProvider((
          ownerId: ownerId,
          propertyId: propertyId,
          )),
        );
        ref.invalidate(
          monthlyBillsByPropertyAndPeriodProvider((
          ownerId: ownerId,
          propertyId: propertyId,
          billingPeriodStart: billingPeriodStart,
          )),
        );
      }

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
