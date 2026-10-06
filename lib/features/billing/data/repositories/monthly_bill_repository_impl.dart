import '../../domain/entities/create_monthly_bill_request.dart';
import '../../domain/entities/monthly_bill.dart';
import '../../domain/repositories/monthly_bill_repository.dart';
import '../datasources/monthly_bill_datasource.dart';

class MonthlyBillRepositoryImpl implements MonthlyBillRepository {
  final MonthlyBillDataSource _dataSource;

  const MonthlyBillRepositoryImpl({
    required this._dataSource,
  });

  @override
  Future<MonthlyBill> createMonthlyBill({
    required CreateMonthlyBillRequest request,
  }) async {
    return _dataSource.createMonthlyBill(
      request: request,
    );
  }

  @override
  Future<MonthlyBill?> getMonthlyBillById({
    required String billId,
  }) async {
    return _dataSource.getMonthlyBillById(
      billId,
    );
  }

  @override
  Future<List<MonthlyBill>> getMonthlyBillsByUnitAndPeriod({
    required String ownerId,
    required String unitId,
    required DateTime billingPeriodStart,
  }) async {
    return _dataSource.getMonthlyBillsByUnitAndPeriod(
      ownerId: ownerId,
      unitId: unitId,
      billingPeriodStart: billingPeriodStart,
    );
  }

  @override
  Future<MonthlyBill?>
  getMonthlyBillByUnitAndTenantAndPeriodAndType({
    required String ownerId,
    required String unitId,
    required String tenantId,
    required DateTime billingPeriodStart,
    required MonthlyBillType type,
  }) async {
    return _dataSource
        .getMonthlyBillByUnitAndTenantAndPeriodAndType(
      ownerId: ownerId,
      unitId: unitId,
      tenantId: tenantId,
      billingPeriodStart: billingPeriodStart,
      type: type,
    );
  }

  @override
  Future<List<MonthlyBill>> getMonthlyBillsByTenantAndPeriod({
    required String tenantUserId,
    required DateTime billingPeriodStart,
  }) async {
    return _dataSource.getMonthlyBillsByTenantAndPeriod(
      tenantUserId: tenantUserId,
      billingPeriodStart: billingPeriodStart,
    );
  }

  @override
  Future<List<MonthlyBill>> getMonthlyBillHistoryByTenantUserId({
    required String tenantUserId,
  }) async {
    return _dataSource.getMonthlyBillHistoryByTenantUserId(
      tenantUserId: tenantUserId,
    );
  }

  @override
  Future<List<MonthlyBill>> getMonthlyBillsByPropertyAndPeriod({
    required String ownerId,
    required String propertyId,
    required DateTime billingPeriodStart,
  }) async {
    return _dataSource.getMonthlyBillsByPropertyAndPeriod(
      ownerId: ownerId,
      propertyId: propertyId,
      billingPeriodStart: billingPeriodStart,
    );
  }

  @override
  Future<List<MonthlyBill>> getMonthlyBillHistoryByPropertyId({
    required String ownerId,
    required String propertyId,
  }) async {
    return _dataSource.getMonthlyBillHistoryByPropertyId(
      ownerId: ownerId,
      propertyId: propertyId,
    );
  }

  @override
  Future<MonthlyBill?> updateMonthlyBillAmount({
    required String billId,
    required double amount,
  }) async {
    return _dataSource.updateMonthlyBillAmount(
      billId: billId,
      amount: amount,
    );
  }

  @override
  Future<MonthlyBill?> cancelMonthlyBill({
    required String billId,
  }) async {
    return _dataSource.cancelMonthlyBill(
      billId,
    );
  }
}