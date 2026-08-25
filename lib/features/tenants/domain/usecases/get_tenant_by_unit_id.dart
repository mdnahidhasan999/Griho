import '../entities/repositories/tenant_repository.dart';
import '../entities/tenant.dart';

class GetTenantByUnitId {
  final TenantRepository _repository;

  const GetTenantByUnitId(
      this._repository,
      );

  Future<Tenant?> call(String unitId) {
    return _repository.getTenantByUnitId(
      unitId,
    );
  }
}