import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/create_billing_rule_request.dart';
import '../../domain/entities/update_billing_rule_request.dart';
import '../../domain/repositories/billing_rule_repository.dart';
import '../datasources/billing_rule_datasource.dart';

class BillingRuleRepositoryImpl
    implements BillingRuleRepository {
  final BillingRuleDataSource _dataSource;

  BillingRuleRepositoryImpl({
    required this._dataSource,
  });

  @override
  Future<BillingRule> createBillingRule(
      CreateBillingRuleRequest request,
      ) {
    return _dataSource.createBillingRule(
      request: request,
    );
  }

  @override
  Future<BillingRule?> getBillingRuleById(
      String ruleId,
      ) {
    return _dataSource.getBillingRuleById(
      ruleId,
    );
  }

  @override
  Future<List<BillingRule>> getPropertyBillingRules({
    required String ownerId,
    required String propertyId,
  }) {
    return _dataSource.getPropertyBillingRules(
      ownerId: ownerId,
      propertyId: propertyId,
    );
  }

  @override
  Future<List<BillingRule>> getBillingRulesForPeriod({
    required String ownerId,
    required String propertyId,
    required DateTime date,
  }) {
    return _dataSource.getBillingRulesForPeriod(
      ownerId: ownerId,
      propertyId: propertyId,
      date: date,
    );
  }

  @override
  Future<BillingRule> updateBillingRule(
      UpdateBillingRuleRequest request,
      ) {
    return _dataSource.updateBillingRule(
      request: request,
    );
  }

  @override
  Future<void> deactivateBillingRule({
    required String ruleId,
    required String ownerId,
  }) {
    return _dataSource.deactivateBillingRule(
      ruleId: ruleId,
      ownerId: ownerId,
    );
  }
}