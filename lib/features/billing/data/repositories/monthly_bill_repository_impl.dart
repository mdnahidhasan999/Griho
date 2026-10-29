import '../../../rents/domain/entities/monthly_rent.dart';
import '../../domain/entities/create_monthly_bill_request.dart';
import '../../domain/entities/monthly_bill.dart';
import '../../domain/repositories/monthly_bill_repository.dart';
import '../datasources/monthly_bill_datasource.dart';

class MonthlyBillRepositoryImpl implements MonthlyBillRepository {
  final MonthlyBillDataSource _dataSource;

  const MonthlyBillRepositoryImpl({required this._dataSource});

  @override
  Future<MonthlyBill> createMonthlyBill({
    required CreateMonthlyBillRequest request,
  }) {
    return _dataSource.createMonthlyBill(request: request);
  }

  @override
  Future<MonthlyBill?> getMonthlyBillById({required String billId}) {
    return _dataSource.getMonthlyBillById(billId);
  }

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

  @override
  Future<MonthlyBill?> getMonthlyBillByUnitAndTenantAndPeriodAndType({
    required String ownerId,
    required String unitId,
    required String tenantId,
    required DateTime billingPeriodStart,
    required MonthlyBillType type,
  }) {
    return _dataSource.getMonthlyBillByUnitAndTenantAndPeriodAndType(
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
  }) {
    return _dataSource.getMonthlyBillsByTenantAndPeriod(
      tenantUserId: tenantUserId,
      billingPeriodStart: billingPeriodStart,
    );
  }

  @override
  Future<List<MonthlyRent>> getMonthlyRentsByTenantAndPeriod({
    required String tenantUserId,
    required DateTime billingPeriodStart,
  }) {
    return _dataSource.getMonthlyRentsByTenantAndPeriod(
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

  @override
  Future<MonthlyBill?> cancelMonthlyBill({required String billId}) {
    return _dataSource.cancelMonthlyBill(billId);
  }
}
