// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/presentation/providers/property_provider.dart';
import '../../../units/presentation/providers/unit_provider.dart';
import '../../data/datasources/rent_rate_datasource.dart';
import '../../data/repositories/rent_rate_repository_impl.dart';
import '../../domain/entities/rent_rate.dart';
import '../../domain/repositories/rent_rate_repository.dart';
import '../../domain/usecases/change_floor_rent.dart';
import '../../domain/usecases/change_property_rent.dart';
import '../../domain/usecases/change_unit_rent.dart';
import '../../domain/usecases/create_initial_rent_rate.dart';
import '../../domain/usecases/get_current_rent_rate.dart';
import '../../domain/usecases/get_rent_rate_applicable_at.dart';
import '../../domain/usecases/get_tenant_rent_rate_history.dart';
import '../../domain/usecases/get_unit_rent_rate_history.dart';
import '../controllers/rent_rate_controller.dart';

final rentRateDataSourceProvider = Provider<RentRateDataSource>((ref) {
  return RentRateDataSource();
});

final rentRateRepositoryProvider = Provider<RentRateRepository>((ref) {
  return RentRateRepositoryImpl(
    dataSource: ref.read(rentRateDataSourceProvider),
    unitRepository: ref.read(unitRepositoryProvider),
  );
});

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

final changePropertyRentProvider = Provider<ChangePropertyRent>((ref) {
  return ChangePropertyRent(repository: ref.read(rentRateRepositoryProvider));
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

final currentRentRateProvider =
    FutureProvider.family<RentRate?, ({String unitId, String ownerId})>((
      ref,
      args,
    ) async {
      return ref.read(getCurrentRentRateProvider)(
        unitId: args.unitId,
        ownerId: args.ownerId,
      );
    });

final currentTenantRentRateProvider = FutureProvider.family<RentRate?, String>((
  ref,
  unitId,
) async {
  final normalizedUnitId = unitId.trim();
  if (normalizedUnitId.isEmpty) {
    return null;
  }

  final unit = await ref.read(unitByIdProvider(normalizedUnitId).future);
  if (unit == null) {
    return null;
  }

  final property = await ref.read(propertyByIdProvider(unit.propertyId).future);
  if (property == null) {
    return null;
  }

  return ref.read(getCurrentRentRateProvider)(
    unitId: unit.id,
    ownerId: property.ownerId,
  );
});

final unitRentRateHistoryProvider =
    FutureProvider.family<List<RentRate>, ({String unitId, String ownerId})>((
      ref,
      args,
    ) async {
      return ref.read(getUnitRentRateHistoryProvider)(
        unitId: args.unitId,
        ownerId: args.ownerId,
      );
    });

final tenantRentRateHistoryProvider =
    FutureProvider.family<
      List<RentRate>,
      ({String unitId, String ownerId, String tenantId})
    >((ref, args) async {
      return ref.read(getTenantRentRateHistoryProvider)(
        unitId: args.unitId,
        ownerId: args.ownerId,
        tenantId: args.tenantId,
      );
    });

final rentRateControllerProvider =
    NotifierProvider<RentRateController, AsyncValue<void>>(
      RentRateController.new,
    );

final rentRateApplicableAtProvider =
    FutureProvider.family<
      RentRate?,
      ({String unitId, String ownerId, DateTime effectiveAt})
    >((ref, args) async {
      return ref.read(getRentRateApplicableAtProvider)(
        unitId: args.unitId,
        ownerId: args.ownerId,
        effectiveAt: args.effectiveAt,
      );
    });
