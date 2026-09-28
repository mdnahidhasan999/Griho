import '../../domain/entities/create_monthly_bill_request.dart';
import '../../domain/entities/monthly_bill.dart';
import '../../domain/repositories/monthly_bill_repository.dart';
import '../datasources/monthly_bill_datasource.dart';

class MonthlyBillRepositoryImpl
    implements MonthlyBillRepository {
  final MonthlyBillDataSource _dataSource;

  MonthlyBillRepositoryImpl({
    required this._dataSource,
  });

  @override
  Future<MonthlyBill> createMonthlyBill(
      CreateMonthlyBillRequest request,
      ) {
    return _dataSource.createMonthlyBill(
      request: request,
    );
  }

  @override
  Future<MonthlyBill?> getMonthlyBillById(
      String billId,
      ) {
    return _dataSource.getMonthlyBillById(
      billId,
    );
  }

  @override
  Future<List<MonthlyBill>>
  getMonthlyBillsByUnitAndPeriod({
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
  Future<List<MonthlyBill>>
  getMonthlyBillsByTenantAndPeriod({
    required String ownerId,
    required String tenantId,
    required DateTime billingPeriodStart,
  }) {
    return _dataSource.getMonthlyBillsByTenantAndPeriod(
      ownerId: ownerId,
      tenantId: tenantId,
      billingPeriodStart: billingPeriodStart,
    );
  }

  @override
  Future<List<MonthlyBill>>
  getMonthlyBillHistoryByTenantId({
    required String ownerId,
    required String tenantId,
  }) {
    return _dataSource.getMonthlyBillHistoryByTenantId(
      ownerId: ownerId,
      tenantId: tenantId,
    );
  }

  @override
  Future<List<MonthlyBill>>
  getMonthlyBillsByPropertyAndPeriod({
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
  Future<List<MonthlyBill>>
  getMonthlyBillHistoryByPropertyId({
    required String ownerId,
    required String propertyId,
  }) {
    return _dataSource.getMonthlyBillHistoryByPropertyId(
      ownerId: ownerId,
      propertyId: propertyId,
    );
  }

  @override
  Future<MonthlyBill?> updateMonthlyBillAmount({
    required String billId,
    required double amount,
  }) {
    return _dataSource.updateMonthlyBillAmount(
      billId: billId,
      amount: amount,
    );
  }

  @override
  Future<MonthlyBill?> cancelMonthlyBill(
      String billId,
      ) {
    return _dataSource.cancelMonthlyBill(
      billId,
    );
  }
}