import '../entities/billing_rule.dart';
import '../entities/create_monthly_bill_request.dart';
import '../entities/monthly_bill.dart';
import '../repositories/billing_rule_repository.dart';
import '../repositories/monthly_bill_repository.dart';

/// Generates monthly bills for non-rent billing rules.
///
/// Rent is intentionally handled by the dedicated rent-generation flow
/// because rent requires tenancy-period resolution, proration and
/// historical rent-rate segmentation.
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
      throw ArgumentError(
        'Due date cannot be before billing period start.',
      );
    }

    if (targets.isEmpty) {
      return const [];
    }

    // =========================================================================
    // LOAD BILLING RULES
    // =========================================================================

    final rules = await _billingRuleRepository.getBillingRulesForPeriod(
      ownerId: normalizedOwnerId,
      propertyId: normalizedPropertyId,
      date: billingPeriodStart,
    );

    if (rules.isEmpty) {
      return const [];
    }

    // =========================================================================
    // GENERATE
    // =========================================================================

    final generatedBills = <MonthlyBill>[];

    for (final target in targets) {
      final normalizedTarget = target.normalized();

      if (normalizedTarget == null) {
        continue;
      }

      final applicableRules = _resolveRulesForTarget(
        rules: rules,
        target: normalizedTarget,
      );

      for (final rule in applicableRules) {
        final billType = _toMonthlyBillType(
          rule.chargeType,
        );

        // =====================================================================
        // RENT IS NOT GENERATED HERE
        // =====================================================================

        if (billType == MonthlyBillType.rent) {
          continue;
        }

        // =====================================================================
        // DUPLICATE READ CHECK
        // =====================================================================

        final existingBill = await _monthlyBillRepository
            .getMonthlyBillByUnitAndTenantAndPeriodAndType(
          ownerId: normalizedOwnerId,
          unitId: normalizedTarget.unitId,
          tenantId: normalizedTarget.tenantId,
          billingPeriodStart: billingPeriodStart,
          type: billType,
        );

        if (existingBill != null) {
          // Historical bills must never be replaced automatically.
          continue;
        }

        // =====================================================================
        // DETERMINE BILL VALUE
        // =====================================================================

        final amount = rule.amount;

        // Both Fixed and Variable bills are immediately payable.
        final status = MonthlyBillStatus.unpaid;

        // =====================================================================
        // CREATE REQUEST
        // =====================================================================

        final request = CreateMonthlyBillRequest(
          ownerId: normalizedOwnerId,
          propertyId: normalizedPropertyId,
          floorId: normalizedTarget.floorId,
          unitId: normalizedTarget.unitId,
          tenantId: normalizedTarget.tenantId,
          tenantUserId: normalizedTarget.tenantUserId,
          sourceRuleId: rule.id,
          type: billType,
          valueType: rule.valueType,
          amount: amount,
          billingPeriodStart: billingPeriodStart,
          billingPeriodEnd: billingPeriodEnd,
          dueDate: dueDate,
          status: status,
        );

        // =====================================================================
        // CREATE WITH TRANSACTION-SAFE DUPLICATE PROTECTION
        // =====================================================================

        try {
          final bill = await _monthlyBillRepository.createMonthlyBill(
            request: request,
          );

          generatedBills.add(bill);
        } on StateError catch (error) {
          // Another generation request may have created the same bill
          // after our read check but before this create.
          //
          // The datasource transaction is the final protection.
          //
          // Ignore only the known duplicate error.
          if (!_isDuplicateBillError(error)) {
            rethrow;
          }
        }
      }
    }

    return generatedBills;
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

        return _matchesScope(
          rule: rule,
          target: target,
        );
      }).toList();

      if (matchingRules.isEmpty) {
        continue;
      }

      matchingRules.sort((a, b) {
        // First: more specific scope wins.
        final priorityComparison = _scopePriority(
          b.scopeType,
        ).compareTo(
          _scopePriority(a.scopeType),
        );

        if (priorityComparison != 0) {
          return priorityComparison;
        }

        // Second: latest effectiveFrom wins.
        final effectiveFromComparison = b.effectiveFrom.compareTo(
          a.effectiveFrom,
        );

        if (effectiveFromComparison != 0) {
          return effectiveFromComparison;
        }

        // Third: Variable wins over Fixed when both start
        // in the same month and have the same scope.
        final valueTypeComparison = _valueTypePriority(
          b.valueType,
        ).compareTo(
          _valueTypePriority(a.valueType),
        );

        if (valueTypeComparison != 0) {
          return valueTypeComparison;
        }

        // Final deterministic tie-breaker.
        return a.id.compareTo(b.id);
      });

      result.add(matchingRules.first);
    }

    return result;
  }

  // ===========================================================================
  // SCOPE MATCHING
  // ===========================================================================

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

  // ===========================================================================
  // SCOPE PRIORITY
  // ===========================================================================

  int _scopePriority(BillingScopeType scope,) {
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

  int _valueTypePriority(BillingValueType valueType,) {
    switch (valueType) {
      case BillingValueType.fixed:
        return 1;

      case BillingValueType.variable:
        return 2;
    }
  }

  // ===========================================================================
  // BILL TYPE MAPPING
  // ===========================================================================

  MonthlyBillType _toMonthlyBillType(BillingChargeType type,) {
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

  // ===========================================================================
  // DUPLICATE ERROR DETECTION
  // ===========================================================================

  bool _isDuplicateBillError(StateError error,) {
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

  const MonthlyBillTarget({
    required this.floorId,
    required this.unitId,
    required this.tenantId,
    this.tenantUserId,
  });

  /// Returns a normalized target or null when a required ID is missing.
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

    return MonthlyBillTarget(
      floorId: normalizedFloorId,
      unitId: normalizedUnitId,
      tenantId: normalizedTenantId,
      tenantUserId:
      normalizedTenantUserId == null ||
          normalizedTenantUserId.isEmpty
          ? null
          : normalizedTenantUserId,
    );
  }
}