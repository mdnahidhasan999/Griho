import 'property.dart';

class CreatePropertyRequest {
  final String name;
  final String? address;
  final String? description;

  final PropertyType type;

  final int numberOfFloors;

  const CreatePropertyRequest({
    required this.name,
    this.address,
    this.description,
    required this.type,
    required this.numberOfFloors,
  });
}
