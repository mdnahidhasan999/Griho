import '../entities/create_unit_request.dart';
import '../entities/unit.dart';

abstract interface class UnitRepository {
  // ============================================================
  // GET UNIT BY ID
  // ============================================================

  Future<Unit?> getUnitById(String unitId);

  // ============================================================
  // GET UNITS BY PROPERTY
  // ============================================================

  Future<List<Unit>> getUnitsByPropertyId(String propertyId);

  // ============================================================
  // GET OCCUPIED UNITS BY PROPERTY
  // ============================================================

  Future<List<Unit>> getOccupiedUnitsByProperty({
    required String propertyId,
  });

  // ============================================================
  // GET OCCUPIED UNITS BY FLOOR
  // ============================================================

  Future<List<Unit>> getOccupiedUnitsByFloor({
    required String propertyId,
    required int floorNumber,
  });

  // ============================================================
  // CREATE UNIT
  // ============================================================

  Future<Unit> createUnit(CreateUnitRequest request);

  // ============================================================
  // UPDATE UNIT
  // ============================================================

  Future<Unit> updateUnit(Unit unit);

  // ============================================================
  // DELETE UNIT
  // ============================================================

  Future<void> deleteUnit(String unitId);

  // ============================================================
  // ASSIGN TENANT USER
  // ============================================================

  Future<void> assignTenantUser({
    required String unitId,
    required String tenantUserId,
  });

  // ============================================================
  // REMOVE TENANT USER
  // ============================================================

  Future<void> removeTenantUser({
    required String unitId,
  });
}