enum TenancyHistoryStatus {
  ended,
}

class TenancyHistory {
  final String id;

  // Internal identifiers.
  final String tenantId;
  final String? tenantUserId;
  final String ownerId;
  final String propertyId;
  final String unitId;

  // Human-readable historical snapshots.
  final String tenantName;
  final String propertyName;
  final String propertyCode;
  final String? propertyAddress;
  final String unitNumber;
  final String? unitName;

  final int floorNumber;
  final double? monthlyRent;

  final DateTime startedAt;
  final DateTime endedAt;

  final TenancyHistoryStatus status;

  final DateTime createdAt;

  const TenancyHistory({
    required this.id,
    required this.tenantId,
    required this.tenantUserId,
    required this.ownerId,
    required this.propertyId,
    required this.tenantName,
    required this.propertyName,
    required this.propertyCode,
    required this.propertyAddress,
    required this.unitId,
    required this.unitNumber,
    required this.unitName,
    required this.floorNumber,
    required this.monthlyRent,
    required this.startedAt,
    required this.endedAt,
    required this.status,
    required this.createdAt,
  });

  TenancyHistory copyWith({
    String? id,
    String? tenantId,
    Object? tenantUserId = _keep,
    String? ownerId,
    String? propertyId,
    String? tenantName,
    String? propertyName,
    String? propertyCode,
    Object? propertyAddress = _keep,
    String? unitId,
    String? unitNumber,
    Object? unitName = _keep,
    int? floorNumber,
    Object? monthlyRent = _keep,
    DateTime? startedAt,
    DateTime? endedAt,
    TenancyHistoryStatus? status,
    DateTime? createdAt,
  }) {
    return TenancyHistory(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      tenantUserId: identical(tenantUserId, _keep)
          ? this.tenantUserId
          : tenantUserId as String?,
      ownerId: ownerId ?? this.ownerId,
      propertyId: propertyId ?? this.propertyId,
      tenantName: tenantName ?? this.tenantName,
      propertyName: propertyName ?? this.propertyName,
      propertyCode: propertyCode ?? this.propertyCode,
      propertyAddress: identical(propertyAddress, _keep)
          ? this.propertyAddress
          : propertyAddress as String?,
      unitId: unitId ?? this.unitId,
      unitNumber: unitNumber ?? this.unitNumber,
      unitName: identical(unitName, _keep)
          ? this.unitName
          : unitName as String?,
      floorNumber: floorNumber ?? this.floorNumber,
      monthlyRent: identical(monthlyRent, _keep)
          ? this.monthlyRent
          : monthlyRent as double?,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static const _keep = Object();
}