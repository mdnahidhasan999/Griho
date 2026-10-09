import 'billing_rule.dart';

class CreateBillingRuleRequest {
  final String ownerId;
  final String propertyId;

  final BillingScopeType scopeType;
  final String scopeId;

  final BillingChargeType chargeType;
  final BillingValueType valueType;

  final double amount;

  final String? title;

  final DateTime effectiveFrom;
  final DateTime? effectiveTo;

  final bool isActive;

  const CreateBillingRuleRequest({
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
    this.isActive = true,
  });
}