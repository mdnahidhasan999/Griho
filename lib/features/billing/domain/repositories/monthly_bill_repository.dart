import '../entities/create_monthly_bill_request.dart';
import '../entities/monthly_bill.dart';

abstract interface class MonthlyBillRepository {
  // ==========================================================================
  // CREATE
  // ==========================================================================

  Future<MonthlyBill> createMonthlyBill(
      CreateMonthlyBillRequest request,
      );

  // ==========================================================================
  // BILL BY ID
  // ==========================================================================

  Future<MonthlyBill?> getMonthlyBillById(
      String billId,
      );

  // ==========================================================================
  // UNIT + PERIOD
  // ==========================================================================

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

  // ==========================================================================
  // TENANT + PERIOD
  // ==========================================================================

  Future<List<MonthlyBill>> getMonthlyBillsByTenantAndPeriod({
    required String tenantUserId,
    required DateTime billingPeriodStart,
  });

  // ==========================================================================
  // TENANT HISTORY
  // ==========================================================================

  Future<List<MonthlyBill>> getMonthlyBillHistoryByTenantUserId({
    required String tenantUserId,
  });

  // ==========================================================================
  // PROPERTY + PERIOD
  // ==========================================================================

  Future<List<MonthlyBill>> getMonthlyBillsByPropertyAndPeriod({
    required String ownerId,
    required String propertyId,
    required DateTime billingPeriodStart,
  });

  // ==========================================================================
  // PROPERTY HISTORY
  // ==========================================================================

  Future<List<MonthlyBill>> getMonthlyBillHistoryByPropertyId({
    required String ownerId,
    required String propertyId,
  });

  // ==========================================================================
  // UPDATE AMOUNT
  // ==========================================================================

  Future<MonthlyBill?> updateMonthlyBillAmount({
    required String billId,
    required double amount,
  });

  // ==========================================================================
  // CANCEL
  // ==========================================================================

  Future<MonthlyBill?> cancelMonthlyBill(
      String billId,
      );
}