import '../entities/create_monthly_rent_request.dart';
import '../entities/monthly_rent.dart';

abstract interface class MonthlyRentRepository {
  Future<MonthlyRent> createMonthlyRent(
      CreateMonthlyRentRequest request,
      );

  Future<MonthlyRent?> getMonthlyRentById(
      String rentId,
      );

  Future<MonthlyRent?> getMonthlyRentByUnitAndPeriod({
    required String unitId,
    required String ownerId,
    required DateTime billingPeriodStart,
  });

  Future<List<MonthlyRent>> getMonthlyRentHistoryByUnitId({
    required String unitId,
    required String ownerId,
  });

  Future<List<MonthlyRent>> getMonthlyRentHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  });

  Future<List<MonthlyRent>> getMonthlyRentsByPeriod({
    required String ownerId,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
  });
}