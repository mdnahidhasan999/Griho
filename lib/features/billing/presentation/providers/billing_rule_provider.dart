import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/billing_rule_datasource.dart';
import '../../data/repositories/billing_rule_repository_impl.dart';
import '../../domain/entities/billing_rule.dart';
import '../../domain/entities/update_billing_rule_request.dart';
import '../../domain/repositories/billing_rule_repository.dart';
import '../../domain/services/billing_rule_resolver.dart';
import '../../domain/usecases/create_billing_rule.dart';
import '../../domain/usecases/resolve_billing_rule.dart';

final billingRuleDataSourceProvider =
Provider<BillingRuleDataSource>((ref) {
  return BillingRuleDataSource();
});

final billingRuleRepositoryProvider =
Provider<BillingRuleRepository>((ref) {
  return BillingRuleRepositoryImpl(
    dataSource: ref.read(
      billingRuleDataSourceProvider,
    ),
  );
});

final billingRuleResolverProvider =
Provider<BillingRuleResolver>((ref) {
  return const BillingRuleResolver();
});

final createBillingRuleProvider =
Provider<CreateBillingRule>((ref) {
  return CreateBillingRule(
    repository: ref.read(
      billingRuleRepositoryProvider,
    ),
  );
});

final resolveBillingRuleProvider =
Provider<ResolveBillingRule>((ref) {
  return ResolveBillingRule(
    resolver: ref.read(
      billingRuleResolverProvider,
    ),
  );
});

final propertyBillingRulesProvider =
FutureProvider.family<
    List<BillingRule>,
    ({
    String ownerId,
    String propertyId,
    })>((ref, params) async {
  final repository = ref.read(
    billingRuleRepositoryProvider,
  );

  return repository.getPropertyBillingRules(
    ownerId: params.ownerId,
    propertyId: params.propertyId,
  );
});


final updateBillingRuleProvider =
Provider<Future<BillingRule> Function(
    UpdateBillingRuleRequest request,
    )>((ref) {
  final repository =
  ref.watch(billingRuleRepositoryProvider);

  return repository.updateBillingRule;
});



final deactivateBillingRuleProvider =
Provider<Future<void> Function({
required String ruleId,
required String ownerId,
})>((ref) {
  final repository =
  ref.watch(billingRuleRepositoryProvider);

  return repository.deactivateBillingRule;
});



