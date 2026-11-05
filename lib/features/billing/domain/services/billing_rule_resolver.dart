import '../entities/billing_rule.dart';
import '../entities/resolved_billing_rule.dart';

class BillingRuleResolver {
  const BillingRuleResolver();

  ResolvedBillingRule? resolve({
    required List<BillingRule> rules,
    required String propertyId,
    String? floorId,
    String? unitId,
    String? tenantId,
    required BillingChargeType chargeType,

    /// The billing period date for which the billing rule must be resolved.
    required DateTime effectiveAt,
  }) {
    final normalizedPropertyId = propertyId.trim();

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    final normalizedFloorId = _normalizeId(floorId);
    final normalizedUnitId = _normalizeId(unitId);
    final normalizedTenantId = _normalizeId(tenantId);

    final matchingRules = rules.where((rule) {
      if (rule.propertyId.trim() != normalizedPropertyId) {
        return false;
      }

      if (rule.chargeType != chargeType) {
        return false;
      }

      // Ensures inactive rules and expired Variable rules are excluded,
      // allowing Fixed rules to take effect again in subsequent months.
      if (!rule.isEffectiveForMonth(effectiveAt)) {
        return false;
      }

      return _matchesScope(
        rule: rule,
        propertyId: normalizedPropertyId,
        floorId: normalizedFloorId,
        unitId: normalizedUnitId,
        tenantId: normalizedTenantId,
      );
    }).toList();

    if (matchingRules.isEmpty) {
      return null;
    }

    matchingRules.sort(compareRulesByPriority);

    final selectedRule = matchingRules.first;

    return ResolvedBillingRule(rule: selectedRule, amount: selectedRule.amount);
  }

  /// Deterministic priority comparator shared across rule resolution:
  /// 1. Variable rules override Fixed rules for the target month.
  /// 2. More specific scopes (tenant > unit > floor > property) win.
  /// 3. Newer [effectiveFrom] wins.
  /// 4. More recently updated rule wins.
  static int compareRulesByPriority(BillingRule a, BillingRule b) {
    final valueTypeComparison = _valueTypePriority(
      b.valueType,
    ).compareTo(_valueTypePriority(a.valueType));

    if (valueTypeComparison != 0) {
      return valueTypeComparison;
    }

    final priorityComparison = _scopePriority(
      b.scopeType,
    ).compareTo(_scopePriority(a.scopeType));

    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final effectiveFromComparison = b.effectiveFrom.compareTo(a.effectiveFrom);

    if (effectiveFromComparison != 0) {
      return effectiveFromComparison;
    }

    final updatedAtComparison = b.updatedAt.compareTo(a.updatedAt);

    if (updatedAtComparison != 0) {
      return updatedAtComparison;
    }

    return a.id.compareTo(b.id);
  }

  // ==========================================================================
  // SCOPE MATCHING
  // ==========================================================================

  bool _matchesScope({
    required BillingRule rule,
    required String propertyId,
    required String? floorId,
    required String? unitId,
    required String? tenantId,
  }) {
    switch (rule.scopeType) {
      case BillingScopeType.property:
        return rule.scopeId.trim().isEmpty || rule.scopeId.trim() == propertyId;

      case BillingScopeType.floor:
        return _matchesId(rule.scopeId, floorId);

      case BillingScopeType.unit:
        return _matchesId(rule.scopeId, unitId);

      case BillingScopeType.tenant:
        return _matchesId(rule.scopeId, tenantId);
    }
  }

  bool _matchesId(String ruleId, String? targetId) {
    if (targetId == null) {
      return false;
    }

    return ruleId.trim() == targetId.trim();
  }

  // ==========================================================================
  // PRIORITY
  // ==========================================================================

  static int _scopePriority(BillingScopeType scopeType) {
    switch (scopeType) {
      case BillingScopeType.property:
        return 1;

      case BillingScopeType.floor:
        return 2;

      case BillingScopeType.unit:
        return 3;

      case BillingScopeType.tenant:
        return 4;
    }
  }

  static int _valueTypePriority(BillingValueType valueType) {
    switch (valueType) {
      case BillingValueType.fixed:
        return 1;

      case BillingValueType.variable:
        return 2;
    }
  }

  // ==========================================================================
  // ID NORMALIZATION
  // ==========================================================================

  String? _normalizeId(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }
}
