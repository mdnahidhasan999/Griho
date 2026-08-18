import '../entities/property.dart';
import '../repositories/property_repository.dart';

class GetProperty {
  final PropertyRepository _repository;

  const GetProperty({
    required this._repository,
  });

  Future<Property?> call(
      String propertyId,
      ) async {
    return _repository.getPropertyById(
      propertyId,
    );
  }
}