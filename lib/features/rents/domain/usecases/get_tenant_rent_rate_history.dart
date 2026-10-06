import '../entities/rent_rate.dart';
import '../repositories/rent_rate_repository.dart';

class GetTenantRentRateHistory {
  final RentRateRepository _repository;

  const GetTenantRentRateHistory({
    required this._repository,
  });

  Future<List<RentRate>> call({
    required String ownerId,
    required String tenantId,
    required String unitId,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedTenantId = tenantId.trim();
    final normalizedUnitId = unitId.trim();

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    // Rent rates belong to a unit, not to a tenant.
    //
    // tenantId is intentionally validated here because this
    // use case is called while generating a tenant's rent,
    // but the historical rate source remains the unit history.
    return _repository.getRentRateHistoryByUnitId(
      ownerId: normalizedOwnerId,
      unitId: normalizedUnitId,
    );
  }
}