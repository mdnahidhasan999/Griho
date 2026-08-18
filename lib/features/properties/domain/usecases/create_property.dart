import '../entities/create_property_request.dart';
import '../entities/property.dart';
import '../repositories/property_repository.dart';

class CreateProperty {
  final PropertyRepository _repository;

  const CreateProperty({
    required this._repository,
  });

  Future<Property> call(
      CreatePropertyRequest request,
      ) async {
    return _repository.createProperty(
      request,
    );
  }
}