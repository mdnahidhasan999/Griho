import '../../../tenants/domain/entities/repositories/tenancy_history_repository.dart';
import '../../../tenants/domain/entities/tenancy_billing_target.dart';
import '../../../tenants/domain/entities/tenant.dart';

class TenancyBillingTargetResolver {
  final TenancyHistoryRepository _repository;

  const TenancyBillingTargetResolver({
    required this._repository,
  });

  /// Resolves all tenancies that overlap the requested billing period.
  ///
  /// Historical ended tenancies are loaded from TenancyHistory.
  /// Current active tenancies are resolved from the current Tenant records.
  ///
  /// Billing period:
  ///   [billingPeriodStart, billingPeriodEnd)
  ///
  /// Tenancy dates:
  ///   [startedAt, endedAt] inclusive.
  Future<List<TenancyBillingTarget>> resolve({
    required String ownerId,
    required String propertyId,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
    required List<Tenant> currentTenants,
    required List<({String unitId, String floorId})> units,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedPropertyId = propertyId.trim();

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID is required.');
    }

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID is required.');
    }

    final periodStart = _dateOnly(billingPeriodStart);
    final periodEndExclusive = _dateOnly(billingPeriodEnd);

    if (!periodEndExclusive.isAfter(periodStart)) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    final floorByUnitId = <String, String>{};

    for (final unit in units) {
      final unitId = unit.unitId.trim();
      final floorId = unit.floorId.trim();

      if (unitId.isEmpty || floorId.isEmpty) {
        continue;
      }

      floorByUnitId[unitId] = floorId;
    }

    final targets = <TenancyBillingTarget>[];

    // ============================================================
    // 1. HISTORICAL ENDED TENANCIES
    // ============================================================

    for (final unit in units) {
      final unitId = unit.unitId.trim();
      final floorId = unit.floorId.trim();

      if (unitId.isEmpty || floorId.isEmpty) {
        continue;
      }

      final histories = await _repository.getHistoryByUnitId(
        unitId: unitId,
        ownerId: normalizedOwnerId,
      );

      for (final history in histories) {
        if (history.propertyId != normalizedPropertyId) {
          continue;
        }

        final overlap = _resolveOverlap(
          tenancyStart: history.startedAt,
          tenancyEnd: history.endedAt,
          billingStart: periodStart,
          billingEndExclusive: periodEndExclusive,
        );

        if (overlap == null) {
          continue;
        }

        targets.add(
          TenancyBillingTarget(
            floorId: floorId,
            unitId: history.unitId,
            tenantId: history.tenantId,
            tenantUserId: history.tenantUserId,
            tenancyStart: overlap.$1,
            tenancyEnd: overlap.$2,
          ),
        );
      }
    }

    // ============================================================
    // 2. CURRENT ACTIVE TENANCIES
    // ============================================================

    for (final tenant in currentTenants) {
      if (tenant.status != TenantStatus.active) {
        continue;
      }

      if (tenant.ownerId != normalizedOwnerId) {
        continue;
      }

      if (tenant.propertyId != normalizedPropertyId) {
        continue;
      }

      final unitId = tenant.unitId.trim();

      if (unitId.isEmpty) {
        continue;
      }

      final floorId = floorByUnitId[unitId];

      if (floorId == null || floorId.isEmpty) {
        continue;
      }

      final tenancyStartedAt = tenant.tenancyStartedAt;

      if (tenancyStartedAt == null) {
        continue;
      }

      final tenancyStart = _dateOnly(tenancyStartedAt);

      final billingEndInclusive = periodEndExclusive.subtract(
        const Duration(days: 1),
      );

      final overlapStart = tenancyStart.isAfter(periodStart)
          ? tenancyStart
          : periodStart;

      final overlapEnd = billingEndInclusive;

      if (overlapStart.isAfter(overlapEnd)) {
        continue;
      }

      targets.add(
        TenancyBillingTarget(
          floorId: floorId,
          unitId: unitId,
          tenantId: tenant.id,
          tenantUserId: tenant.userId,
          tenancyStart: overlapStart,
          tenancyEnd: overlapEnd,
        ),
      );
    }

    // ============================================================
    // 3. REMOVE DUPLICATE TENANCY TARGETS
    // ============================================================

    final uniqueTargets = <String, TenancyBillingTarget>{};

    for (final target in targets) {
      final key = _targetKey(target);

      uniqueTargets[key] = target;
    }

    final result = uniqueTargets.values.toList();

    // Stable ordering:
    // Unit → tenancy start → tenant.
    result.sort((a, b) {
      final unitComparison = a.unitId.compareTo(b.unitId);

      if (unitComparison != 0) {
        return unitComparison;
      }

      final startComparison = a.tenancyStart.compareTo(b.tenancyStart);

      if (startComparison != 0) {
        return startComparison;
      }

      return a.tenantId.compareTo(b.tenantId);
    });

    return result;
  }

  // ============================================================
  // OVERLAP RESOLUTION
  // ============================================================

  (DateTime, DateTime)? _resolveOverlap({
    required DateTime tenancyStart,
    required DateTime tenancyEnd,
    required DateTime billingStart,
    required DateTime billingEndExclusive,
  }) {
    final normalizedTenancyStart = _dateOnly(tenancyStart);
    final normalizedTenancyEnd = _dateOnly(tenancyEnd);

    if (normalizedTenancyEnd.isBefore(normalizedTenancyStart)) {
      return null;
    }

    final billingEndInclusive = billingEndExclusive.subtract(
      const Duration(days: 1),
    );

    final overlapStart = normalizedTenancyStart.isAfter(billingStart)
        ? normalizedTenancyStart
        : billingStart;

    final overlapEnd = normalizedTenancyEnd.isBefore(billingEndInclusive)
        ? normalizedTenancyEnd
        : billingEndInclusive;

    if (overlapStart.isAfter(overlapEnd)) {
      return null;
    }

    return (overlapStart, overlapEnd);
  }

  // ============================================================
  // DUPLICATE KEY
  // ============================================================

  String _targetKey(TenancyBillingTarget target) {
    return [
      target.unitId,
      target.tenantId,
      target.tenancyStart.millisecondsSinceEpoch,
      target.tenancyEnd.millisecondsSinceEpoch,
    ].join('_');
  }

  // ============================================================
  // DATE NORMALIZATION
  // ============================================================

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
