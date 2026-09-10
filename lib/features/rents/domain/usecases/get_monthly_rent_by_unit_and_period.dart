import '../entities/monthly_rent.dart';
import '../repositories/monthly_rent_repository.dart';

class GetMonthlyRentByUnitAndPeriod {
  final MonthlyRentRepository _repository;

  const GetMonthlyRentByUnitAndPeriod({
    required this._repository,
  });

  Future<MonthlyRent?> call({
    required String unitId,
    required String ownerId,
    required DateTime billingPeriodStart,
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

    return _repository.getMonthlyRentByUnitAndPeriod(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
      billingPeriodStart: billingPeriodStart,
    );
  }
}