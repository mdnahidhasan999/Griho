import '../entities/repositories/tenant_access_repository.dart';

class DeleteTenantAccess {
  final TenantAccessRepository _repository;

  const DeleteTenantAccess(this._repository);

  Future<void> call(String userId) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return;
    }

    await _repository.deleteTenantAccess(
      normalizedUserId,
    );
  }
}