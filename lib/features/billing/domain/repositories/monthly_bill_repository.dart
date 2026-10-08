import '../entities/create_monthly_bill_request.dart';
import '../entities/monthly_bill.dart';

abstract class MonthlyBillRepository {
  /// Creates a new monthly bill.
  ///
  /// Duplicate protection is enforced by the data source.
  Future<MonthlyBill> createMonthlyBill({
    required CreateMonthlyBillRequest request,
  });

  /// Gets a monthly bill by its document ID.
  Future<MonthlyBill?> getMonthlyBillById({
    required String billId,
  });

  /// Gets all bills for a specific unit and billing period.
  ///
  /// Multiple bills can exist for the same unit/month because:
  /// - different tenants may occupy the unit during the month;
  /// - multiple billing types exist.
  Future<List<MonthlyBill>> getMonthlyBillsByUnitAndPeriod({
    required String ownerId,
    required String unitId,
    required DateTime billingPeriodStart,
  });

  /// Gets one specific bill for:
  /// tenant + unit + billing period + type.
  ///
  /// Tenant ID is part of the identity because the same unit
  /// can have different tenants during the same calendar month.
  Future<MonthlyBill?>
  getMonthlyBillByUnitAndTenantAndPeriodAndType({
    required String ownerId,
    required String unitId,
    required String tenantId,
    required DateTime billingPeriodStart,
    required MonthlyBillType type,
  });

  /// Gets all bills for a tenant during a billing period.
  Future<List<MonthlyBill>> getMonthlyBillsByTenantAndPeriod({
    required String tenantUserId,
    required DateTime billingPeriodStart,
  });

  /// Gets the complete bill history for a tenant.
  Future<List<MonthlyBill>> getMonthlyBillHistoryByTenantUserId({
    required String tenantUserId,
  });

  /// Gets all bills for a property during a billing period.
  Future<List<MonthlyBill>> getMonthlyBillsByPropertyAndPeriod({
    required String ownerId,
    required String propertyId,
    required DateTime billingPeriodStart,
  });

  /// Gets the complete bill history for a property.
  Future<List<MonthlyBill>> getMonthlyBillHistoryByPropertyId({
    required String ownerId,
    required String propertyId,
  });


  /// Cancels/voids a monthly bill.
  Future<MonthlyBill?> cancelMonthlyBill({
    required String billId,
  });
}