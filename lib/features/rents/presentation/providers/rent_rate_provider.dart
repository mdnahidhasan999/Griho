import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../units/presentation/providers/unit_provider.dart';
import '../../data/datasources/rent_rate_datasource.dart';
import '../../data/repositories/rent_rate_repository_impl.dart';
import '../../domain/entities/rent_rate.dart';
import '../../domain/repositories/rent_rate_repository.dart';
import '../../domain/usecases/change_floor_rent.dart';
import '../../domain/usecases/change_unit_rent.dart';
import '../../domain/usecases/create_initial_rent_rate.dart';
import '../../domain/usecases/get_current_rent_rate.dart';
import '../../domain/usecases/get_rent_rate_applicable_at.dart';
import '../../domain/usecases/get_tenant_rent_rate_history.dart';
import '../../domain/usecases/get_unit_rent_rate_history.dart';
import '../controllers/rent_rate_controller.dart';

// ============================================================================
// DATA SOURCE
// ============================================================================

final rentRateDataSourceProvider = Provider<RentRateDataSource>((ref) {
  return RentRateDataSource();
});

// ============================================================================
// REPOSITORY
// ============================================================================

final rentRateRepositoryProvider = Provider<RentRateRepository>((ref) {
  return RentRateRepositoryImpl(
    dataSource: ref.read(rentRateDataSourceProvider),
    unitRepository: ref.read(unitRepositoryProvider),
  );
});

// ============================================================================
// USE CASES
// ============================================================================

final createInitialRentRateProvider = Provider<CreateInitialRentRate>((ref) {
  return CreateInitialRentRate(
    repository: ref.read(rentRateRepositoryProvider),
  );
});

final changeUnitRentProvider = Provider<ChangeUnitRent>((ref) {
  return ChangeUnitRent(repository: ref.read(rentRateRepositoryProvider));
});

final changeFloorRentProvider = Provider<ChangeFloorRent>((ref) {
  return ChangeFloorRent(repository: ref.read(rentRateRepositoryProvider));
});
final getRentRateApplicableAtProvider = Provider<GetRentRateApplicableAt>((
  ref,
) {
  return GetRentRateApplicableAt(
    repository: ref.read(rentRateRepositoryProvider),
  );
});
final getCurrentRentRateProvider = Provider<GetCurrentRentRate>((ref) {
  return GetCurrentRentRate(repository: ref.read(rentRateRepositoryProvider));
});

final getUnitRentRateHistoryProvider = Provider<GetUnitRentRateHistory>((ref) {
  return GetUnitRentRateHistory(
    repository: ref.read(rentRateRepositoryProvider),
  );
});

final getTenantRentRateHistoryProvider = Provider<GetTenantRentRateHistory>((
  ref,
) {
  return GetTenantRentRateHistory(
    repository: ref.read(rentRateRepositoryProvider),
  );
});

// ============================================================================
// CURRENT RENT RATE — UNIT
// ============================================================================

final currentRentRateProvider =
    FutureProvider.family<RentRate?, ({String unitId, String ownerId})>((
      ref,
      args,
    ) async {
      final getCurrentRentRate = ref.read(getCurrentRentRateProvider);

      return getCurrentRentRate(unitId: args.unitId, ownerId: args.ownerId);
    });

// ============================================================================
// RENT RATE HISTORY — UNIT
// ============================================================================

final unitRentRateHistoryProvider =
    FutureProvider.family<List<RentRate>, ({String unitId, String ownerId})>((
      ref,
      args,
    ) async {
      final getHistory = ref.read(getUnitRentRateHistoryProvider);

      return getHistory(unitId: args.unitId, ownerId: args.ownerId);
    });

// ============================================================================
// RENT RATE HISTORY — TENANT
// ============================================================================

final tenantRentRateHistoryProvider =
    FutureProvider.family<List<RentRate>, ({String tenantId, String ownerId})>((
      ref,
      args,
    ) async {
      final getHistory = ref.read(getTenantRentRateHistoryProvider);

      return getHistory(tenantId: args.tenantId, ownerId: args.ownerId);
    });

// ============================================================================
// CONTROLLER
// ============================================================================

final rentRateControllerProvider =
    StateNotifierProvider<RentRateController, AsyncValue<void>>((ref) {
      return RentRateController(
        createInitialRentRate: ref.read(createInitialRentRateProvider),
        changeUnitRent: ref.read(changeUnitRentProvider),
        changeFloorRent: ref.read(changeFloorRentProvider),
      );
    });
final rentRateApplicableAtProvider =
    FutureProvider.family<
      RentRate?,
      ({String unitId, String ownerId, DateTime effectiveAt})
    >((ref, args) async {
      final getRentRate = ref.read(getRentRateApplicableAtProvider);

      return getRentRate(
        unitId: args.unitId,
        ownerId: args.ownerId,
        effectiveAt: args.effectiveAt,
      );
    });
