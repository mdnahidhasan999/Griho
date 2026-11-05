import '../entities/billing_rule.dart';
import '../entities/create_monthly_bill_request.dart';
import '../entities/monthly_bill.dart';
import '../repositories/billing_rule_repository.dart';
import '../repositories/monthly_bill_repository.dart';
import '../services/billing_rule_resolver.dart';

class GenerateMonthlyBills {
  final BillingRuleRepository _billingRuleRepository;
  final MonthlyBillRepository _monthlyBillRepository;

  const GenerateMonthlyBills({
    required this._billingRuleRepository,
    required this._monthlyBillRepository,
  });

  Future<List<MonthlyBill>> call({
    required String ownerId,
    required String propertyId,
    required List<MonthlyBillTarget> targets,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
    required DateTime dueDate,
    BillingValueType? onlyValueType,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedPropertyId = propertyId.trim();

    // =========================================================================
    // VALIDATION
    // =========================================================================

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (!billingPeriodEnd.isAfter(billingPeriodStart)) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    if (dueDate.isBefore(billingPeriodStart)) {
      throw ArgumentError('Due date cannot be before billing period start.');
    }

    if (targets.isEmpty) {
      return const [];
    }

    // =========================================================================
    // 1. LOAD BILLING RULES FOR PERIOD
    // =========================================================================

    final rules = await _billingRuleRepository.getBillingRulesForPeriod(
      ownerId: normalizedOwnerId,
      propertyId: normalizedPropertyId,
      date: billingPeriodStart,
    );

    if (rules.isEmpty) {
      return const [];
    }

    // Filter rules strictly by Fixed (ongoing) vs Variable (single-month/bounded)
    final periodActiveRules = rules.where((rule) {
      return rule.isEffectiveForMonth(billingPeriodStart);
    }).toList();

    if (periodActiveRules.isEmpty) {
      return const [];
    }

    // =========================================================================
    // 2. SINGLE BATCH READ FOR DUPLICATE & OVERRIDE CHECK
    // =========================================================================

    final existingPeriodBills = await _monthlyBillRepository
        .getMonthlyBillsByPropertyAndPeriod(
          ownerId: normalizedOwnerId,
          propertyId: normalizedPropertyId,
          billingPeriodStart: billingPeriodStart,
        );

    final existingBillsByKey = <String, MonthlyBill>{
      for (final bill in existingPeriodBills)
        _buildBillKey(
          unitId: bill.unitId,
          tenantId: bill.tenantId,
          type: bill.type,
        ): bill,
    };

    // =========================================================================
    // 3. GENERATE MISSING BILLS OR APPLY VARIABLE OVERRIDES OVER FIXED BILLS
    // =========================================================================

    final generatedBills = <MonthlyBill>[];

    for (final target in targets) {
      final normalizedTarget = target.normalized();

      if (normalizedTarget == null) {
        continue;
      }

      final applicableRules = _resolveRulesForTarget(
        rules: periodActiveRules,
        propertyId: normalizedPropertyId,
        target: normalizedTarget,
      );

      final selectedRules = onlyValueType == null
          ? applicableRules
          : applicableRules
                .where((rule) => rule.valueType == onlyValueType)
                .toList();

      for (final rule in selectedRules) {
        final billType = _toMonthlyBillType(rule.chargeType);

        if (billType == MonthlyBillType.rent) {
          continue;
        }

        final candidateKey = _buildBillKey(
          unitId: normalizedTarget.unitId,
          tenantId: normalizedTarget.tenantId,
          type: billType,
        );

        final existingBill = existingBillsByKey[candidateKey];

        if (existingBill != null) {
          final canOverrideFixedBill =
              existingBill.status != MonthlyBillStatus.cancelled &&
              existingBill.valueType == BillingValueType.fixed &&
              rule.valueType == BillingValueType.variable &&
              rule.amount >= existingBill.paidAmount;

          final isReplacingCancelledBill =
              existingBill.status == MonthlyBillStatus.cancelled;

          if (!canOverrideFixedBill && !isReplacingCancelledBill) {
            continue;
          }
        }

        final request = CreateMonthlyBillRequest(
          ownerId: normalizedOwnerId,
          propertyId: normalizedPropertyId,
          floorId: normalizedTarget.floorId,
          unitId: normalizedTarget.unitId,
          tenantId: normalizedTarget.tenantId,
          tenantUserId: normalizedTarget.tenantUserId,
          tenancyHistoryId: normalizedTarget.tenancyHistoryId,
          sourceRuleId: rule.id,
          title: rule.title,
          ruleScopeType: rule.scopeType,
          ruleScopeId: rule.scopeId,
          ruleSnapshot: rule.toImmutableSnapshot(),
          type: billType,
          valueType: rule.valueType,
          amount: rule.amount,
          billingPeriodStart: billingPeriodStart,
          billingPeriodEnd: billingPeriodEnd,
          dueDate: dueDate,
          status: MonthlyBillStatus.unpaid,
        );

        try {
          final bill = await _monthlyBillRepository.createMonthlyBill(
            request: request,
          );

          existingBillsByKey[candidateKey] = bill;
          generatedBills.add(bill);
        } on StateError catch (error) {
          if (!_isDuplicateBillError(error)) {
            rethrow;
          }
        }
      }
    }

    return generatedBills;
  }

  String _buildBillKey({
    required String unitId,
    required String tenantId,
    required MonthlyBillType type,
  }) {
    return '${unitId.trim()}_${tenantId.trim()}_${type.name}';
  }

  List<BillingRule> _resolveRulesForTarget({
    required List<BillingRule> rules,
    required String propertyId,
    required MonthlyBillTarget target,
  }) {
    final result = <BillingRule>[];

    for (final chargeType in BillingChargeType.values) {
      final matchingRules = rules.where((rule) {
        if (rule.chargeType != chargeType) {
          return false;
        }

        return _matchesScope(
          rule: rule,
          propertyId: propertyId,
          target: target,
        );
      }).toList();

      if (matchingRules.isEmpty) {
        continue;
      }

      matchingRules.sort(BillingRuleResolver.compareRulesByPriority);

      result.add(matchingRules.first);
    }

    return result;
  }

  bool _matchesScope({
    required BillingRule rule,
    required String propertyId,
    required MonthlyBillTarget target,
  }) {
    switch (rule.scopeType) {
      case BillingScopeType.property:
        return rule.scopeId.trim().isEmpty || rule.scopeId.trim() == propertyId;

      case BillingScopeType.floor:
        return rule.scopeId.trim() == target.floorId;

      case BillingScopeType.unit:
        return rule.scopeId.trim() == target.unitId;

      case BillingScopeType.tenant:
        return rule.scopeId.trim() == target.tenantId;
    }
  }

  MonthlyBillType _toMonthlyBillType(BillingChargeType type) {
    switch (type) {
      case BillingChargeType.water:
        return MonthlyBillType.water;

      case BillingChargeType.gas:
        return MonthlyBillType.gas;

      case BillingChargeType.garbage:
        return MonthlyBillType.garbage;

      case BillingChargeType.serviceCharge:
        return MonthlyBillType.serviceCharge;

      case BillingChargeType.electricity:
        return MonthlyBillType.electricity;

      case BillingChargeType.other:
        return MonthlyBillType.other;
    }
  }

  bool _isDuplicateBillError(StateError error) {
    return error.message.toString().contains(
      'Monthly bill already exists for this '
      'tenant, bill type and billing period.',
    );
  }
}

class MonthlyBillTarget {
  final String floorId;
  final String unitId;
  final String tenantId;
  final String? tenantUserId;
  final String? tenancyHistoryId;

  const MonthlyBillTarget({
    required this.floorId,
    required this.unitId,
    required this.tenantId,
    this.tenantUserId,
    this.tenancyHistoryId,
  });

  MonthlyBillTarget? normalized() {
    final normalizedFloorId = floorId.trim();
    final normalizedUnitId = unitId.trim();
    final normalizedTenantId = tenantId.trim();

    if (normalizedFloorId.isEmpty ||
        normalizedUnitId.isEmpty ||
        normalizedTenantId.isEmpty) {
      return null;
    }

    final normalizedTenantUserId = tenantUserId?.trim();
    final normalizedTenancyHistoryId = tenancyHistoryId?.trim();

    return MonthlyBillTarget(
      floorId: normalizedFloorId,
      unitId: normalizedUnitId,
      tenantId: normalizedTenantId,
      tenantUserId:
          normalizedTenantUserId == null || normalizedTenantUserId.isEmpty
          ? null
          : normalizedTenantUserId,
      tenancyHistoryId:
          normalizedTenancyHistoryId == null ||
              normalizedTenancyHistoryId.isEmpty
          ? null
          : normalizedTenancyHistoryId,
    );
  }
}
