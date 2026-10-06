import 'monthly_rent.dart';

class CreateMonthlyRentRequest {
  final String ownerId;
  final String propertyId;
  final String unitId;
  final String tenantId;
  final String? tenantUserId;

  final String rentRateId;

  /// Contractual monthly rent at the time this charge was generated.
  final double monthlyRate;

  /// Final amount charged for this billing segment.
  final double amount;

  /// Number of days for which rent is charged.
  final int chargeableDays;

  /// Total calendar days in the billing month.
  final int daysInBillingPeriod;

  /// Charge start date within the billing month.
  final DateTime chargePeriodStart;

  /// Charge end date within the billing month.
  final DateTime chargePeriodEnd;

  /// First day of the billing month.
  final DateTime billingPeriodStart;

  /// Last day of the billing month.
  final DateTime billingPeriodEnd;

  /// Payment due date.
  final DateTime dueDate;

  final MonthlyRentStatus status;

  const CreateMonthlyRentRequest({
    required this.ownerId,
    required this.propertyId,
    required this.unitId,
    required this.tenantId,
    this.tenantUserId,
    required this.rentRateId,
    required this.monthlyRate,
    required this.amount,
    required this.chargeableDays,
    required this.daysInBillingPeriod,
    required this.chargePeriodStart,
    required this.chargePeriodEnd,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.dueDate,
    this.status = MonthlyRentStatus.unpaid,
  });

  double get prorationFactor =>
      chargeableDays / daysInBillingPeriod;
}