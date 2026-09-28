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

  /// Generates monthly bills for all active tenants/units
  /// that have applicable billing rules.
  ///
  /// Fixed rules:
  ///   amount comes directly from the rule.
  ///
  /// Variable rules:
  ///   amount starts at 0 and can be updated later.
  ///
  /// Existing monthly bills are skipped.
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
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (!billingPeriodEnd.isAfter(
      billingPeriodStart,
    )) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    if (dueDate.isBefore(
      billingPeriodStart,
    )) {
      throw ArgumentError(
        'Due date cannot be before billing period start.',
      );
    }

    if (targets.isEmpty) {
      return const [];
    }

    final rules =
    await _billingRuleRepository.getBillingRulesForPeriod(
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
        final existingBill =
        await _monthlyBillRepository
            .getMonthlyBillByUnitAndPeriodAndType(
          ownerId: normalizedOwnerId,
          unitId: target.unitId,
          billingPeriodStart: billingPeriodStart,
          type: _toMonthlyBillType(
            rule.chargeType,
          ),
        );

        if (existingBill != null) {
          continue;
        }

        final double amount = rule.valueType ==
            BillingValueType.fixed
            ? (rule.amount ?? 0.0)
            : 0.0;

        final request = CreateMonthlyBillRequest(
          ownerId: normalizedOwnerId,
          propertyId: normalizedPropertyId,
          floorId: target.floorId,
          unitId: target.unitId,
          tenantId: target.tenantId,
          tenantUserId: target.tenantUserId,
          sourceRuleId: rule.id,
          type: _toMonthlyBillType(
            rule.chargeType,
          ),
          valueType: rule.valueType,
          amount: amount,
          billingPeriodStart:
          billingPeriodStart,
          billingPeriodEnd:
          billingPeriodEnd,
          dueDate: dueDate,
          status: amount > 0
              ? MonthlyBillStatus.unpaid
              : MonthlyBillStatus.unpaid,
        );

        final bill =
        await _monthlyBillRepository
            .createMonthlyBill(request);

        generatedBills.add(bill);
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

    final chargeTypes =
        BillingChargeType.values;

    for (final chargeType in chargeTypes) {
      final matchingRules = rules.where(
            (rule) {
          if (rule.chargeType != chargeType) {
            return false;
          }

          return _matchesScope(
            rule: rule,
            target: target,
          );
        },
      ).toList();

      if (matchingRules.isEmpty) {
        continue;
      }

      matchingRules.sort(
            (a, b) => _scopePriority(
          b.scopeType,
        ).compareTo(
          _scopePriority(
            a.scopeType,
          ),
        ),
      );

      result.add(
        matchingRules.first,
      );
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

  int _scopePriority(
      BillingScopeType scope,
      ) {
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

  MonthlyBillType _toMonthlyBillType(
      BillingChargeType type,
      ) {
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