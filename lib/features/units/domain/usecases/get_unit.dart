import '../entities/unit.dart';
import '../repositories/unit_repository.dart';

class GetUnit {
  final UnitRepository _repository;

  const GetUnit(this._repository);

  Future<Unit?> call(String unitId) async {
    final id = unitId.trim();

    if (id.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    return _repository.getUnitById(id);
  }
}
