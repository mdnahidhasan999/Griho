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

  /// The rent rate used for this billing segment.
  ///
  /// This is a historical reference and must not change later.
  final String rentRateId;

  /// Monthly contractual rent amount from the applicable rent rate.
  ///
  /// This is the monthly-rate snapshot, not necessarily the final
  /// amount charged for this billing period.
  final double monthlyRate;

  /// Final rent amount charged for this billing segment.
  ///
  /// For a full-month tenancy this normally equals [monthlyRate].
  /// For a partial-month tenancy this is the prorated amount.
  final double amount;

  /// Number of calendar days covered by this rent charge.
  final int chargeableDays;

  /// Total number of calendar days in the billing month.
  final int daysInBillingPeriod;

  /// Proration factor used to calculate [amount].
  ///
  /// Full month:
  ///   1.0
  ///
  /// Partial month:
  ///   chargeableDays / daysInBillingPeriod
  final double prorationFactor;

  /// First day of the billing month.
  final DateTime billingPeriodStart;

  /// Last day of the billing month.
  final DateTime billingPeriodEnd;

  /// Actual start date covered by this rent charge.
  final DateTime chargePeriodStart;

  /// Actual end date covered by this rent charge.
  final DateTime chargePeriodEnd;

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
    required this.monthlyRate,
    required this.amount,
    required this.chargeableDays,
    required this.daysInBillingPeriod,
    required this.prorationFactor,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.chargePeriodStart,
    required this.chargePeriodEnd,
    required this.dueDate,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isProrated => chargeableDays != daysInBillingPeriod;

  bool get isFullMonth => chargeableDays == daysInBillingPeriod;

  MonthlyRent copyWith({
    String? id,
    String? ownerId,
    String? propertyId,
    String? unitId,
    String? tenantId,
    String? tenantUserId,
    String? rentRateId,
    double? monthlyRate,
    double? amount,
    int? chargeableDays,
    int? daysInBillingPeriod,
    double? prorationFactor,
    DateTime? billingPeriodStart,
    DateTime? billingPeriodEnd,
    DateTime? chargePeriodStart,
    DateTime? chargePeriodEnd,
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
      monthlyRate: monthlyRate ?? this.monthlyRate,
      amount: amount ?? this.amount,
      chargeableDays: chargeableDays ?? this.chargeableDays,
      daysInBillingPeriod:
      daysInBillingPeriod ?? this.daysInBillingPeriod,
      prorationFactor:
      prorationFactor ?? this.prorationFactor,
      billingPeriodStart:
      billingPeriodStart ?? this.billingPeriodStart,
      billingPeriodEnd:
      billingPeriodEnd ?? this.billingPeriodEnd,
      chargePeriodStart:
      chargePeriodStart ?? this.chargePeriodStart,
      chargePeriodEnd:
      chargePeriodEnd ?? this.chargePeriodEnd,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}