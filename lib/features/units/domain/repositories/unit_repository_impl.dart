import '../../data/datasources/unit_datasource.dart';
import '../../data/models/unit_model.dart';
import '../../domain/entities/create_unit_request.dart';
import '../../domain/entities/unit.dart';
import '../../domain/repositories/unit_repository.dart';

class UnitRepositoryImpl implements UnitRepository {
  final UnitDataSource _dataSource;

  const UnitRepositoryImpl({required this._dataSource});

  @override
  Future<Unit?> getUnitById(String unitId) async {
    return _dataSource.getUnitById(unitId);
  }

  @override
  Future<List<Unit>> getUnitsByPropertyId(String propertyId) async {
    return _dataSource.getUnitsByPropertyId(propertyId);
  }

  @override
  Future<Unit> createUnit(CreateUnitRequest request) async {
    return _dataSource.createUnit(request: request);
  }

  @override
  Future<Unit> updateUnit(Unit unit) async {
    final model = UnitModel.fromEntity(unit);

    return _dataSource.updateUnit(model);
  }

  @override
  Future<void> deleteUnit(String unitId) async {
    await _dataSource.deleteUnit(unitId);
  }
}
