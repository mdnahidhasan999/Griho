import '../entities/rent_rate.dart';
import '../repositories/rent_rate_repository.dart';

class ChangeUnitRent {
  final RentRateRepository _repository;

  const ChangeUnitRent({
    required this._repository,
  });

  Future<RentRate> call({
    required String unitId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
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

    if (amount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    return _repository.changeUnitRent(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
      amount: amount,
      effectiveFrom: effectiveFrom,
    );
  }
}