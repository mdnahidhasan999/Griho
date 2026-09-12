import '../entities/create_rent_rate_request.dart';
import '../entities/rent_rate.dart';

abstract interface class RentRateRepository {
  // ============================================================
  // CREATE
  // ============================================================

  Future<RentRate> createInitialRentRate(
      CreateRentRateRequest request,
      );

  // ============================================================
  // CURRENT RENT — OWNER
  // ============================================================

  Future<RentRate?> getCurrentRentRate({
    required String unitId,
    required String ownerId,
  });

  // ============================================================
  // CURRENT RENT — TENANT
  // ============================================================

  Future<RentRate?> getCurrentRentRateForTenant({
    required String unitId,
    required String tenantUserId,
  });

  // ============================================================
  // APPLICABLE RENT RATE
  // ============================================================

  Future<RentRate?> getRentRateApplicableAt({
    required String unitId,
    required String ownerId,
    required DateTime effectiveAt,
  });

  // ============================================================
  // UNIT HISTORY
  // ============================================================

  Future<List<RentRate>> getRentRateHistoryByUnitId({
    required String unitId,
    required String ownerId,
  });

  // ============================================================
  // TENANT HISTORY
  // ============================================================

  Future<List<RentRate>> getRentRateHistoryByTenantId({
    required String tenantId,
    required String ownerId,
  });

  // ============================================================
  // CURRENT RATES BY FLOOR
  // ============================================================

  Future<List<RentRate>> getCurrentRentRatesByFloor({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
  });

  // ============================================================
  // CHANGE UNIT RENT
  // ============================================================

  Future<RentRate> changeUnitRent({
    required String unitId,
    required String tenantId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  });

  // ============================================================
  // CHANGE FLOOR RENT
  // ============================================================

  Future<List<RentRate>> changeFloorRent({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  });

  // ============================================================
  // CHANGE PROPERTY RENT
  // ============================================================

  Future<List<RentRate>> changePropertyRent({
    required String propertyId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  });
}