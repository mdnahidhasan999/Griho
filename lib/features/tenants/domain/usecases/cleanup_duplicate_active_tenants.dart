import '../entities/repositories/tenant_repository.dart';

class CleanupDuplicateActiveTenants {
  final TenantRepository _repository;

  const CleanupDuplicateActiveTenants(
      this._repository,
      );

  Future<void> call({
    required String unitId,
    required String ownerId,
    required String keepTenantId,
  }) {
    return _repository.cleanupDuplicateActiveTenants(
      unitId: unitId,
      ownerId: ownerId,
      keepTenantId: keepTenantId,
    );
  }
}