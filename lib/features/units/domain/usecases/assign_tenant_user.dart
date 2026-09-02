import '../repositories/unit_repository.dart';

class AssignTenantUser {
  final UnitRepository _repository;

  const AssignTenantUser(this._repository);

  Future<void> call({
    required String unitId,
    required String tenantUserId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedTenantUserId = tenantUserId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (normalizedTenantUserId.isEmpty) {
      throw ArgumentError(
        'Tenant user ID cannot be empty.',
      );
    }

    await _repository.assignTenantUser(
      unitId: normalizedUnitId,
      tenantUserId: normalizedTenantUserId,
    );
  }
}