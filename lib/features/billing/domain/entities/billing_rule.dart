enum BillingChargeType {
  water,
  gas,
  garbage,
  serviceCharge,
  electricity,
  other,
}

enum BillingValueType { fixed, variable }

enum BillingScopeType { property, floor, unit, tenant }

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

  /// Checks whether this rule is active and eligible for the given billing month.
  ///
  /// - Fixed rules continue every month from [effectiveFrom] until [effectiveTo] (if set).
  /// - Variable rules without [effectiveTo] apply strictly to their [effectiveFrom] month,
  ///   so in the following month the Fixed rule automatically becomes effective again.
  bool isEffectiveForMonth(DateTime date) {
    if (!isActive) {
      return false;
    }

    final targetMonth = DateTime(date.year, date.month, 1);
    final startMonth = DateTime(effectiveFrom.year, effectiveFrom.month, 1);

    if (targetMonth.isBefore(startMonth)) {
      return false;
    }

    if (effectiveTo != null) {
      final endMonth = DateTime(effectiveTo!.year, effectiveTo!.month, 1);
      if (!targetMonth.isBefore(endMonth)) {
        return false;
      }
    } else if (valueType == BillingValueType.variable) {
      return targetMonth.year == startMonth.year &&
          targetMonth.month == startMonth.month;
    }

    return true;
  }

  /// Creates an immutable snapshot map to store inside generated monthly bills.
  Map<String, dynamic> toImmutableSnapshot() {
    return {
      'ruleId': id,
      'ownerId': ownerId,
      'propertyId': propertyId,
      'scopeType': scopeType.name,
      'scopeId': scopeId,
      'chargeType': chargeType.name,
      'valueType': valueType.name,
      'amount': amount,
      'title': title,
      'effectiveFrom': effectiveFrom.toIso8601String(),
      'effectiveTo': effectiveTo?.toIso8601String(),
    };
  }

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
      title: clearTitle ? null : title ?? this.title,
      effectiveFrom: effectiveFrom ?? this.effectiveFrom,
      effectiveTo: clearEffectiveTo ? null : effectiveTo ?? this.effectiveTo,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
