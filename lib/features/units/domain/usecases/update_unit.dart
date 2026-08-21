import '../entities/unit.dart';
import '../repositories/unit_repository.dart';

class UpdateUnit {
  final UnitRepository _repository;

  const UpdateUnit(this._repository);

  Future<Unit> call(
      Unit unit,
      ) async {
    if (unit.id.trim().isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (unit.propertyId.trim().isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (unit.floorNumber < 1) {
      throw ArgumentError(
        'Floor number must be at least 1.',
      );
    }

    if (unit.unitNumber.trim().isEmpty) {
      throw ArgumentError(
        'Unit number cannot be empty.',
      );
    }

    if (unit.monthlyRent != null &&
        unit.monthlyRent! < 0) {
      throw ArgumentError(
        'Monthly rent cannot be negative.',
      );
    }

    return _repository.updateUnit(unit);
  }
}