enum RentRateSource {
  initial,
  property,
  floor,
  unit,
}

class RentRate {
  final String id;
  final String ownerId;
  final String propertyId;
  final String unitId;
  final String tenantId;
  final String? tenantUserId;

  /// Monthly rent amount.
  final double amount;

  /// Date from which this rent rate becomes effective.
  final DateTime effectiveFrom;

  /// Date until which this rent rate was effective.
  ///
  /// Null means this rate has no end date.
  final DateTime? effectiveTo;

  /// How this rate was created.
  final RentRateSource source;

  /// ID of the previous rent rate that this rate replaces.
  ///
  /// Null only for the initial rate.
  final String? previousRentRateId;

  /// ID of the next rent rate that replaces this rate.
  ///
  /// Null when this is currently the latest rate.
  ///
  /// When a future rent change is scheduled, this field points
  /// to the newly-created future rent rate.
  final String? nextRentRateId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const RentRate({
    required this.id,
    required this.ownerId,
    required this.propertyId,
    required this.unitId,
    required this.tenantId,
    this.tenantUserId,
    required this.amount,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.source,
    this.previousRentRateId,
    this.nextRentRateId,
    required this.createdAt,
    required this.updatedAt,
  });

  RentRate copyWith({
    String? id,
    String? ownerId,
    String? propertyId,
    String? unitId,
    String? tenantId,
    String? tenantUserId,
    double? amount,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    RentRateSource? source,
    String? previousRentRateId,
    String? nextRentRateId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearTenantUserId = false,
    bool clearEffectiveTo = false,
    bool clearPreviousRentRateId = false,
    bool clearNextRentRateId = false,
  }) {
    return RentRate(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      tenantUserId:
      clearTenantUserId
          ? null
          : tenantUserId ?? this.tenantUserId,
      amount: amount ?? this.amount,
      effectiveFrom:
      effectiveFrom ?? this.effectiveFrom,
      effectiveTo:
      clearEffectiveTo
          ? null
          : effectiveTo ?? this.effectiveTo,
      source: source ?? this.source,
      previousRentRateId:
      clearPreviousRentRateId
          ? null
          : previousRentRateId ??
          this.previousRentRateId,
      nextRentRateId:
      clearNextRentRateId
          ? null
          : nextRentRateId ??
          this.nextRentRateId,
      createdAt:
      createdAt ?? this.createdAt,
      updatedAt:
      updatedAt ?? this.updatedAt,
    );
  }
}