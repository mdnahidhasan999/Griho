import '../repositories/unit_repository.dart';

class DeleteUnit {
  final UnitRepository _repository;

  const DeleteUnit(this._repository);

  Future<void> call(
      String unitId,
      ) async {
    if (unitId.trim().isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    await _repository.deleteUnit(
      unitId,
    );
  }
}