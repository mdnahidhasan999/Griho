import '../../domain/entities/create_monthly_bill_request.dart';
import '../../domain/entities/monthly_bill.dart';
import '../../domain/repositories/monthly_bill_repository.dart';
import '../datasources/monthly_bill_datasource.dart';

class MonthlyBillRepositoryImpl implements MonthlyBillRepository {
  final MonthlyBillDataSource _dataSource;

  MonthlyBillRepositoryImpl({required this._dataSource});

  @override
  Future<MonthlyBill> createMonthlyBill(CreateMonthlyBillRequest request) {
    return _dataSource.createMonthlyBill(request: request);
  }

  @override
  Future<MonthlyBill?> getMonthlyBillById(String billId) {
    return _dataSource.getMonthlyBillById(billId);
  }

  // ==========================================================================
  // UNIT + PERIOD
  // ==========================================================================

  @override
  Future<List<MonthlyBill>> getMonthlyBillsByUnitAndPeriod({
    required String ownerId,
    required String unitId,
    required DateTime billingPeriodStart,
  }) {
    return _dataSource.getMonthlyBillsByUnitAndPeriod(
      ownerId: ownerId,
      unitId: unitId,
      billingPeriodStart: billingPeriodStart,
    );
  }

  // ==========================================================================
  // UNIT + PERIOD + TYPE
  // ==========================================================================

  @override
  Future<MonthlyBill?> getMonthlyBillByUnitAndPeriodAndType({
    required String ownerId,
    required String unitId,
    required DateTime billingPeriodStart,
    required MonthlyBillType type,
  }) {
    return _dataSource.getMonthlyBillByUnitAndPeriodAndType(
      ownerId: ownerId,
      unitId: unitId,
      billingPeriodStart: billingPeriodStart,
      type: type,
    );
  }

  @override
  Future<List<MonthlyBill>> getMonthlyBillsByTenantAndPeriod({
    required String tenantUserId,
    required DateTime billingPeriodStart,
  }) {
    return _dataSource.getMonthlyBillsByTenantAndPeriod(
      tenantUserId: tenantUserId,
      billingPeriodStart: billingPeriodStart,
    );
  }

  @override
  Future<List<MonthlyBill>> getMonthlyBillHistoryByTenantUserId({
    required String tenantUserId,
  }) {
    return _dataSource.getMonthlyBillHistoryByTenantUserId(
      tenantUserId: tenantUserId,
    );
  }

  // ==========================================================================
  // PROPERTY + PERIOD
  // ==========================================================================

  @override
  Future<List<MonthlyBill>> getMonthlyBillsByPropertyAndPeriod({
    required String ownerId,
    required String propertyId,
    required DateTime billingPeriodStart,
  }) {
    return _dataSource.getMonthlyBillsByPropertyAndPeriod(
      ownerId: ownerId,
      propertyId: propertyId,
      billingPeriodStart: billingPeriodStart,
    );
  }

  // ==========================================================================
  // PROPERTY HISTORY
  // ==========================================================================

  @override
  Future<List<MonthlyBill>> getMonthlyBillHistoryByPropertyId({
    required String ownerId,
    required String propertyId,
  }) {
    return _dataSource.getMonthlyBillHistoryByPropertyId(
      ownerId: ownerId,
      propertyId: propertyId,
    );
  }

  // ==========================================================================
  // UPDATE AMOUNT
  // ==========================================================================

  @override
  Future<MonthlyBill?> updateMonthlyBillAmount({
    required String billId,
    required double amount,
  }) {
    return _dataSource.updateMonthlyBillAmount(billId: billId, amount: amount);
  }

  // ==========================================================================
  // CANCEL
  // ==========================================================================

  @override
  Future<MonthlyBill?> cancelMonthlyBill(String billId) {
    return _dataSource.cancelMonthlyBill(billId);
  }
}
