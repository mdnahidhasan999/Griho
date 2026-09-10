import 'monthly_rent.dart';

class CreateMonthlyRentRequest {
  final String ownerId;
  final String propertyId;
  final String unitId;
  final String tenantId;
  final String? tenantUserId;
  final String rentRateId;
  final double amount;
  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final DateTime dueDate;
  final MonthlyRentStatus status;

  const CreateMonthlyRentRequest({
    required this.ownerId,
    required this.propertyId,
    required this.unitId,
    required this.tenantId,
    this.tenantUserId,
    required this.rentRateId,
    required this.amount,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.dueDate,
    this.status = MonthlyRentStatus.unpaid,
  });
}