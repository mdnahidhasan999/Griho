import 'rent_rate.dart';

class CreateRentRateRequest {
  final String ownerId;
  final String propertyId;
  final String unitId;
  final String tenantId;
  final String? tenantUserId;
  final double amount;
  final DateTime effectiveFrom;
  final RentRateSource source;

  /// Null only when creating the initial rent rate.
  final String? previousRentRateId;

  const CreateRentRateRequest({
    required this.ownerId,
    required this.propertyId,
    required this.unitId,
    required this.tenantId,
    this.tenantUserId,
    required this.amount,
    required this.effectiveFrom,
    required this.source,
    this.previousRentRateId,
  });
}