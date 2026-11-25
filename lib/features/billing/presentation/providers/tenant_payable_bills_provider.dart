// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tenants/domain/entities/tenant.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../domain/entities/monthly_bill.dart';
import '../../domain/entities/tenant_payable_bill.dart';
import 'monthly_bill_provider.dart';

/// Current billing period payable items (Rent + Utility Bills combined & deduplicated).
/// Reuses currentTenantMonthlyBillsProvider directly (which already includes monthlyRents)
/// to avoid redundant 60-month rent history Firestore reads.
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

      final monthlyBills = await ref.watch(
        currentTenantMonthlyBillsProvider.future,
      );

      final payableByKey = <String, TenantPayableBill>{};
      for (final bill in monthlyBills) {
        if (bill.tenantUserId != uid) {
          continue;
        }
        final payable = TenantPayableBill.fromMonthlyBill(bill);
        if (payable.isPayable) {
          payableByKey[payable.uniqueKey] = payable;
        }
      }

      return payableByKey.values.toList()..sort(_comparePayableBills);
    });

/// All monthly invoices (Rent + Utility Bills) grouped by month for the current tenant.
/// Reuses tenantMonthlyBillHistoryProvider (which already fetches both monthlyBills
/// and monthlyRents in parallel) to avoid duplicate Firestore queries.
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

      final historyBills = await ref.watch(
        tenantMonthlyBillHistoryProvider(uid).future,
      );

      final allByKey = <String, TenantPayableBill>{};
      for (final bill in historyBills) {
        if (bill.tenantUserId != uid) {
          continue;
        }
        if (bill.status == MonthlyBillStatus.cancelled) {
          continue;
        }
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

      return groupedByMonth.entries.map((entry) {
          final sortedItems = entry.value..sort(_comparePayableBills);
          return TenantMonthlyInvoiceGroup(
            billingPeriodStart: entry.key,
            items: sortedItems,
          );
        }).toList()
        ..sort((a, b) => b.billingPeriodStart.compareTo(a.billingPeriodStart));
    });

int _comparePayableBills(TenantPayableBill a, TenantPayableBill b) {
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
