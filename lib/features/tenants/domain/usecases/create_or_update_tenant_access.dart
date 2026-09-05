import '../entities/repositories/tenant_access_repository.dart';
import '../entities/tenant_access.dart';

class CreateOrUpdateTenantAccess {
  final TenantAccessRepository _repository;

  const CreateOrUpdateTenantAccess(this._repository);

  Future<void> call(TenantAccess access) async {
    if (access.id.trim().isEmpty) {
      throw ArgumentError('Tenant access ID cannot be empty.');
    }

    if (access.userId.trim().isEmpty) {
      throw ArgumentError('Tenant user ID cannot be empty.');
    }

    if (access.tenantId.trim().isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    if (access.ownerId.trim().isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    if (access.propertyId.trim().isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (access.unitId.trim().isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    final invitationId = access.invitationId?.trim();

    if (invitationId != null && invitationId.isEmpty) {
      throw ArgumentError('Invitation ID cannot be empty.');
    }

    if (access.id.trim() != access.userId.trim()) {
      throw ArgumentError('Tenant access document ID must match the user ID.');
    }

    await _repository.createOrUpdateTenantAccess(access);
  }
}
