enum BillingChargeType {
  water,
  gas,
  garbage,
  serviceCharge,
  electricity,
  other,
}

enum BillingValueType {
  fixed,
  variable,
}

enum BillingScopeType {
  property,
  floor,
  unit,
  tenant,
}

class BillingRule {
  final String id;

  final String ownerId;
  final String propertyId;

  /// Property, floor, unit or tenant.
  final BillingScopeType scopeType;

  /// The ID of the property/floor/unit/tenant
  /// depending on [scopeType].
  final String scopeId;

  final BillingChargeType chargeType;
  final BillingValueType valueType;

  /// Required for fixed charges.
  ///
  /// For variable charges this can be null.
  final double? amount;

  /// Optional custom name for "other" charges.
  final String? title;

  final DateTime effectiveFrom;
  final DateTime? effectiveTo;

  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BillingRule({
    required this.id,
    required this.ownerId,
    required this.propertyId,
    required this.scopeType,
    required this.scopeId,
    required this.chargeType,
    required this.valueType,
    required this.amount,
    this.title,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  BillingRule copyWith({
    String? id,
    String? ownerId,
    String? propertyId,
    BillingScopeType? scopeType,
    String? scopeId,
    BillingChargeType? chargeType,
    BillingValueType? valueType,
    double? amount,
    String? title,
    DateTime? effectiveFrom,
    DateTime? effectiveTo,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearAmount = false,
    bool clearTitle = false,
    bool clearEffectiveTo = false,
  }) {
    return BillingRule(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      scopeType: scopeType ?? this.scopeType,
      scopeId: scopeId ?? this.scopeId,
      chargeType: chargeType ?? this.chargeType,
      valueType: valueType ?? this.valueType,
      amount: clearAmount ? null : amount ?? this.amount,
      title: clearTitle ? null : title ?? this.title,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo:
      clearEffectiveTo ? null : effectiveTo ?? this.effectiveTo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}