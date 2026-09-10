import '../entities/rent_rate.dart';
import '../repositories/rent_rate_repository.dart';

class GetCurrentRentRate {
  final RentRateRepository _repository;

  const GetCurrentRentRate({
    required this._repository,
  });

  Future<RentRate?> call({
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

    return _repository.getCurrentRentRate(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
    );
  }
}