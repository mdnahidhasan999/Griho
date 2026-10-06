import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/datasources/monthly_rent_datasource.dart';
import '../../data/repositories/monthly_rent_repository_impl.dart';

import '../../domain/entities/monthly_rent.dart';
import '../../domain/repositories/monthly_rent_repository.dart';

import '../../domain/usecases/create_monthly_rent.dart';
import '../../domain/usecases/generate_monthly_rent.dart';
import '../../domain/usecases/get_monthly_rent_by_id.dart';
import '../../domain/usecases/get_monthly_rent_by_unit_and_period.dart';
import '../../domain/usecases/get_tenant_monthly_rent_history.dart';
import '../../domain/usecases/get_unit_monthly_rent_history.dart';

import '../controllers/monthly_rent_controller.dart';
import 'rent_rate_provider.dart';

// ============================================================================
// DATA SOURCE
// ============================================================================

final monthlyRentDataSourceProvider =
Provider<MonthlyRentDataSource>((ref) {
  return MonthlyRentDataSource();
});

// ============================================================================
// REPOSITORY
// ============================================================================

final monthlyRentRepositoryProvider =
Provider<MonthlyRentRepository>((ref) {
  return MonthlyRentRepositoryImpl(
    dataSource: ref.read(
      monthlyRentDataSourceProvider,
    ),
  );
});

// ============================================================================
// USE CASES
// ============================================================================

final createMonthlyRentProvider =
Provider<CreateMonthlyRent>((ref) {
  return CreateMonthlyRent(
    repository: ref.read(
      monthlyRentRepositoryProvider,
    ),
  );
});

// ============================================================================
// GENERATE MONTHLY RENT
// ============================================================================
//
// New generation flow:
//
// Billing Period
//      ↓
// Tenancy Period
//      ↓
// Rent Rate History
//      ↓
// MonthlyRentGenerationCalculator
//      ↓
// Create MonthlyRent record(s)
//
// Supports:
// - calendar-month billing
// - prorated tenancy periods
// - rent-rate changes within a month
// - historical rent snapshots
//

final generateMonthlyRentProvider =
Provider<GenerateMonthlyRent>((ref) {
  return GenerateMonthlyRent(
    monthlyRentRepository: ref.read(
      monthlyRentRepositoryProvider,
    ),
    rentRateRepository: ref.read(
      rentRateRepositoryProvider,
    ),
  );
});

// ============================================================================
// QUERY USE CASES
// ============================================================================

final getMonthlyRentByIdProvider =
Provider<GetMonthlyRentById>((ref) {
  return GetMonthlyRentById(
    repository: ref.read(
      monthlyRentRepositoryProvider,
    ),
  );
});

final getMonthlyRentByUnitAndPeriodProvider =
Provider<GetMonthlyRentByUnitAndPeriod>((ref) {
  return GetMonthlyRentByUnitAndPeriod(
    repository: ref.read(
      monthlyRentRepositoryProvider,
    ),
  );
});

final getUnitMonthlyRentHistoryProvider =
Provider<GetUnitMonthlyRentHistory>((ref) {
  return GetUnitMonthlyRentHistory(
    repository: ref.read(
      monthlyRentRepositoryProvider,
    ),
  );
});

final getTenantMonthlyRentHistoryProvider =
Provider<GetTenantMonthlyRentHistory>((ref) {
  return GetTenantMonthlyRentHistory(
    repository: ref.read(
      monthlyRentRepositoryProvider,
    ),
  );
});

// ============================================================================
// MONTHLY RENT BY ID
// ============================================================================

final monthlyRentByIdProvider =
FutureProvider.family<MonthlyRent?, String>(
      (ref,
      rentId,) async {
    final getMonthlyRentById = ref.read(
      getMonthlyRentByIdProvider,
    );

    return getMonthlyRentById(
      rentId,
    );
  },
);

// ============================================================================
// MONTHLY RENTS BY UNIT + PERIOD
// ============================================================================
//
// A single unit can have multiple rent records in one billing month.
//
// Example:
//
// Tenant A → 01–14 September
// Tenant B → 15–30 September
//
// Or:
//
// Old rent rate → 01–09 October
// New rent rate → 10–31 October
//
// Therefore this provider returns List<MonthlyRent>.
//

final monthlyRentByUnitAndPeriodProvider =
FutureProvider.family<
    List<MonthlyRent>,
    ({
    String unitId,
    String ownerId,
    DateTime billingPeriodStart,
    })>(
      (ref,
      args,) async {
    final getMonthlyRent = ref.read(
      getMonthlyRentByUnitAndPeriodProvider,
    );

    return getMonthlyRent(
      unitId: args.unitId,
      ownerId: args.ownerId,
      billingPeriodStart: args.billingPeriodStart,
    );
  },
);

// ============================================================================
// UNIT HISTORY
// ============================================================================

final unitMonthlyRentHistoryProvider =
FutureProvider.family<
    List<MonthlyRent>,
    ({
    String unitId,
    String ownerId,
    })>(
      (ref,
      args,) async {
    final getHistory = ref.read(
      getUnitMonthlyRentHistoryProvider,
    );

    return getHistory(
      unitId: args.unitId,
      ownerId: args.ownerId,
    );
  },
);

// ============================================================================
// TENANT HISTORY
// ============================================================================

final tenantMonthlyRentHistoryProvider =
FutureProvider.family<
    List<MonthlyRent>,
    ({
    String tenantId,
    String ownerId,
    })>(
      (ref,
      args,) async {
    final getHistory = ref.read(
      getTenantMonthlyRentHistoryProvider,
    );

    return getHistory(
      tenantId: args.tenantId,
      ownerId: args.ownerId,
    );
  },
);

// ============================================================================
// CONTROLLER
// ============================================================================
//
// Kept for existing legacy create flow.
//
// New monthly rent generation should use:
// generateMonthlyRentProvider
//

final monthlyRentControllerProvider =
StateNotifierProvider<
    MonthlyRentController,
    AsyncValue<void>>(
      (ref) {
    return MonthlyRentController(
      createMonthlyRent: ref.read(
        createMonthlyRentProvider,
      ),
    );
  },
);