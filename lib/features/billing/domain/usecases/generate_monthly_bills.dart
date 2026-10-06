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

  /// Generates non-rent monthly bills for all supplied targets.
  ///
  /// Rent is intentionally NOT generated here.
  ///
  /// Rent has its own generation flow because rent depends on:
  /// - tenancy period
  /// - prorated days
  /// - historical rent rates
  /// - rent-rate changes inside a billing month
  ///
  /// Fixed billing rules create a normal unpaid bill.
  ///
  /// Variable billing rules create a pending bill because the
  /// actual amount is not known at generation time.
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

    final rules = await _billingRuleRepository.getBillingRulesForPeriod(
      ownerId: normalizedOwnerId,
      propertyId: normalizedPropertyId,
      date: billingPeriodStart,
    );

    if (rules.isEmpty) {
      return const [];
    }

    final generatedBills = <MonthlyBill>[];

    for (final target in targets) {
      final applicableRules = _resolveRulesForTarget(
        rules: rules,
        target: target,
      );

      for (final rule in applicableRules) {
        final billType = _toMonthlyBillType(rule.chargeType);

        // Rent is handled separately by GenerateMonthlyRent.
        if (billType == MonthlyBillType.rent) {
          continue;
        }

        final existingBill = await _monthlyBillRepository
            .getMonthlyBillByUnitAndTenantAndPeriodAndType(
              ownerId: normalizedOwnerId,
              unitId: target.unitId,
              tenantId: target.tenantId,
              billingPeriodStart: billingPeriodStart,
              type: billType,
            );

        // This is an optimization/readability check.
        //
        // The actual duplicate protection remains inside
        // MonthlyBillDataSource.createMonthlyBill(), which
        // uses a Firestore transaction.
        if (existingBill != null) {
          continue;
        }

        final isVariable = rule.valueType == BillingValueType.variable;

        final amount = isVariable ? 0.0 : (rule.amount ?? 0.0);

        final status = isVariable
            ? MonthlyBillStatus.pending
            : MonthlyBillStatus.unpaid;

        final request = CreateMonthlyBillRequest(
          ownerId: normalizedOwnerId,
          propertyId: normalizedPropertyId,
          floorId: target.floorId,
          unitId: target.unitId,
          tenantId: target.tenantId,
          tenantUserId: target.tenantUserId,
          sourceRuleId: rule.id,
          type: billType,
          valueType: rule.valueType,
          amount: amount,
          billingPeriodStart: billingPeriodStart,
          billingPeriodEnd: billingPeriodEnd,
          dueDate: dueDate,
          status: status,
        );

        try {
          final bill = await _monthlyBillRepository.createMonthlyBill(
            request: request,
          );

          generatedBills.add(bill);
        } on StateError catch (error) {
          // Another generation request may have created the
          // same bill between our read check and the transaction.
          //
          // Do not create a second bill.
          //
          // We only ignore the known duplicate error. Other
          // StateError values are rethrown.
          if (!_isDuplicateBillError(error)) {
            rethrow;
          }
        }
      }
    }

    return generatedBills;
  }

  // ==========================================================================
  // RESOLVE RULES FOR TARGET
  // ==========================================================================

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

      matchingRules.sort(
        (a, b) =>
            _scopePriority(b.scopeType).compareTo(_scopePriority(a.scopeType)),
      );

      result.add(matchingRules.first);
    }

    return result;
  }

  // ==========================================================================
  // SCOPE MATCHING
  // ==========================================================================

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

  // ==========================================================================
  // BILL TYPE MAPPING
  // ==========================================================================

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

  // ==========================================================================
  // DUPLICATE ERROR DETECTION
  // ==========================================================================

  bool _isDuplicateBillError(StateError error) {
    return error.message.toString().contains(
      'Monthly bill already exists for this '
      'tenant, bill type and billing period.',
    );
  }
}

// ==============================================================================
// MONTHLY BILL TARGET
// ==============================================================================

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
}
