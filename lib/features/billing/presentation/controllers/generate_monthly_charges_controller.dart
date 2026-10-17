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

  /// Keeps track of `{ownerId}_{propertyId}_{YYYY-MM}` so we NEVER
  /// re-read or re-check Firebase when switching tabs or re-opening screens.
  final Set<String> _syncedPropertyMonthKeys = <String>{};

  GenerateMonthlyChargesController({required this._ref})
    : super(const AsyncValue.data(null));

  String _buildCycleKey({
    required String ownerId,
    required String propertyId,
    required DateTime billingPeriodStart,
  }) {
    final monthStr = billingPeriodStart.month.toString().padLeft(2, '0');
    return '${ownerId.trim()}_${propertyId.trim()}_${billingPeriodStart.year}-$monthStr';
  }

  /// Checks if this property has already been checked/synced for the given month.
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

  /// Marks a property's month cache as dirty (e.g., when a new billing rule is added)
  /// so the next check will sync the newly added rule.
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

  /// Deduplicates tenancy targets by (unitId + tenantId) before passing to use-case
  /// to guarantee zero duplicate generation in a single batch.
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

  /// Generates monthly charges (Rent + Fixed Bills + Variable Bills for the month).
  /// Safe for both automatic background sync and manual "Generate Bill" button clicks.
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
      final cleanTargets = _deduplicateTargets(tenancyTargets);
      final generateMonthlyCharges = _ref.read(generateMonthlyChargesProvider);

      final result = await generateMonthlyCharges(
        ownerId: ownerId,
        propertyId: propertyId,
        tenancyTargets: cleanTargets,
        billingPeriodStart: billingPeriodStart,
        billingPeriodEnd: billingPeriodEnd,
        dueDate: dueDate,
      );

      // Lock this property + month so we don't repeat unnecessary Firebase reads
      final cycleKey = _buildCycleKey(
        ownerId: ownerId,
        propertyId: propertyId,
        billingPeriodStart: billingPeriodStart,
      );
      _syncedPropertyMonthKeys.add(cycleKey);

      state = AsyncValue.data(result);

      // Only invalidate bill history providers if new records were actually created
      if (result.generatedRents.isNotEmpty ||
          result.generatedBills.isNotEmpty) {
        _ref.invalidate(
          propertyMonthlyBillHistoryProvider((
            ownerId: ownerId,
            propertyId: propertyId,
          )),
        );
        _ref.invalidate(
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
