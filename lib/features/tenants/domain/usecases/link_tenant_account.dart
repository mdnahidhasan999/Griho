import '../entities/repositories/tenant_repository.dart';
import '../entities/tenant.dart';

class LinkTenantAccount {
  final TenantRepository _repository;

  const LinkTenantAccount({
    required this._repository,
  });

  Future<Tenant> call({
    required String tenantId,
    required String userId,
  }) {
    return _repository.linkTenantAccount(
      tenantId: tenantId,
      userId: userId,
    );
  }
}