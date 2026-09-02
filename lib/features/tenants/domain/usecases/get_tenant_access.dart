import '../entities/repositories/tenant_access_repository.dart';
import '../entities/tenant_access.dart';

class GetTenantAccess {
  final TenantAccessRepository _repository;

  const GetTenantAccess(this._repository);

  Future<TenantAccess?> call(String userId) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    return _repository.getTenantAccessByUserId(
      normalizedUserId,
    );
  }
}