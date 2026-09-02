import '../entities/create_unit_request.dart';
import '../entities/unit.dart';

abstract interface class UnitRepository {
  Future<Unit?> getUnitById(String unitId);

  Future<List<Unit>> getUnitsByPropertyId(
      String propertyId,
      );

  Future<Unit> createUnit(
      CreateUnitRequest request,
      );

  Future<Unit> updateUnit(
      Unit unit,
      );

  Future<void> deleteUnit(
      String unitId,
      );

  Future<void> assignTenantUser({
    required String unitId,
    required String tenantUserId,
  });

  Future<void> removeTenantUser({
    required String unitId,
  });
}