import '../../data/datasources/unit_datasource.dart';
import '../../data/models/unit_model.dart';
import '../../domain/entities/create_unit_request.dart';
import '../../domain/entities/unit.dart';
import '../../domain/repositories/unit_repository.dart';

class UnitRepositoryImpl implements UnitRepository {
  final UnitDataSource _dataSource;

  UnitRepositoryImpl({
    required this._dataSource,
  });

  // ============================================================
  // GET UNIT BY ID
  // ============================================================

  @override
  Future<Unit?> getUnitById(String unitId) {
    return _dataSource.getUnitById(unitId);
  }

  // ============================================================
  // GET UNITS BY PROPERTY
  // ============================================================

  @override
  Future<List<Unit>> getUnitsByPropertyId(String propertyId) {
    return _dataSource.getUnitsByPropertyId(propertyId);
  }

// ============================================================
// GET ALL UNITS BY FLOOR
// ============================================================

  @override
  Future<List<Unit>> getUnitsByFloor({
    required String propertyId,
    required int floorNumber,
  }) {
    return _dataSource.getUnitsByFloor(
      propertyId: propertyId,
      floorNumber: floorNumber,
    );
  }

  // ============================================================
  // GET OCCUPIED UNITS BY PROPERTY
  // ============================================================

  @override
  Future<List<Unit>> getOccupiedUnitsByProperty({
    required String propertyId,
  }) {
    return _dataSource.getOccupiedUnitsByProperty(
      propertyId: propertyId,
    );
  }

  // ============================================================
  // GET OCCUPIED UNITS BY FLOOR
  // ============================================================

  @override
  Future<List<Unit>> getOccupiedUnitsByFloor({
    required String propertyId,
    required int floorNumber,
  }) {
    return _dataSource.getOccupiedUnitsByFloor(
      propertyId: propertyId,
      floorNumber: floorNumber,
    );
  }

  // ============================================================
  // CREATE UNIT
  // ============================================================

  @override
  Future<Unit> createUnit(CreateUnitRequest request,) {
    return _dataSource.createUnit(
      request: request,
    );
  }

  // ============================================================
  // UPDATE UNIT
  // ============================================================

  @override
  Future<Unit> updateUnit(Unit unit,) {
    final model = UnitModel(
      id: unit.id,
      propertyId: unit.propertyId,
      floorNumber: unit.floorNumber,
      unitNumber: unit.unitNumber,
      name: unit.name,
      status: unit.status,
      tenantUserId: unit.tenantUserId,
      createdAt: unit.createdAt,
      updatedAt: unit.updatedAt,
    );

    return _dataSource.updateUnit(model);
  }

  // ============================================================
  // DELETE UNIT
  // ============================================================

  @override
  Future<void> deleteUnit(String unitId,) {
    return _dataSource.deleteUnit(unitId);
  }

  // ============================================================
  // ASSIGN TENANT USER
  // ============================================================

  @override
  Future<void> assignTenantUser({
    required String unitId,
    required String tenantUserId,
  }) {
    return _dataSource.assignTenantUser(
      unitId: unitId,
      tenantUserId: tenantUserId,
    );
  }

  // ============================================================
  // REMOVE TENANT USER
  // ============================================================

  @override
  Future<void> removeTenantUser({
    required String unitId,
  }) {
    return _dataSource.removeTenantUser(
      unitId: unitId,
    );
  }
}