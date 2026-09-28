enum BillingRuleScope {
  property,
  floor,
  unit,
  tenant,
}

enum BillingType {
  water,
  gas,
  garbage,
  serviceCharge,
  electricity,
  other,
}

enum BillingAmountType {
  fixed,
  variable,
}

class BillingRule {
  final String id;

  final String ownerId;
  final String propertyId;

  /// Required only for floor/unit/tenant scoped rules.
  final String? floorId;
  final String? unitId;
  final String? tenantId;

  final BillingRuleScope scope;
  final BillingType type;
  final BillingAmountType amountType;

  /// Used when amountType == fixed.
  final double? amount;

  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  const BillingRule({
    required this.id,
    required this.ownerId,
    required this.propertyId,
    this.floorId,
    this.unitId,
    this.tenantId,
    required this.scope,
    required this.type,
    required this.amountType,
    this.amount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  BillingRule copyWith({
    String? id,
    String? ownerId,
    String? propertyId,
    String? floorId,
    String? unitId,
    String? tenantId,
    BillingRuleScope? scope,
    BillingType? type,
    BillingAmountType? amountType,
    double? amount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearFloorId = false,
    bool clearUnitId = false,
    bool clearTenantId = false,
    bool clearAmount = false,
  }) {
    return BillingRule(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      floorId: clearFloorId ? null : floorId ?? this.floorId,
      unitId: clearUnitId ? null : unitId ?? this.unitId,
      tenantId: clearTenantId ? null : tenantId ?? this.tenantId,
      scope: scope ?? this.scope,
      type: type ?? this.type,
      amountType: amountType ?? this.amountType,
      amount: clearAmount ? null : amount ?? this.amount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}