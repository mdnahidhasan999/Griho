import '../../domain/entities/create_monthly_rent_request.dart';
import '../../domain/entities/monthly_rent.dart';
import '../../domain/repositories/monthly_rent_repository.dart';
import '../datasources/monthly_rent_datasource.dart';

class MonthlyRentRepositoryImpl
    implements MonthlyRentRepository {
  final MonthlyRentDataSource _dataSource;

  MonthlyRentRepositoryImpl({
    required this._dataSource,
  });

  // ==========================================================================
  // CREATE
  // ==========================================================================

  @override
  Future<MonthlyRent> createMonthlyRent(
      CreateMonthlyRentRequest request,
      ) {
    return _dataSource.createMonthlyRent(
      request: request,
    );
  }

  // ==========================================================================
  // GET BY ID
  // ==========================================================================

  @override
  Future<MonthlyRent?> getMonthlyRentById(
      String rentId,
      ) {
    return _dataSource.getMonthlyRentById(
      rentId,
    );
  }

  // ==========================================================================
  // GET BY UNIT + BILLING PERIOD
  // ==========================================================================

  @override
  Future<List<MonthlyRent>> getMonthlyRentsByUnitAndPeriod({
    required String unitId,
    required String ownerId,
    required DateTime billingPeriodStart,
  }) {
    return _dataSource.getMonthlyRentsByUnitAndPeriod(
      unitId: unitId,
      ownerId: ownerId,
      billingPeriodStart: billingPeriodStart,
    );
  }

  // ==========================================================================
  // UNIT HISTORY
  // ==========================================================================

  @override
  Future<List<MonthlyRent>>
  getMonthlyRentHistoryByUnitId({
    required String unitId,
    required String ownerId,
  }) {
    return _dataSource.getMonthlyRentHistoryByUnitId(
      unitId: unitId,
      ownerId: ownerId,
    );
  }

  // ==========================================================================
  // TENANT HISTORY
  // ==========================================================================

  @override
  Future<List<MonthlyRent>>
  getMonthlyRentHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  }) {
    return _dataSource.getMonthlyRentHistoryByTenantId(
      tenantId: tenantId,
      ownerId: ownerId,
    );
  }

  // ==========================================================================
  // GET BY BILLING PERIOD
  // ==========================================================================

  @override
  Future<List<MonthlyRent>> getMonthlyRentsByPeriod({
    required String ownerId,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
  }) {
    return _dataSource.getMonthlyRentsByPeriod(
      ownerId: ownerId,
      billingPeriodStart: billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd,
    );
  }
}