import '../entities/repositories/tenancy_history_repository.dart';
import '../entities/tenancy_history.dart';

class GetMyTenancyHistory {
  final TenancyHistoryRepository _repository;

  const GetMyTenancyHistory({
    required this._repository,
  });

  Future<List<TenancyHistory>> call({
    required String tenantUserId,
  }) async {
    final normalizedTenantUserId =
    tenantUserId.trim();

    if (normalizedTenantUserId.isEmpty) {
      throw ArgumentError(
        'Tenant user ID cannot be empty.',
      );
    }

    return _repository.getHistoryByTenantUserId(
      tenantUserId: normalizedTenantUserId,
    );
  }
}