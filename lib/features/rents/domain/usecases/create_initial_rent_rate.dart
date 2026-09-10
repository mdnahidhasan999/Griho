import '../entities/create_rent_rate_request.dart';
import '../entities/rent_rate.dart';
import '../repositories/rent_rate_repository.dart';

class CreateInitialRentRate {
  final RentRateRepository _repository;

  const CreateInitialRentRate({
    required this._repository,
  });

  Future<RentRate> call(
      CreateRentRateRequest request,
      ) async {
    final ownerId = request.ownerId.trim();
    final propertyId = request.propertyId.trim();
    final unitId = request.unitId.trim();
    final tenantId = request.tenantId.trim();

    if (ownerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (propertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (unitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (tenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (request.amount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    return _repository.createInitialRentRate(
      CreateRentRateRequest(
        ownerId: ownerId,
        propertyId: propertyId,
        unitId: unitId,
        tenantId: tenantId,
        tenantUserId: request.tenantUserId?.trim(),
        amount: request.amount,
        effectiveFrom: request.effectiveFrom,
        source: RentRateSource.initial,
      ),
    );
  }
}