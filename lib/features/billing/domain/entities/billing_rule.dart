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

  /// Amount assigned to this billing rule.
  ///
  /// Fixed:
  /// The amount recurs according to the rule's effective period.
  ///
  /// Variable:
  /// The amount applies only to the selected effective month.
  final double amount;

  /// Optional custom title.
  ///
  /// Required by the UI for [BillingChargeType.other].
  final String? title;

  /// Start of the rule's effective period.
  final DateTime effectiveFrom;

  /// End of the rule's effective period.
  ///
  /// This is exclusive.
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
      amount: amount ?? this.amount,
      title: clearTitle
          ? null
          : title ?? this.title,
      effectiveFrom:
      effectiveFrom ?? this.effectiveFrom,
      effectiveTo: clearEffectiveTo
          ? null
          : effectiveTo ?? this.effectiveTo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}