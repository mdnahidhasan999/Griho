enum MonthlyRentStatus {
  unpaid,
  partiallyPaid,
  paid,
  overdue,
  cancelled,
}

class MonthlyRent {
  final String id;

  final String ownerId;
  final String propertyId;
  final String unitId;
  final String tenantId;
  final String? tenantUserId;

  /// The rent rate used to calculate this month's rent.
  final String rentRateId;

  /// Snapshot of the rent amount for this billing period.
  ///
  /// This must not change when the rent rate changes later.
  final double amount;

  /// First day of the billing month.
  final DateTime billingPeriodStart;

  /// Last day of the billing month.
  final DateTime billingPeriodEnd;

  /// Rent payment due date.
  final DateTime dueDate;

  final MonthlyRentStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  const MonthlyRent({
    required this.id,
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
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  MonthlyRent copyWith({
    String? id,
    String? ownerId,
    String? propertyId,
    String? unitId,
    String? tenantId,
    String? tenantUserId,
    String? rentRateId,
    double? amount,
    DateTime? billingPeriodStart,
    DateTime? billingPeriodEnd,
    DateTime? dueDate,
    MonthlyRentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,

    bool clearTenantUserId = false,
  }) {
    return MonthlyRent(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      tenantUserId:
      clearTenantUserId ? null : tenantUserId ?? this.tenantUserId,
      rentRateId: rentRateId ?? this.rentRateId,
      amount: amount ?? this.amount,
      billingPeriodStart:
      billingPeriodStart ?? this.billingPeriodStart,
      billingPeriodEnd:
      billingPeriodEnd ?? this.billingPeriodEnd,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}