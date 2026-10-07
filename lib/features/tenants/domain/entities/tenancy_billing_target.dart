class TenancyBillingTarget {
  final String floorId;
  final String unitId;
  final String tenantId;
  final String? tenantUserId;

  /// Inclusive start date of this tenancy inside the billing period.
  final DateTime tenancyStart;

  /// Inclusive end date of this tenancy inside the billing period.
  final DateTime tenancyEnd;

  const TenancyBillingTarget({
    required this.floorId,
    required this.unitId,
    required this.tenantId,
    required this.tenantUserId,
    required this.tenancyStart,
    required this.tenancyEnd,
  });

  TenancyBillingTarget copyWith({
    String? floorId,
    String? unitId,
    String? tenantId,
    Object? tenantUserId = _keep,
    DateTime? tenancyStart,
    DateTime? tenancyEnd,
  }) {
    return TenancyBillingTarget(
      floorId: floorId ?? this.floorId,
      unitId: unitId ?? this.unitId,
      tenantId: tenantId ?? this.tenantId,
      tenantUserId: identical(tenantUserId, _keep)
          ? this.tenantUserId
          : tenantUserId as String?,
      tenancyStart: tenancyStart ?? this.tenancyStart,
      tenancyEnd: tenancyEnd ?? this.tenancyEnd,
    );
  }

  static const _keep = Object();
}