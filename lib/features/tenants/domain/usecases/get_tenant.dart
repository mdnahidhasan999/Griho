import '../entities/repositories/tenant_repository.dart';
import '../entities/tenant.dart';

class GetTenant {
  final TenantRepository _repository;

  const GetTenant({
    required this._repository,
  });

  Future<Tenant?> call(
      String tenantId,
      ) {
    return _repository.getTenantById(
      tenantId,
    );
  }
}