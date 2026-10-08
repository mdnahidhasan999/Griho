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

    /// The date for which the billing rule must be resolved.
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
      if (!rule.isActive) {
        return false;
      }

      if (rule.propertyId != normalizedPropertyId) {
        return false;
      }

      if (rule.chargeType != chargeType) {
        return false;
      }

      if (!_isEffectiveAt(rule: rule, date: effectiveAt)) {
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

    // =========================================================================
    // RULE PRIORITY
    // =========================================================================
    //
    // More specific scope always wins:
    //
    // tenant > unit > floor > property
    //
    // If two rules have the same scope, the latest effectiveFrom wins.
    //
    // This is important for monthly variable overrides:
    //
    // Fixed Water:
    //   effectiveFrom = 2026-09-01
    //
    // Variable Water:
    //   effectiveFrom = 2026-10-01
    //   effectiveTo   = 2026-11-01
    //
    // During October both can be active.
    // The October variable rule wins because it has the later effectiveFrom.
    //
    // On November 1 the variable rule is no longer effective, so the fixed
    // rule becomes the selected rule again.
    // =========================================================================

    matchingRules.sort((a, b) {
      final priorityComparison = _priority(
        b.scopeType,
      ).compareTo(_priority(a.scopeType));

      if (priorityComparison != 0) {
        return priorityComparison;
      }

      return b.effectiveFrom.compareTo(a.effectiveFrom);
    });

    final selectedRule = matchingRules.first;

    return ResolvedBillingRule(rule: selectedRule, amount: selectedRule.amount);
  }

  // ==========================================================================
  // EFFECTIVE DATE
  // ==========================================================================

  bool _isEffectiveAt({required BillingRule rule, required DateTime date}) {
    if (date.isBefore(rule.effectiveFrom)) {
      return false;
    }

    // effectiveTo is EXCLUSIVE.
    //
    // Example:
    //
    // effectiveFrom = 2026-10-01
    // effectiveTo   = 2026-11-01
    //
    // 2026-10-01 → effective
    // 2026-10-31 → effective
    // 2026-11-01 → NOT effective
    if (rule.effectiveTo != null && !date.isBefore(rule.effectiveTo!)) {
      return false;
    }

    return true;
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
        return rule.scopeId == propertyId;

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

  int _priority(BillingScopeType scopeType) {
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
