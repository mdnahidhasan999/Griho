import '../entities/rent_adjustment.dart';
import '../entities/rent_rate.dart';
import '../repositories/rent_rate_repository.dart';

class ChangeFloorRent {
  final RentRateRepository _repository;

  const ChangeFloorRent({
    required this._repository,
  });

  Future<List<RentRate>> call({
    required String propertyId,
    required int floorNumber,
    required String ownerId,
    required double amount,
    required RentAdjustmentType adjustmentType,
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

    if (floorNumber < 1) {
      throw ArgumentError(
        'Floor number must be at least 1.',
      );
    }

    if (amount <= 0) {
      throw ArgumentError(
        'Rent adjustment amount must be greater than zero.',
      );
    }

    return _repository.changeFloorRent(
      propertyId: normalizedPropertyId,
      floorNumber: floorNumber,
      ownerId: normalizedOwnerId,
      amount: amount,
      adjustmentType: adjustmentType,
      effectiveFrom: effectiveFrom,
    );
  }
}