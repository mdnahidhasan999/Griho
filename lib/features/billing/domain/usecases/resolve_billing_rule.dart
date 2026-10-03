import '../entities/billing_rule.dart';
import '../entities/resolved_billing_rule.dart';
import '../services/billing_rule_resolver.dart';

class ResolveBillingRule {
  final BillingRuleResolver resolver;

  const ResolveBillingRule({
    required this.resolver,
  });

  ResolvedBillingRule? call({
    required List<BillingRule> rules,
    required String propertyId,
    String? floorId,
    String? unitId,
    String? tenantId,
    required BillingChargeType chargeType,
    required DateTime effectiveAt,
  }) {
    return resolver.resolve(
      rules: rules,
      propertyId: propertyId,
      floorId: floorId,
      unitId: unitId,
      tenantId: tenantId,
      chargeType: chargeType,
      effectiveAt: effectiveAt,
    );
  }
}