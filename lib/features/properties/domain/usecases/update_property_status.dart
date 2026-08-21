import '../entities/property.dart';
import '../repositories/property_repository.dart';

class UpdatePropertyStatus {
  final PropertyRepository _repository;

  UpdatePropertyStatus(this._repository);

  Future<Property> call({
    required Property property,
    required PropertyStatus status,
  }) async {
    final updatedProperty = property.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );

    return _repository.updateProperty(
      updatedProperty,
    );
  }
}