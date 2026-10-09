import 'billing_rule.dart';

class UpdateBillingRuleRequest {
  final String ruleId;
  final String ownerId;

  final BillingChargeType chargeType;
  final BillingValueType valueType;

  final double amount;

  final String? title;

  final DateTime effectiveFrom;
  final DateTime? effectiveTo;

  final bool isActive;

  const UpdateBillingRuleRequest({
    required this.ruleId,
    required this.ownerId,
    required this.chargeType,
    required this.valueType,
    required this.amount,
    this.title,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.isActive,
  });
}