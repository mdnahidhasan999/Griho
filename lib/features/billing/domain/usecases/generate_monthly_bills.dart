import '../entities/billing_rule.dart';
import '../entities/create_monthly_bill_request.dart';
import '../entities/monthly_bill.dart';
import '../repositories/billing_rule_repository.dart';
import '../repositories/monthly_bill_repository.dart';

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
      return _isRuleEligibleForPeriod(
        rule: rule,
        billingPeriodStart: billingPeriodStart,
      );
    }).toList();

    if (periodActiveRules.isEmpty) {
      return const [];
    }

    // =========================================================================
    // 2. SINGLE BATCH READ FOR DUPLICATE PROTECTION (SAVES N*M FIREBASE READS)
    // =========================================================================

    final existingPeriodBills = await _monthlyBillRepository
        .getMonthlyBillsByPropertyAndPeriod(
          ownerId: normalizedOwnerId,
          propertyId: normalizedPropertyId,
          billingPeriodStart: billingPeriodStart,
        );

    final existingBillKeys = <String>{
      for (final bill in existingPeriodBills)
        _buildBillKey(
          unitId: bill.unitId,
          tenantId: bill.tenantId,
          type: bill.type,
        ),
    };

    // =========================================================================
    // 3. GENERATE MISSING BILLS ONLY
    // =========================================================================

    final generatedBills = <MonthlyBill>[];

    for (final target in targets) {
      final normalizedTarget = target.normalized();

      if (normalizedTarget == null) {
        continue;
      }

      final applicableRules = _resolveRulesForTarget(
        rules: periodActiveRules,
        target: normalizedTarget,
      );

      for (final rule in applicableRules) {
        final billType = _toMonthlyBillType(rule.chargeType);

        if (billType == MonthlyBillType.rent) {
          continue;
        }

        final candidateKey = _buildBillKey(
          unitId: normalizedTarget.unitId,
          tenantId: normalizedTarget.tenantId,
          type: billType,
        );

        // O(1) In-Memory Duplicate Check (No extra Firestore read needed!)
        if (existingBillKeys.contains(candidateKey)) {
          continue;
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

          existingBillKeys.add(candidateKey);
          generatedBills.add(bill);
        } on StateError catch (error) {
          if (!_isDuplicateBillError(error)) {
            rethrow;
          }
          existingBillKeys.add(candidateKey);
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

  /// Ensures Fixed rules continue every month while Variable rules only run
  /// for their target month (unless an explicit effectiveTo range is set).
  bool _isRuleEligibleForPeriod({
    required BillingRule rule,
    required DateTime billingPeriodStart,
  }) {
    if (!rule.isActive) {
      return false;
    }

    final targetMonth = DateTime(
      billingPeriodStart.year,
      billingPeriodStart.month,
      1,
    );
    final startMonth = DateTime(
      rule.effectiveFrom.year,
      rule.effectiveFrom.month,
      1,
    );

    if (targetMonth.isBefore(startMonth)) {
      return false;
    }

    if (rule.effectiveTo != null) {
      final endMonth = DateTime(
        rule.effectiveTo!.year,
        rule.effectiveTo!.month,
        1,
      );
      if (!targetMonth.isBefore(endMonth)) {
        return false;
      }
    } else if (rule.valueType == BillingValueType.variable) {
      // A variable bill without an explicit end date is strictly for its effectiveFrom month
      return targetMonth.year == startMonth.year &&
          targetMonth.month == startMonth.month;
    }

    return true;
  }

  List<BillingRule> _resolveRulesForTarget({
    required List<BillingRule> rules,
    required MonthlyBillTarget target,
  }) {
    final result = <BillingRule>[];

    for (final chargeType in BillingChargeType.values) {
      final matchingRules = rules.where((rule) {
        if (rule.chargeType != chargeType) {
          return false;
        }

        return _matchesScope(rule: rule, target: target);
      }).toList();

      if (matchingRules.isEmpty) {
        continue;
      }

      matchingRules.sort((a, b) {
        final priorityComparison = _scopePriority(
          b.scopeType,
        ).compareTo(_scopePriority(a.scopeType));

        if (priorityComparison != 0) {
          return priorityComparison;
        }

        final effectiveFromComparison = b.effectiveFrom.compareTo(
          a.effectiveFrom,
        );

        if (effectiveFromComparison != 0) {
          return effectiveFromComparison;
        }

        final valueTypeComparison = _valueTypePriority(
          b.valueType,
        ).compareTo(_valueTypePriority(a.valueType));

        if (valueTypeComparison != 0) {
          return valueTypeComparison;
        }

        return a.id.compareTo(b.id);
      });

      result.add(matchingRules.first);
    }

    return result;
  }

  bool _matchesScope({
    required BillingRule rule,
    required MonthlyBillTarget target,
  }) {
    switch (rule.scopeType) {
      case BillingScopeType.property:
        return true;

      case BillingScopeType.floor:
        return rule.scopeId == target.floorId;

      case BillingScopeType.unit:
        return rule.scopeId == target.unitId;

      case BillingScopeType.tenant:
        return rule.scopeId == target.tenantId;
    }
  }

  int _scopePriority(BillingScopeType scope) {
    switch (scope) {
      case BillingScopeType.property:
        return 1;

      case BillingScopeType.floor:
        return 2;

      case BillingScopeType.unit:
        return 3;

      case BillingScopeType.tenant:
        return 4;
    }
  }

  int _valueTypePriority(BillingValueType valueType) {
    switch (valueType) {
      case BillingValueType.fixed:
        return 1;

      case BillingValueType.variable:
        return 2;
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
