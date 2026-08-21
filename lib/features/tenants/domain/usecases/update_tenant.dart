import '../entities/repositories/tenant_repository.dart';
import '../entities/tenant.dart';

class UpdateTenant {
  final TenantRepository _repository;

  const UpdateTenant({
    required this._repository,
  });

  Future<Tenant> call(
      Tenant tenant,
      ) {
    return _repository.updateTenant(
      tenant,
    );
  }
}