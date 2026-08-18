import '../repositories/property_repository.dart';

class DeleteProperty {
  final PropertyRepository _repository;

  const DeleteProperty({
    required this._repository,
  });

  Future<void> call(
      String propertyId,
      ) async {
    await _repository.deleteProperty(
      propertyId,
    );
  }
}