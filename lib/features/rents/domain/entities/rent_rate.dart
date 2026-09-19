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

  /// Rent amount applicable to this unit.
  final double amount;

  /// Start of this rent-rate period.
  ///
  /// Rent rate is applicable from this date.
  final DateTime effectiveFrom;

  /// End of this rent-rate period.
  ///
  /// null means this is currently open-ended.
  ///
  /// Rent period follows:
  /// [effectiveFrom, effectiveTo)
  final DateTime? effectiveTo;

  final RentRateSource source;

  /// Previous rent rate of this unit.
  final String? previousRentRateId;

  /// Next rent rate of this unit.
  final String? nextRentRateId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const RentRate({
    required this.id,
    required this.ownerId,
    required this.propertyId,
    required this.unitId,
    required this.amount,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.source,
    this.previousRentRateId,
    this.nextRentRateId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns true when this rent rate applies at [dateTime].
  bool isApplicableAt(DateTime dateTime) {
    if (dateTime.isBefore(effectiveFrom)) {
      return false;
    }

    if (effectiveTo != null && !dateTime.isBefore(effectiveTo!)) {
      return false;
    }

    return true;
  }

  /// Whether this rent rate has no end date.
  bool get isOpenEnded => effectiveTo == null;

  RentRate copyWith({
    String? id,
    String? ownerId,
    String? propertyId,
    String? unitId,
    double? amount,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    RentRateSource? source,
    String? previousRentRateId,
    String? nextRentRateId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RentRate(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      amount: amount ?? this.amount,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: effectiveTo ?? this.effectiveTo,
      source: source ?? this.source,
      previousRentRateId:
      previousRentRateId ?? this.previousRentRateId,
      nextRentRateId: nextRentRateId ?? this.nextRentRateId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}