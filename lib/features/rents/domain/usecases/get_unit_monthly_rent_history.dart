import '../entities/monthly_rent.dart';
import '../repositories/monthly_rent_repository.dart';

class GetUnitMonthlyRentHistory {
  final MonthlyRentRepository _repository;

  const GetUnitMonthlyRentHistory({
    required this._repository,
  });

  Future<List<MonthlyRent>> call({
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

    return _repository.getMonthlyRentHistoryByUnitId(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
    );
  }
}