import '../entities/create_property_request.dart';
import '../entities/property.dart';

abstract interface class PropertyRepository {
  Future<Property?> getPropertyById(String propertyId);

  Future<List<Property>> getPropertiesByOwnerId(String ownerId);

  Future<Property> createProperty(
      CreatePropertyRequest request,
      );

  Future<Property> updateProperty(Property property);

  Future<void> deleteProperty(String propertyId);
}