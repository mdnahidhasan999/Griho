import '../entities/billing_rule.dart';
import '../entities/create_billing_rule_request.dart';
import '../repositories/billing_rule_repository.dart';

class CreateBillingRule {
  final BillingRuleRepository _repository;

  const CreateBillingRule({
    required this._repository,
  });

  Future<BillingRule> call(
      CreateBillingRuleRequest request,
      ) async {
    if (request.ownerId.trim().isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (request.propertyId.trim().isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (request.scopeId.trim().isEmpty) {
      throw ArgumentError(
        'Billing scope ID cannot be empty.',
      );
    }

    if (request.valueType == BillingValueType.fixed) {
      if (request.amount == null || request.amount! < 0) {
        throw ArgumentError(
          'Fixed billing amount must be zero or greater.',
        );
      }
    }

    if (request.valueType == BillingValueType.variable &&
        request.amount != null &&
        request.amount! < 0) {
      throw ArgumentError(
        'Billing amount cannot be negative.',
      );
    }

    if (request.effectiveTo != null &&
        request.effectiveTo!.isBefore(
          request.effectiveFrom,
        )) {
      throw ArgumentError(
        'Effective end date cannot be before start date.',
      );
    }

    return _repository.createBillingRule(
      request,
    );
  }
}