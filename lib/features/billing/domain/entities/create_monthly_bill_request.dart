import 'billing_rule.dart';
import 'monthly_bill.dart';

class CreateMonthlyBillRequest {
  final String ownerId;
  final String propertyId;
  final String floorId;
  final String unitId;
  final String tenantId;
  final String? tenantUserId;

  final String sourceRuleId;

  final MonthlyBillType type;
  final BillingValueType valueType;

  final double amount;

  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final DateTime dueDate;

  final MonthlyBillStatus status;

  const CreateMonthlyBillRequest({
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
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.dueDate,
    this.status = MonthlyBillStatus.unpaid,
  });
}