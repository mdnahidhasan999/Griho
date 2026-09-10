enum RentRateSource {
  initial,
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
  /// Null means this is the current rate.
  final DateTime? effectiveTo;

  /// How this rate was created.
  final RentRateSource source;

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
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearTenantUserId = false,
    bool clearEffectiveTo = false,
  }) {
    return RentRate(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      tenantUserId:
      clearTenantUserId ? null : tenantUserId ?? this.tenantUserId,
      amount: amount ?? this.amount,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo:
      clearEffectiveTo ? null : effectiveTo ?? this.effectiveTo,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}