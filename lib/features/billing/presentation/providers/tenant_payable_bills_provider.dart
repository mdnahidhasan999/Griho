import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../rents/domain/entities/monthly_rent.dart';
import '../../../rents/presentation/providers/monthly_rent_provider.dart';
import '../../../tenants/presentation/providers/tenant_dashboard_provider.dart';
import '../../../tenants/domain/entities/tenant.dart';

import '../../domain/entities/monthly_bill.dart';
import '../../domain/entities/tenant_payable_bill.dart';

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

      final payableBills = <TenantPayableBill>[];

      for (final bill in monthlyBills) {
        if (bill.tenantUserId != uid) continue;

        final payable = TenantPayableBill.fromMonthlyBill(bill);

        if (payable.isPayable) {
          payableBills.add(payable);
        }
      }

      for (final rent in rentHistory) {
        final sameMonth =
            rent.billingPeriodStart.year == periodStart.year &&
            rent.billingPeriodStart.month == periodStart.month;

        if (!sameMonth) continue;

        // Never allow a rent payment against a different tenant account.
        if (rent.tenantUserId != uid) continue;

        final payable = TenantPayableBill.fromMonthlyRent(rent);

        if (payable.isPayable) {
          payableBills.add(payable);
        }
      }

      payableBills.sort((a, b) {
        final dateComparison = a.dueDate.compareTo(b.dueDate);

        if (dateComparison != 0) {
          return dateComparison;
        }

        return a.title.compareTo(b.title);
      });

      return payableBills;
    });
