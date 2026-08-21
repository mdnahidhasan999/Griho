import '../entities/unit.dart';
import '../repositories/unit_repository.dart';

class GetUnitsByPropertyId {
  final UnitRepository _repository;

  const GetUnitsByPropertyId(this._repository);

  Future<List<Unit>> call(
      String propertyId,
      ) async {
    if (propertyId.trim().isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    return _repository.getUnitsByPropertyId(
      propertyId,
    );
  }
}