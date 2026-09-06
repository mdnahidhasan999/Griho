import '../entities/repositories/tenancy_history_repository.dart';
import '../entities/tenancy_history.dart';

class GetUnitHistory {
  final TenancyHistoryRepository _repository;

  const GetUnitHistory({
    required this._repository,
  });

  Future<List<TenancyHistory>> call({
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

    return _repository.getHistoryByUnitId(
      unitId: normalizedUnitId,
      ownerId: normalizedOwnerId,
    );
  }
}