class CreateUnitRequest {
  final String propertyId;

  final int floorNumber;
  final String unitNumber;
  final String? name;

  const CreateUnitRequest({
    required this.propertyId,
    required this.floorNumber,
    required this.unitNumber,
    this.name,
  });
}