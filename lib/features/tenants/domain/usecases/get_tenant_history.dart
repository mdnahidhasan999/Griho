import '../entities/repositories/tenancy_history_repository.dart';
import '../entities/tenancy_history.dart';

class GetTenantHistory {
  final TenancyHistoryRepository _repository;

  const GetTenantHistory({
    required this._repository,
  });

  Future<List<TenancyHistory>> call({
    required String tenantId,
    required String ownerId,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    return _repository.getHistoryByTenantId(
      tenantId: normalizedTenantId,
      ownerId: normalizedOwnerId,
    );
  }
}