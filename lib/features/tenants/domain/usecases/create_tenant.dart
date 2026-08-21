import '../entities/create_tenant_request.dart';
import '../entities/repositories/tenant_repository.dart';
import '../entities/tenant.dart';

class CreateTenant {
  final TenantRepository _repository;

  const CreateTenant({
    required this._repository,
  });

  Future<Tenant> call(
      CreateTenantRequest request,
      ) {
    return _repository.createTenant(request);
  }
}