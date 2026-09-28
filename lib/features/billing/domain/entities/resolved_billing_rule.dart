import 'billing_rule.dart';

class ResolvedBillingRule {
  final BillingRule rule;

  /// The amount configured by the selected rule.
  ///
  /// For fixed billing this contains the configured amount.
  /// For variable billing this may be null until the
  /// actual monthly amount is entered.
  final double? amount;

  const ResolvedBillingRule({
    required this.rule,
    required this.amount,
  });

  bool get isFixed =>
      rule.valueType == BillingValueType.fixed;

  bool get isVariable =>
      rule.valueType == BillingValueType.variable;
}