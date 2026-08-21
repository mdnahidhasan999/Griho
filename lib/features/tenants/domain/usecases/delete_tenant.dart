import '../entities/repositories/tenant_repository.dart';

class DeleteTenant {
  final TenantRepository _repository;

  const DeleteTenant({required this._repository});

  Future<void> call(String tenantId) {
    return _repository.deleteTenant(tenantId);
  }
}
