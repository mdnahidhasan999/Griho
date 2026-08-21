import '../entities/create_unit_request.dart';
import '../entities/unit.dart';
import '../repositories/unit_repository.dart';

class CreateUnit {
  final UnitRepository _repository;

  const CreateUnit(this._repository);

  Future<Unit> call(
      CreateUnitRequest request,
      ) async {
    return _repository.createUnit(
      request,
    );
  }
}