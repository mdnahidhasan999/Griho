import '../entities/property.dart';
import '../repositories/property_repository.dart';

class GetProperties {
  final PropertyRepository _repository;

  const GetProperties({
    required this._repository,
  });

  Future<List<Property>> call(
      String ownerId,
      ) async {
    return _repository.getPropertiesByOwnerId(
      ownerId,
    );
  }
}