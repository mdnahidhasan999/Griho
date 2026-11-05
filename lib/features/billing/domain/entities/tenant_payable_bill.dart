import '../../../rents/domain/entities/monthly_rent.dart';
import 'billing_rule.dart';
import 'monthly_bill.dart';

enum PayableBillCollection { monthlyBills, monthlyRents }

class TenantPayableBill {
  final String id;
  final String ownerId;
  final String propertyId;
  final String unitId;
  final String tenantId;
  final String tenantUserId;

  final String title;
  final MonthlyBillType billType;
  final BillingValueType valueType;
  final double amount;
  final double paidAmount;
  final String status;

  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final DateTime dueDate;

  final PayableBillCollection collection;

  const TenantPayableBill({
    required this.id,
    required this.ownerId,
    required this.propertyId,
    required this.unitId,
    required this.tenantId,
    required this.tenantUserId,
    required this.title,
    this.billType = MonthlyBillType.other,
    this.valueType = BillingValueType.fixed,
    required this.amount,
    required this.paidAmount,
    required this.status,
    required this.billingPeriodStart,
    DateTime? billingPeriodEnd,
    required this.dueDate,
    required this.collection,
  }) : billingPeriodEnd = billingPeriodEnd ?? billingPeriodStart;

  /// Unique composite key across collections (`monthlyRents` and `monthlyBills`).
  String get uniqueKey => '${collection.name}_$id';

  double get remainingAmount {
    final remaining = amount - paidAmount;
    return remaining > 0 ? remaining : 0;
  }

  bool get isPayable =>
      status != 'paid' && status != 'cancelled' && remainingAmount > 0;

  bool get isPaid => status == 'paid' || remainingAmount <= 0;

  bool get isPartiallyPaid =>
      status == 'partiallyPaid' || (paidAmount > 0 && remainingAmount > 0);

  bool get isOverdue {
    if (!isPayable) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadline = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return today.isAfter(deadline);
  }

  String get effectiveStatus {
    if (status == 'cancelled') return 'cancelled';
    if (isPaid) return 'paid';
    if (isOverdue) return 'overdue';
    if (isPartiallyPaid) return 'partiallyPaid';
    return 'unpaid';
  }

  factory TenantPayableBill.fromMonthlyBill(MonthlyBill bill) {
    final isRentDoc =
        bill.billCollection == 'monthlyRents' ||
        bill.type == MonthlyBillType.rent;

    final customTitle = bill.title?.trim();
    final resolvedTitle = (customTitle != null && customTitle.isNotEmpty)
        ? customTitle
        : _billTypeTitle(bill.type);

    return TenantPayableBill(
      id: bill.id,
      ownerId: bill.ownerId,
      propertyId: bill.propertyId,
      unitId: bill.unitId,
      tenantId: bill.tenantId,
      tenantUserId: bill.tenantUserId ?? '',
      title: resolvedTitle,
      billType: bill.type,
      valueType: bill.valueType,
      amount: bill.amount,
      paidAmount: bill.paidAmount,
      status: bill.status.name,
      billingPeriodStart: bill.billingPeriodStart,
      billingPeriodEnd: bill.billingPeriodEnd,
      dueDate: bill.dueDate,
      collection: isRentDoc
          ? PayableBillCollection.monthlyRents
          : PayableBillCollection.monthlyBills,
    );
  }

  factory TenantPayableBill.fromMonthlyRent(MonthlyRent rent) {
    final title = rent.isProrated
        ? 'House rent (${rent.chargeableDays}/${rent.daysInBillingPeriod} days)'
        : 'House rent';

    return TenantPayableBill(
      id: rent.id,
      ownerId: rent.ownerId,
      propertyId: rent.propertyId,
      unitId: rent.unitId,
      tenantId: rent.tenantId,
      tenantUserId: rent.tenantUserId ?? '',
      title: title,
      billType: MonthlyBillType.rent,
      valueType: BillingValueType.fixed,
      amount: rent.amount,
      paidAmount: rent.paidAmount,
      status: rent.status.name,
      billingPeriodStart: rent.billingPeriodStart,
      billingPeriodEnd: rent.billingPeriodEnd,
      dueDate: rent.dueDate,
      collection: PayableBillCollection.monthlyRents,
    );
  }

  static String _billTypeTitle(MonthlyBillType type) {
    switch (type) {
      case MonthlyBillType.rent:
        return 'House rent';
      case MonthlyBillType.water:
        return 'Water bill';
      case MonthlyBillType.gas:
        return 'Gas bill';
      case MonthlyBillType.garbage:
        return 'Garbage bill';
      case MonthlyBillType.serviceCharge:
        return 'Service charge';
      case MonthlyBillType.electricity:
        return 'Electricity bill';
      case MonthlyBillType.other:
        return 'Other bill';
    }
  }
}

/// Represents a grouped monthly invoice containing both Rent and Utility Bills
/// for a specific billing month (used in Expandable Monthly Invoices).
class TenantMonthlyInvoiceGroup {
  final DateTime billingPeriodStart;
  final List<TenantPayableBill> items;

  const TenantMonthlyInvoiceGroup({
    required this.billingPeriodStart,
    required this.items,
  });

  double get totalAmount => items.fold(0, (sum, item) => sum + item.amount);

  double get totalPaidAmount =>
      items.fold(0, (sum, item) => sum + item.paidAmount);

  double get totalRemainingAmount =>
      items.fold(0, (sum, item) => sum + item.remainingAmount);

  List<TenantPayableBill> get payableItems =>
      items.where((item) => item.isPayable).toList();

  bool get isFullyPaid => payableItems.isEmpty && items.isNotEmpty;

  bool get hasOverdue => items.any((item) => item.isOverdue);

  String get groupStatus {
    if (isFullyPaid) return 'paid';
    if (hasOverdue) return 'overdue';
    if (totalPaidAmount > 0 && totalRemainingAmount > 0) return 'partiallyPaid';
    return 'unpaid';
  }
}
