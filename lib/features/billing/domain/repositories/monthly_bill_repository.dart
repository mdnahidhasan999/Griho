import '../entities/create_monthly_bill_request.dart';
import '../entities/monthly_bill.dart';

abstract interface class MonthlyBillRepository {
  Future<MonthlyBill> createMonthlyBill(
      CreateMonthlyBillRequest request,
      );

  Future<MonthlyBill?> getMonthlyBillById(
      String billId,
      );

  Future<List<MonthlyBill>> getMonthlyBillsByUnitAndPeriod({
    required String ownerId,
    required String unitId,
    required DateTime billingPeriodStart,
  });

  // ==========================================================================
  // UNIT + PERIOD + TYPE
  // ==========================================================================

  Future<MonthlyBill?> getMonthlyBillByUnitAndPeriodAndType({
    required String ownerId,
    required String unitId,
    required DateTime billingPeriodStart,
    required MonthlyBillType type,
  });

  Future<List<MonthlyBill>> getMonthlyBillsByTenantAndPeriod({
    required String ownerId,
    required String tenantId,
    required DateTime billingPeriodStart,
  });

  Future<List<MonthlyBill>> getMonthlyBillHistoryByTenantId({
    required String ownerId,
    required String tenantId,
  });

  Future<List<MonthlyBill>> getMonthlyBillsByPropertyAndPeriod({
    required String ownerId,
    required String propertyId,
    required DateTime billingPeriodStart,
  });

  Future<List<MonthlyBill>> getMonthlyBillHistoryByPropertyId({
    required String ownerId,
    required String propertyId,
  });

  Future<MonthlyBill?> updateMonthlyBillAmount({
    required String billId,
    required double amount,
  });

  Future<MonthlyBill?> cancelMonthlyBill(
      String billId,
      );
}