import '../../../../core/services/current_user_service.dart';

import '../../domain/entities/create_property_request.dart';
import '../../domain/entities/property.dart';
import '../../domain/repositories/property_repository.dart';

import '../datasources/property_datasource.dart';
import '../models/property_model.dart';

class PropertyRepositoryImpl implements PropertyRepository {
  final PropertyDataSource _dataSource;
  final CurrentUserService _currentUserService;

  const PropertyRepositoryImpl({
    required this._dataSource,
    required this._currentUserService,
  });

  @override
  Future<Property?> getPropertyById(String propertyId) async {
    return _dataSource.getPropertyById(propertyId);
  }

  @override
  Future<List<Property>> getPropertiesByOwnerId(String ownerId) async {
    return _dataSource.getPropertiesByOwnerId(ownerId);
  }

  @override
  Future<Property> createProperty(CreatePropertyRequest request) async {
    final ownerId = _currentUserService.requiredUid;

    return _dataSource.createProperty(
      ownerId: ownerId,
      name: request.name,
      address: request.address,
      description: request.description,
      type: request.type,
    );
  }

  @override
  Future<Property> updateProperty(Property property) async {
    final model = PropertyModel.fromEntity(property);

    return _dataSource.updateProperty(model);
  }

  @override
  Future<void> deleteProperty(String propertyId) async {
    await _dataSource.deleteProperty(propertyId);
  }
}
