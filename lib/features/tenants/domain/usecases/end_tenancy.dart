import '../entities/repositories/tenant_repository.dart';
import '../entities/tenant.dart';

class EndTenancy {
  final TenantRepository _repository;

  const EndTenancy({
    required this._repository,
  });

  Future<Tenant> call(String tenantId) async {
    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    return _repository.endTenancy(normalizedTenantId);
  }
}