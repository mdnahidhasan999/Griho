// noinspection SpellCheckingInspection
import 'package:griho/features/tenants/domain/entities/tenancy_billing_target.dart';

import '../../../tenants/domain/entities/repositories/tenancy_history_repository.dart';
import '../../../tenants/domain/entities/tenancy_history.dart';
import '../../../tenants/domain/entities/tenant.dart';

class TenancyBillingTargetResolver {
  final TenancyHistoryRepository _repository;

  const TenancyBillingTargetResolver({required this._repository});

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
    final validUnits = <({String unitId, String floorId})>[];

    for (final unit in units) {
      final unitId = unit.unitId.trim();
      final floorId = unit.floorId.trim();

      if (unitId.isEmpty || floorId.isEmpty) {
        continue;
      }

      if (floorByUnitId.putIfAbsent(unitId, () => floorId) == floorId) {
        validUnits.add((unitId: unitId, floorId: floorId));
      }
    }

    final targets = <TenancyBillingTarget>[];

    // 1. Fetch historical ended tenancies for all units concurrently.
    if (validUnits.isNotEmpty) {
      final historyLists = await Future.wait<List<TenancyHistory>>(
        validUnits.map(
          (unit) => _repository.getHistoryByUnitId(
            unitId: unit.unitId,
            ownerId: normalizedOwnerId,
          ),
        ),
      );

      for (var i = 0; i < validUnits.length; i++) {
        final floorId = validUnits[i].floorId;
        final histories = historyLists[i];

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
              tenancyHistoryId: history.id,
              tenancyStart: overlap.$1,
              tenancyEnd: overlap.$2,
            ),
          );
        }
      }
    }

    // 2. Resolve current active tenancies.
    final billingEndInclusive = periodEndExclusive.subtract(
      const Duration(days: 1),
    );

    for (final tenant in currentTenants) {
      if (tenant.status != TenantStatus.active) {
        continue;
      }
      if (tenant.ownerId != normalizedOwnerId ||
          tenant.propertyId != normalizedPropertyId) {
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
      final overlapStart = tenancyStart.isAfter(periodStart)
          ? tenancyStart
          : periodStart;

      if (overlapStart.isAfter(billingEndInclusive)) {
        continue;
      }

      targets.add(
        TenancyBillingTarget(
          floorId: floorId,
          unitId: unitId,
          tenantId: tenant.id,
          tenantUserId: tenant.userId,
          tenancyHistoryId: null,
          tenancyStart: overlapStart,
          tenancyEnd: billingEndInclusive,
        ),
      );
    }

    // 3. Deduplicate and sort deterministically.
    final uniqueTargets = <String, TenancyBillingTarget>{};
    for (final target in targets) {
      uniqueTargets[_targetKey(target)] = target;
    }

    final result = uniqueTargets.values.toList()
      ..sort((a, b) {
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

  String _targetKey(TenancyBillingTarget target) {
    return [
      target.unitId,
      target.tenantId,
      target.tenancyStart.millisecondsSinceEpoch,
      target.tenancyEnd.millisecondsSinceEpoch,
    ].join('_');
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
