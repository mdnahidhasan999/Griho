import '../entities/repositories/tenant_repository.dart';
import '../entities/tenant.dart';

class GetActiveTenantsByUnitId {
  final TenantRepository _repository;

  const GetActiveTenantsByUnitId(
      this._repository,
      );

  Future<List<Tenant>> call(
      String unitId,
      ) {
    return _repository.getActiveTenantsByUnitId(
      unitId,
    );
  }
}