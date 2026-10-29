import 'monthly_bill.dart';
import '../../../rents/domain/entities/monthly_rent.dart';

enum PayableBillCollection { monthlyBills, monthlyRents }

class TenantPayableBill {
  final String id;
  final String ownerId;
  final String propertyId;
  final String unitId;
  final String tenantId;
  final String tenantUserId;

  final String title;
  final double amount;
  final double paidAmount;
  final String status;

  final DateTime billingPeriodStart;
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
    required this.amount,
    required this.paidAmount,
    required this.status,
    required this.billingPeriodStart,
    required this.dueDate,
    required this.collection,
  });

  double get remainingAmount {
    final remaining = amount - paidAmount;
    return remaining > 0 ? remaining : 0;
  }

  bool get isPayable =>
      status != 'paid' && status != 'cancelled' && remainingAmount > 0;

  factory TenantPayableBill.fromMonthlyBill(MonthlyBill bill) {
    return TenantPayableBill(
      id: bill.id,
      ownerId: bill.ownerId,
      propertyId: bill.propertyId,
      unitId: bill.unitId,
      tenantId: bill.tenantId,
      tenantUserId: bill.tenantUserId ?? '',
      title: _billTypeTitle(bill.type),
      amount: bill.amount,
      paidAmount: bill.paidAmount,
      status: bill.status.name,
      billingPeriodStart: bill.billingPeriodStart,
      dueDate: bill.dueDate,
      collection: PayableBillCollection.monthlyBills,
    );
  }

  factory TenantPayableBill.fromMonthlyRent(MonthlyRent rent) {
    return TenantPayableBill(
      id: rent.id,
      ownerId: rent.ownerId,
      propertyId: rent.propertyId,
      unitId: rent.unitId,
      tenantId: rent.tenantId,
      tenantUserId: rent.tenantUserId ?? '',
      title: 'House rent',
      amount: rent.amount,
      paidAmount: rent.paidAmount,
      status: rent.status.name,
      billingPeriodStart: rent.billingPeriodStart,
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
