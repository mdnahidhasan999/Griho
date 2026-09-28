import 'package:griho/features/billing/domain/entities/billing_rule.dart';

enum MonthlyBillStatus {
  unpaid,
  partiallyPaid,
  paid,
  overdue,
  cancelled,
}

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
  /// recurring rule or requires a variable amount.
  final BillingValueType valueType;

  /// Snapshot of the amount for this billing period.
  ///
  /// Once a monthly bill is generated, this amount
  /// should not change automatically when the original
  /// billing rule changes later.
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
    required this.ownerId,
    required this.propertyId,
    required this.floorId,
    required this.unitId,
    required this.tenantId,
    this.tenantUserId,
    required this.sourceRuleId,
    required this.type,
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

  /// Remaining amount that the tenant still needs to pay.
  double get remainingAmount {
    final remaining = amount - paidAmount;

    if (remaining <= 0) {
      return 0;
    }

    return remaining;
  }

  bool get isFullyPaid =>
      remainingAmount == 0;

  bool get isPartiallyPaid =>
      paidAmount > 0 &&
          paidAmount < amount;

  bool get isUnpaid =>
      paidAmount == 0;

  MonthlyBill copyWith({
    String? id,
    String? ownerId,
    String? propertyId,
    String? floorId,
    String? unitId,
    String? tenantId,
    String? tenantUserId,
    String? sourceRuleId,
    MonthlyBillType? type,
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
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      floorId: floorId ?? this.floorId,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      tenantUserId:
      clearTenantUserId
          ? null
          : tenantUserId ?? this.tenantUserId,
      sourceRuleId:
      sourceRuleId ?? this.sourceRuleId,
      type: type ?? this.type,
      valueType:
      valueType ?? this.valueType,
      amount: amount ?? this.amount,
      paidAmount:
      paidAmount ?? this.paidAmount,
      billingPeriodStart:
      billingPeriodStart ??
          this.billingPeriodStart,
      billingPeriodEnd:
      billingPeriodEnd ??
          this.billingPeriodEnd,
      dueDate:
      dueDate ?? this.dueDate,
      status:
      status ?? this.status,
      createdAt:
      createdAt ?? this.createdAt,
      updatedAt:
      updatedAt ?? this.updatedAt,
    );
  }
}