import '../entities/create_monthly_rent_request.dart';
import '../entities/monthly_rent.dart';

abstract interface class MonthlyRentRepository {
  // ==========================================================================
  // CREATE
  // ==========================================================================

  Future<MonthlyRent> createMonthlyRent(
      CreateMonthlyRentRequest request,
      );

  // ==========================================================================
  // GET BY ID
  // ==========================================================================

  Future<MonthlyRent?> getMonthlyRentById(
      String rentId,
      );

  // ==========================================================================
  // GET BY UNIT + BILLING PERIOD
  // ==========================================================================
  //
  // A single unit can have multiple MonthlyRent records in the same
  // billing month because:
  //
  // 1. Tenant can change during the month.
  // 2. Rent rate can change during the month.
  //
  // Therefore this must return all matching rent segments.
  //

  Future<List<MonthlyRent>> getMonthlyRentsByUnitAndPeriod({
    required String unitId,
    required String ownerId,
    required DateTime billingPeriodStart,
  });

  // ==========================================================================
  // UNIT HISTORY
  // ==========================================================================

  Future<List<MonthlyRent>> getMonthlyRentHistoryByUnitId({
    required String unitId,
    required String ownerId,
  });

  // ==========================================================================
  // TENANT HISTORY
  // ==========================================================================

  Future<List<MonthlyRent>> getMonthlyRentHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  });

  // ==========================================================================
  // GET BY BILLING PERIOD
  // ==========================================================================

  Future<List<MonthlyRent>> getMonthlyRentsByPeriod({
    required String ownerId,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
  });
}