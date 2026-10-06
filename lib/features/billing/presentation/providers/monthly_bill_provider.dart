import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/monthly_bill_datasource.dart';
import '../../data/repositories/monthly_bill_repository_impl.dart';
import '../../domain/entities/monthly_bill.dart';
import '../../domain/repositories/monthly_bill_repository.dart';

final monthlyBillDataSourceProvider = Provider<MonthlyBillDataSource>((ref) {
  return MonthlyBillDataSource();
});

final monthlyBillRepositoryProvider = Provider<MonthlyBillRepository>((ref) {
  return MonthlyBillRepositoryImpl(
    dataSource: ref.read(monthlyBillDataSourceProvider),
  );
});

// ============================================================================
// BILL BY ID
// ============================================================================

final monthlyBillByIdProvider = FutureProvider.family<MonthlyBill?, String>((
  ref,
  billId,
) async {
  final repository = ref.read(monthlyBillRepositoryProvider);

  return repository.getMonthlyBillById(billId: billId);
});

// ============================================================================
// UNIT + PERIOD
// ============================================================================

final monthlyBillsByUnitAndPeriodProvider =
    FutureProvider.family<
      List<MonthlyBill>,
      ({String ownerId, String unitId, DateTime billingPeriodStart})
    >((ref, params) async {
      final repository = ref.read(monthlyBillRepositoryProvider);

      return repository.getMonthlyBillsByUnitAndPeriod(
        ownerId: params.ownerId,
        unitId: params.unitId,
        billingPeriodStart: params.billingPeriodStart,
      );
    });

// ============================================================================
// TENANT + PERIOD
// ============================================================================

final monthlyBillsByTenantAndPeriodProvider =
    FutureProvider.family<
      List<MonthlyBill>,
      ({String tenantUserId, DateTime billingPeriodStart})
    >((ref, params) async {
      final repository = ref.read(monthlyBillRepositoryProvider);

      return repository.getMonthlyBillsByTenantAndPeriod(
        tenantUserId: params.tenantUserId,
        billingPeriodStart: params.billingPeriodStart,
      );
    });

// ============================================================================
// TENANT BILL HISTORY
// ============================================================================

final tenantMonthlyBillHistoryProvider =
    FutureProvider.family<List<MonthlyBill>, String>((ref, tenantUserId) async {
      final repository = ref.read(monthlyBillRepositoryProvider);

      return repository.getMonthlyBillHistoryByTenantUserId(
        tenantUserId: tenantUserId,
      );
    });

// ============================================================================
// PROPERTY + PERIOD
// ============================================================================

final monthlyBillsByPropertyAndPeriodProvider =
    FutureProvider.family<
      List<MonthlyBill>,
      ({String ownerId, String propertyId, DateTime billingPeriodStart})
    >((ref, params) async {
      final repository = ref.read(monthlyBillRepositoryProvider);

      return repository.getMonthlyBillsByPropertyAndPeriod(
        ownerId: params.ownerId,
        propertyId: params.propertyId,
        billingPeriodStart: params.billingPeriodStart,
      );
    });

// ============================================================================
// PROPERTY BILL HISTORY
// ============================================================================

final propertyMonthlyBillHistoryProvider =
    FutureProvider.family<
      List<MonthlyBill>,
      ({String ownerId, String propertyId})
    >((ref, params) async {
      final repository = ref.read(monthlyBillRepositoryProvider);

      return repository.getMonthlyBillHistoryByPropertyId(
        ownerId: params.ownerId,
        propertyId: params.propertyId,
      );
    });
