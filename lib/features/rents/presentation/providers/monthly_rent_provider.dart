// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final monthlyRentDataSourceProvider = Provider<MonthlyRentDataSource>((ref) {
  return MonthlyRentDataSource();
});

final monthlyRentRepositoryProvider = Provider<MonthlyRentRepository>((ref) {
  return MonthlyRentRepositoryImpl(
    dataSource: ref.read(monthlyRentDataSourceProvider),
  );
});

final createMonthlyRentProvider = Provider<CreateMonthlyRent>((ref) {
  return CreateMonthlyRent(repository: ref.read(monthlyRentRepositoryProvider));
});

final generateMonthlyRentProvider = Provider<GenerateMonthlyRent>((ref) {
  return GenerateMonthlyRent(
    monthlyRentRepository: ref.read(monthlyRentRepositoryProvider),
    rentRateRepository: ref.read(rentRateRepositoryProvider),
  );
});

final getMonthlyRentByIdProvider = Provider<GetMonthlyRentById>((ref) {
  return GetMonthlyRentById(
    repository: ref.read(monthlyRentRepositoryProvider),
  );
});

final getMonthlyRentByUnitAndPeriodProvider =
    Provider<GetMonthlyRentByUnitAndPeriod>((ref) {
      return GetMonthlyRentByUnitAndPeriod(
        repository: ref.read(monthlyRentRepositoryProvider),
      );
    });

final getUnitMonthlyRentHistoryProvider = Provider<GetUnitMonthlyRentHistory>((
  ref,
) {
  return GetUnitMonthlyRentHistory(
    repository: ref.read(monthlyRentRepositoryProvider),
  );
});

final getTenantMonthlyRentHistoryProvider =
    Provider<GetTenantMonthlyRentHistory>((ref) {
      return GetTenantMonthlyRentHistory(
        repository: ref.read(monthlyRentRepositoryProvider),
      );
    });

final monthlyRentByIdProvider = FutureProvider.family<MonthlyRent?, String>((
  ref,
  rentId,
) async {
  return ref.read(getMonthlyRentByIdProvider)(rentId);
});

final monthlyRentByUnitAndPeriodProvider =
    FutureProvider.family<
      List<MonthlyRent>,
      ({String unitId, String ownerId, DateTime billingPeriodStart})
    >((ref, args) async {
      return ref.read(getMonthlyRentByUnitAndPeriodProvider)(
        unitId: args.unitId,
        ownerId: args.ownerId,
        billingPeriodStart: args.billingPeriodStart,
      );
    });

final unitMonthlyRentHistoryProvider =
    FutureProvider.family<List<MonthlyRent>, ({String unitId, String ownerId})>(
      (ref, args) async {
        return ref.read(getUnitMonthlyRentHistoryProvider)(
          unitId: args.unitId,
          ownerId: args.ownerId,
        );
      },
    );

final tenantMonthlyRentHistoryProvider =
    FutureProvider.family<
      List<MonthlyRent>,
      ({String tenantId, String ownerId})
    >((ref, args) async {
      return ref.read(getTenantMonthlyRentHistoryProvider)(
        tenantId: args.tenantId,
        ownerId: args.ownerId,
      );
    });

final monthlyRentControllerProvider =
    NotifierProvider<MonthlyRentController, AsyncValue<void>>(
      MonthlyRentController.new,
    );
