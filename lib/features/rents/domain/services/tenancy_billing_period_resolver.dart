class TenancyBillingPeriod {
  final DateTime chargePeriodStart;
  final DateTime chargePeriodEnd;

  const TenancyBillingPeriod({
    required this.chargePeriodStart,
    required this.chargePeriodEnd,
  });

  int get chargeableDays =>
      chargePeriodEnd.difference(chargePeriodStart).inDays + 1;
}

class TenancyBillingPeriodResolver {
  const TenancyBillingPeriodResolver();

  TenancyBillingPeriod? resolve({
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
    required DateTime tenancyStart,
    DateTime? tenancyEnd,
  }) {
    // ------------------------------------------------------------------------
    // Billing period:
    //
    // billingPeriodStart = INCLUSIVE
    // billingPeriodEnd   = EXCLUSIVE
    //
    // Example:
    // 2026-09-01 -> 2026-10-01
    // means Sep 1 through Sep 30.
    // ------------------------------------------------------------------------

    if (!billingPeriodEnd.isAfter(
      billingPeriodStart,
    )) {
      throw ArgumentError(
        'Billing period end must be after '
            'billing period start.',
      );
    }

    // ------------------------------------------------------------------------
    // Tenancy period:
    //
    // tenancyStart = INCLUSIVE
    // tenancyEnd   = INCLUSIVE
    // ------------------------------------------------------------------------

    if (tenancyEnd != null &&
        tenancyEnd.isBefore(
          tenancyStart,
        )) {
      throw ArgumentError(
        'Tenancy end cannot be before '
            'tenancy start.',
      );
    }

    final billingStart = _dateOnly(
      billingPeriodStart,
    );

    // billingPeriodEnd is EXCLUSIVE, so the actual
    // last chargeable calendar day is one day before it.
    final billingEndInclusive = _dateOnly(
      billingPeriodEnd,
    ).subtract(
      const Duration(days: 1),
    );

    final normalizedTenancyStart = _dateOnly(
      tenancyStart,
    );

    final normalizedTenancyEnd = tenancyEnd == null
        ? null
        : _dateOnly(
      tenancyEnd,
    );

    // ------------------------------------------------------------------------
    // No overlap:
    //
    // 1. Tenancy starts after the billing period.
    // 2. Tenancy ended before the billing period.
    // ------------------------------------------------------------------------

    if (normalizedTenancyStart.isAfter(
      billingEndInclusive,
    )) {
      return null;
    }

    if (normalizedTenancyEnd != null &&
        normalizedTenancyEnd.isBefore(
          billingStart,
        )) {
      return null;
    }

    // ------------------------------------------------------------------------
    // Resolve the actual charge period.
    // ------------------------------------------------------------------------

    final chargeStart = _maxDate(
      billingStart,
      normalizedTenancyStart,
    );

    final chargeEnd = _minDate(
      billingEndInclusive,
      normalizedTenancyEnd ?? billingEndInclusive,
    );

    // Defensive validation.
    if (chargeEnd.isBefore(chargeStart)) {
      return null;
    }

    return TenancyBillingPeriod(
      chargePeriodStart: chargeStart,
      chargePeriodEnd: chargeEnd,
    );
  }

  DateTime _maxDate(
      DateTime first,
      DateTime second,
      ) {
    return first.isAfter(second) ? first : second;
  }

  DateTime _minDate(
      DateTime first,
      DateTime second,
      ) {
    return first.isBefore(second) ? first : second;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }
}