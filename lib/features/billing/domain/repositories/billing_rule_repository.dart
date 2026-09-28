import '../entities/billing_rule.dart';
import '../entities/create_billing_rule_request.dart';
import '../entities/update_billing_rule_request.dart';

abstract class BillingRuleRepository {
  Future<BillingRule> createBillingRule(
      CreateBillingRuleRequest request,
      );

  Future<BillingRule?> getBillingRuleById(
      String ruleId,
      );

  Future<List<BillingRule>> getPropertyBillingRules({
    required String ownerId,
    required String propertyId,
  });

  Future<List<BillingRule>> getBillingRulesForPeriod({
    required String ownerId,
    required String propertyId,
    required DateTime date,
  });

  Future<BillingRule> updateBillingRule(
      UpdateBillingRuleRequest request,
      );

  Future<void> deactivateBillingRule({
    required String ruleId,
    required String ownerId,
  });
}