import '../entities/rent_rate.dart';
import '../repositories/rent_rate_repository.dart';

class GetTenantRentRateHistory {
  final RentRateRepository _repository;

  const GetTenantRentRateHistory({
    required this._repository,
  });

  Future<List<RentRate>> call({
    required String unitId,
    required String ownerId,
  }) async {
    final normalizedUnitId = unitId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    return _repository.getRentRateHistoryByUnitId(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
    );
  }
}