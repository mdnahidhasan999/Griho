import '../entities/property.dart';
import '../repositories/property_repository.dart';

class UpdateProperty {
  final PropertyRepository _repository;

  const UpdateProperty({
    required this._repository,
  });

  Future<Property> call(
      Property property,
      ) async {
    return _repository.updateProperty(
      property,
    );
  }
}