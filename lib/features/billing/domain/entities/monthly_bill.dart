import 'package:griho/features/billing/domain/entities/billing_rule.dart';

enum MonthlyBillStatus { unpaid, partiallyPaid, paid, overdue, cancelled }

enum MonthlyBillType {
  rent,
  water,
  gas,
  garbage,
  serviceCharge,
  electricity,
  other,
}

class MonthlyBill {
  final String id;

  /// Firestore collection containing this bill.
  /// Rent records may come from monthlyRents.
  final String billCollection;
  final String ownerId;
  final String propertyId;
  final String floorId;
  final String unitId;
  final String tenantId;

  /// User account ID of the tenant.
  ///
  /// This can be null when the tenant profile exists
  /// but the tenant has not created/linked a user account yet.
  final String? tenantUserId;

  /// The billing rule used to create this monthly bill.
  ///
  /// For rent this refers to the rent rate.
  final String sourceRuleId;

  /// Type of this bill.
  final MonthlyBillType type;

  /// Whether this bill was generated from a fixed
  /// recurring rule or a variable monthly override.
  final BillingValueType valueType;
  final String? tenancyHistoryId;

  /// Immutable snapshot of custom title at the time of bill generation.
  final String? title;

  /// Immutable snapshot of the rule scope at the time of bill generation.
  final BillingScopeType? ruleScopeType;
  final String? ruleScopeId;

  /// Full immutable rule metadata snapshot so future rule edits never alter old bills.
  final Map<String, dynamic>? ruleSnapshot;

  /// Audit fields when a Variable bill overrides an existing Fixed bill.
  final String? overriddenFromRuleId;
  final double? overriddenFromAmount;

  /// Snapshot of the amount for this billing period.
  ///
  /// The amount is already known when the bill is generated.
  final double amount;

  /// Total amount already paid against this bill.
  final double paidAmount;

  /// Start of the billing period.
  final DateTime billingPeriodStart;

  /// End of the billing period.
  final DateTime billingPeriodEnd;

  /// Payment due date.
  final DateTime dueDate;

  final MonthlyBillStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  const MonthlyBill({
    required this.id,
    this.billCollection = 'monthlyBills',
    required this.ownerId,
    required this.propertyId,
    required this.floorId,
    required this.unitId,
    required this.tenantId,
    this.tenantUserId,
    required this.sourceRuleId,
    required this.type,
    this.tenancyHistoryId,
    this.title,
    this.ruleScopeType,
    this.ruleScopeId,
    this.ruleSnapshot,
    this.overriddenFromRuleId,
    this.overriddenFromAmount,
    required this.valueType,
    required this.amount,
    required this.paidAmount,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Whether this bill was updated by a Variable override replacing a Fixed bill.
  bool get isOverriddenByVariable =>
      overriddenFromRuleId != null && overriddenFromRuleId!.trim().isNotEmpty;

  /// Remaining amount that the tenant still needs to pay.
  double get remainingAmount {
    final remaining = amount - paidAmount;

    if (remaining <= 0) {
      return 0;
    }

    return remaining;
  }

  /// Whether the bill has passed its payment deadline
  /// and still has an outstanding balance.
  bool get isOverdue {
    if (remainingAmount <= 0 ||
        status == MonthlyBillStatus.paid ||
        status == MonthlyBillStatus.cancelled) {
      return false;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = DateTime(dueDate.year, dueDate.month, dueDate.day);

    return today.isAfter(deadline);
  }

  /// Returns the effective status without modifying
  /// the original Firestore status.
  MonthlyBillStatus get effectiveStatus {
    if (status == MonthlyBillStatus.paid ||
        status == MonthlyBillStatus.cancelled) {
      return status;
    }

    if (isOverdue) {
      return MonthlyBillStatus.overdue;
    }

    return status;
  }

  bool get isFullyPaid =>
      status == MonthlyBillStatus.paid && remainingAmount == 0;

  bool get isPartiallyPaid =>
      status == MonthlyBillStatus.partiallyPaid ||
      (paidAmount > 0 && paidAmount < amount);

  bool get isUnpaid => status == MonthlyBillStatus.unpaid;

  MonthlyBill copyWith({
    String? id,
    String? billCollection,
    String? ownerId,
    String? propertyId,
    String? floorId,
    String? unitId,
    String? tenantId,
    String? tenantUserId,
    String? sourceRuleId,
    MonthlyBillType? type,
    String? tenancyHistoryId,
    bool clearTenancyHistoryId = false,
    String? title,
    bool clearTitle = false,
    BillingScopeType? ruleScopeType,
    String? ruleScopeId,
    Map<String, dynamic>? ruleSnapshot,
    String? overriddenFromRuleId,
    double? overriddenFromAmount,
    BillingValueType? valueType,
    double? amount,
    double? paidAmount,
    DateTime? billingPeriodStart,
    DateTime? billingPeriodEnd,
    DateTime? dueDate,
    MonthlyBillStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearTenantUserId = false,
  }) {
    return MonthlyBill(
      id: id ?? this.id,
      billCollection: billCollection ?? this.billCollection,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      floorId: floorId ?? this.floorId,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      tenantUserId: clearTenantUserId
          ? null
          : tenantUserId ?? this.tenantUserId,
      sourceRuleId: sourceRuleId ?? this.sourceRuleId,
      type: type ?? this.type,
      valueType: valueType ?? this.valueType,
      tenancyHistoryId: clearTenancyHistoryId
          ? null
          : tenancyHistoryId ?? this.tenancyHistoryId,
      title: clearTitle ? null : title ?? this.title,
      ruleScopeType: ruleScopeType ?? this.ruleScopeType,
      ruleScopeId: ruleScopeId ?? this.ruleScopeId,
      ruleSnapshot: ruleSnapshot ?? this.ruleSnapshot,
      overriddenFromRuleId: overriddenFromRuleId ?? this.overriddenFromRuleId,
      overriddenFromAmount: overriddenFromAmount ?? this.overriddenFromAmount,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      billingPeriodStart: billingPeriodStart ?? this.billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd ?? this.billingPeriodEnd,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
