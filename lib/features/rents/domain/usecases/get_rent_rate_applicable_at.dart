import '../entities/rent_rate.dart';
import '../repositories/rent_rate_repository.dart';

class GetRentRateApplicableAt {
  final RentRateRepository _repository;

  const GetRentRateApplicableAt({
    required this._repository,
  });

  Future<RentRate?> call({
    required String unitId,
    required String ownerId,
    required DateTime effectiveAt,
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

    return _repository.getRentRateApplicableAt(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
      effectiveAt: effectiveAt,
    );
  }
}