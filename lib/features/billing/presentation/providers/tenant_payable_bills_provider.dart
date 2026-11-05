import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../rents/domain/entities/monthly_rent.dart';
import '../../../rents/presentation/providers/monthly_rent_provider.dart';
import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../domain/entities/monthly_bill.dart';
import '../../domain/entities/tenant_payable_bill.dart';
import 'monthly_bill_provider.dart';

/// Current billing period payable items (Rent + Utility Bills combined & deduplicated).
final currentTenantPayableBillsProvider =
    FutureProvider<List<TenantPayableBill>>((ref) async {
      final tenant = await ref.watch(currentTenantProvider.future);

      if (tenant == null || tenant.status != TenantStatus.active) {
        return const [];
      }

      final firebaseUser = ref.watch(currentFirebaseUserProvider);
      final uid = firebaseUser?.uid.trim() ?? '';

      if (uid.isEmpty) {
        return const [];
      }

      final periodStart = ref.watch(currentBillingPeriodStartProvider);

      final billFuture = ref.watch(currentTenantMonthlyBillsProvider.future);

      final rentFuture = ref.watch(
        tenantMonthlyRentHistoryProvider((
          tenantId: tenant.id,
          ownerId: tenant.ownerId,
        )).future,
      );

      final results = await Future.wait<dynamic>([billFuture, rentFuture]);

      final monthlyBills = results[0] as List<MonthlyBill>;
      final rentHistory = results[1] as List<MonthlyRent>;

      final payableByKey = <String, TenantPayableBill>{};

      for (final rent in rentHistory) {
        final sameMonth =
            rent.billingPeriodStart.year == periodStart.year &&
            rent.billingPeriodStart.month == periodStart.month;

        if (!sameMonth) continue;
        if (rent.tenantUserId != uid) continue;

        final payable = TenantPayableBill.fromMonthlyRent(rent);
        if (payable.isPayable) {
          payableByKey[payable.uniqueKey] = payable;
        }
      }

      for (final bill in monthlyBills) {
        if (bill.tenantUserId != uid) continue;

        final payable = TenantPayableBill.fromMonthlyBill(bill);
        if (payable.isPayable) {
          payableByKey[payable.uniqueKey] = payable;
        }
      }

      final payableBills = payableByKey.values.toList()
        ..sort(_comparePayableBills);

      return payableBills;
    });

/// All monthly invoices (Rent + Utility Bills) grouped by month for the current tenant.
/// Powers the Expandable Monthly Invoice screen and Monthly History.
final currentTenantMonthlyInvoiceGroupsProvider =
    FutureProvider<List<TenantMonthlyInvoiceGroup>>((ref) async {
      final tenant = await ref.watch(currentTenantProvider.future);

      if (tenant == null) {
        return const [];
      }

      final firebaseUser = ref.watch(currentFirebaseUserProvider);
      final uid = firebaseUser?.uid.trim() ?? '';

      if (uid.isEmpty) {
        return const [];
      }

      final historyBillsFuture = ref.watch(
        tenantMonthlyBillHistoryProvider(uid).future,
      );

      final rentHistoryFuture = ref.watch(
        tenantMonthlyRentHistoryProvider((
          tenantId: tenant.id,
          ownerId: tenant.ownerId,
        )).future,
      );

      final results = await Future.wait<dynamic>([
        historyBillsFuture,
        rentHistoryFuture,
      ]);

      final historyBills = results[0] as List<MonthlyBill>;
      final rentHistory = results[1] as List<MonthlyRent>;

      final allByKey = <String, TenantPayableBill>{};

      for (final rent in rentHistory) {
        if (rent.tenantUserId != uid) continue;
        if (rent.status == MonthlyRentStatus.cancelled) continue;

        final item = TenantPayableBill.fromMonthlyRent(rent);
        allByKey[item.uniqueKey] = item;
      }

      for (final bill in historyBills) {
        if (bill.tenantUserId != uid) continue;
        if (bill.status == MonthlyBillStatus.cancelled) continue;

        final item = TenantPayableBill.fromMonthlyBill(bill);
        allByKey[item.uniqueKey] = item;
      }

      final groupedByMonth = <DateTime, List<TenantPayableBill>>{};

      for (final item in allByKey.values) {
        final monthKey = DateTime(
          item.billingPeriodStart.year,
          item.billingPeriodStart.month,
          1,
        );
        groupedByMonth.putIfAbsent(monthKey, () => []).add(item);
      }

      final groups =
          groupedByMonth.entries.map((entry) {
            final sortedItems = entry.value..sort(_comparePayableBills);
            return TenantMonthlyInvoiceGroup(
              billingPeriodStart: entry.key,
              items: sortedItems,
            );
          }).toList()..sort(
            (a, b) => b.billingPeriodStart.compareTo(a.billingPeriodStart),
          );

      return groups;
    });

int _comparePayableBills(TenantPayableBill a, TenantPayableBill b) {
  // Always list House Rent first inside a month
  final isRentA = a.collection == PayableBillCollection.monthlyRents ? 0 : 1;
  final isRentB = b.collection == PayableBillCollection.monthlyRents ? 0 : 1;

  if (isRentA != isRentB) {
    return isRentA.compareTo(isRentB);
  }

  final dateComparison = a.dueDate.compareTo(b.dueDate);
  if (dateComparison != 0) {
    return dateComparison;
  }

  return a.title.compareTo(b.title);
}
