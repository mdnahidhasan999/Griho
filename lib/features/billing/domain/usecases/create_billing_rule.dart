import '../entities/billing_rule.dart';
import '../entities/create_billing_rule_request.dart';
import '../repositories/billing_rule_repository.dart';

class CreateBillingRule {
  final BillingRuleRepository _repository;

  const CreateBillingRule({
    required this._repository,
  });

  Future<BillingRule> call(CreateBillingRuleRequest request,) async {
    final ownerId = request.ownerId.trim();
    final propertyId = request.propertyId.trim();
    final scopeId = request.scopeId.trim();
    final title = request.title?.trim();

    // =========================================================================
    // BASIC VALIDATION
    // =========================================================================

    if (ownerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (propertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (scopeId.isEmpty) {
      throw ArgumentError(
        'Billing scope ID cannot be empty.',
      );
    }

    // =========================================================================
    // OTHER CHARGE TITLE
    // =========================================================================

    if (request.chargeType == BillingChargeType.other &&
        (title == null || title.isEmpty)) {
      throw ArgumentError(
        'A title is required for the Other billing type.',
      );
    }

    // =========================================================================
    // FIXED / VARIABLE
    // =========================================================================

    switch (request.valueType) {
      case BillingValueType.fixed:
        if (request.amount == null) {
          throw ArgumentError(
            'Fixed billing amount is required.',
          );
        }

        if (request.amount! < 0) {
          throw ArgumentError(
            'Fixed billing amount cannot be negative.',
          );
        }

      case BillingValueType.variable:
        if (request.amount != null) {
          throw ArgumentError(
            'Variable billing rules cannot contain a fixed amount.',
          );
        }
    }


    if (request.effectiveTo != null &&
        !request.effectiveTo!.isAfter(
          request.effectiveFrom,
        )) {
      throw ArgumentError(
        'Effective end date must be after '
            'the effective start date.',
      );
    }


    return _repository.createBillingRule(
      request,
    );
  }
}