import '../repositories/unit_repository.dart';

class RemoveTenantUser {
  final UnitRepository _repository;

  const RemoveTenantUser(this._repository);

  Future<void> call({
    required String unitId,
  }) async {
    final normalizedUnitId = unitId.trim();

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    await _repository.removeTenantUser(
      unitId: normalizedUnitId,
    );
  }
}