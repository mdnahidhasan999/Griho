class GenerateMonthlyRentRequest {
  final String ownerId;
  final String propertyId;
  final String unitId;
  final String tenantId;
  final String? tenantUserId;

  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final DateTime dueDate;

  final DateTime tenancyStart;
  final DateTime? tenancyEnd;

  const GenerateMonthlyRentRequest({
    required this.ownerId,
    required this.propertyId,
    required this.unitId,
    required this.tenantId,
    this.tenantUserId,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.dueDate,
    required this.tenancyStart,
    this.tenancyEnd,
  });
}