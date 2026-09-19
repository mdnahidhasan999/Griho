import '../entities/create_rent_rate_request.dart';
import '../entities/rent_adjustment.dart';
import '../entities/rent_rate.dart';

abstract interface class RentRateRepository {
  // ============================================================
  // CREATE INITIAL RENT RATE
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
  // APPLICABLE RENT RATE
  // ============================================================

  Future<RentRate?> getRentRateApplicableAt({
    required String unitId,
    required String ownerId,
    required DateTime effectiveAt,
  });

  // ============================================================
  // UNIT RENT HISTORY
  // ============================================================

  Future<List<RentRate>> getRentRateHistoryByUnitId({
    required String unitId,
    required String ownerId,
  });

  // ============================================================
  // CURRENT RENT RATES BY FLOOR
  // ============================================================

  /// Returns current rent rates for ALL units on the floor,
  /// including vacant units.
  Future<List<RentRate>> getCurrentRentRatesByFloor({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
  });

  // ============================================================
  // CURRENT RENT RATES BY PROPERTY
  // ============================================================

  /// Returns current rent rates for ALL units in the property,
  /// including vacant units.
  Future<List<RentRate>> getCurrentRentRatesByProperty({
    required String propertyId,
    required String ownerId,
  });

  // ============================================================
  // CHANGE UNIT RENT
  // ============================================================

  /// Changes rent for one Unit.
  ///
  /// tenantId is intentionally NOT required because rent belongs
  /// to the Unit, not to the Tenant.
  Future<RentRate> changeUnitRent({
    required String unitId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  });

  // ============================================================
  // CHANGE FLOOR RENT
  // ============================================================

  /// Applies the adjustment to every Unit on the floor,
  /// occupied or vacant.
  Future<List<RentRate>> changeFloorRent({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  });

  // ============================================================
  // CHANGE PROPERTY RENT
  // ============================================================

  /// Applies the adjustment to every Unit in the property,
  /// occupied or vacant.
  Future<List<RentRate>> changePropertyRent({
    required String propertyId,
    required String ownerId,
    required double amount,
    required RentAdjustmentType adjustmentType,
    required DateTime effectiveFrom,
  });
}