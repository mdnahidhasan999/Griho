import '../entities/rent_rate.dart';
import '../repositories/rent_rate_repository.dart';

class ChangePropertyRent {
  final RentRateRepository _repository;

  const ChangePropertyRent({
    required this._repository,
  });

  Future<List<RentRate>> call({
    required String propertyId,
    required String ownerId,
    required double amount,
    required DateTime effectiveFrom,
  }) async {
    final normalizedPropertyId =
    propertyId.trim();

    final normalizedOwnerId =
    ownerId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
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

    return _repository.changePropertyRent(
      propertyId: normalizedPropertyId,
      ownerId: normalizedOwnerId,
      amount: amount,
      effectiveFrom: effectiveFrom,
    );
  }
}