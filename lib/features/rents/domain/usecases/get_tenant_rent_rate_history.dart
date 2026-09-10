import '../entities/rent_rate.dart';
import '../repositories/rent_rate_repository.dart';

class GetTenantRentRateHistory {
  final RentRateRepository _repository;

  const GetTenantRentRateHistory({
    required this._repository,
  });

  Future<List<RentRate>> call({
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

    return _repository.getRentRateHistoryByTenantId(
      tenantId: normalizedTenantId,
      ownerId: normalizedOwnerId,
    );
  }
}