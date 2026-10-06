class MonthlyRentCalculation {
  final double monthlyRate;
  final double amount;
  final int chargeableDays;
  final int daysInBillingPeriod;
  final double prorationFactor;
  final DateTime chargePeriodStart;
  final DateTime chargePeriodEnd;

  const MonthlyRentCalculation({
    required this.monthlyRate,
    required this.amount,
    required this.chargeableDays,
    required this.daysInBillingPeriod,
    required this.prorationFactor,
    required this.chargePeriodStart,
    required this.chargePeriodEnd,
  });

  bool get isProrated =>
      chargeableDays != daysInBillingPeriod;

  bool get isFullMonth =>
      chargeableDays == daysInBillingPeriod;
}

class MonthlyRentCalculator {
  const MonthlyRentCalculator();

  MonthlyRentCalculation calculate({
    required double monthlyRate,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
    required DateTime tenancyStart,
    DateTime? tenancyEnd,
  }) {
    if (monthlyRate <= 0) {
      throw ArgumentError(
        'Monthly rent rate must be greater than zero.',
      );
    }

    // Billing period uses an exclusive end.
    //
    // Example:
    // 2026-09-01 -> 2026-10-01
    // means 2026-09-01 through 2026-09-30.
    if (!billingPeriodEnd.isAfter(
      billingPeriodStart,
    )) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    if (tenancyEnd != null &&
        tenancyEnd.isBefore(tenancyStart)) {
      throw ArgumentError(
        'Tenancy end cannot be before tenancy start.',
      );
    }

    final billingStart = _dateOnly(
      billingPeriodStart,
    );

    final billingEndInclusive = billingPeriodEnd
        .subtract(
      const Duration(days: 1),
    );

    final normalizedBillingEnd = _dateOnly(
      billingEndInclusive,
    );

    final normalizedTenancyStart = _dateOnly(
      tenancyStart,
    );

    final normalizedTenancyEnd = tenancyEnd == null
        ? null
        : _dateOnly(tenancyEnd);

    // A tenancy that starts after the last actual
    // billing day cannot generate rent.
    if (normalizedTenancyStart.isAfter(
      normalizedBillingEnd,
    )) {
      throw ArgumentError(
        'Tenancy starts after the billing period.',
      );
    }

    // A tenancy that ended before the first billing
    // day cannot generate rent.
    if (normalizedTenancyEnd != null &&
        normalizedTenancyEnd.isBefore(
          billingStart,
        )) {
      throw ArgumentError(
        'Tenancy ended before the billing period.',
      );
    }

    // ------------------------------------------------------------------------
    // Effective charge period
    //
    // Billing period:
    //   start = inclusive
    //   end   = exclusive
    //
    // Tenancy period:
    //   start = inclusive
    //   end   = inclusive
    // ------------------------------------------------------------------------

    final effectiveStart = _maxDate(
      billingStart,
      normalizedTenancyStart,
    );

    final effectiveEnd = _minDate(
      normalizedBillingEnd,
      normalizedTenancyEnd ?? normalizedBillingEnd,
    );

    if (effectiveEnd.isBefore(
      effectiveStart,
    )) {
      throw ArgumentError(
        'No chargeable tenancy period exists '
            'inside the billing period.',
      );
    }

    // Because billingPeriodEnd is exclusive, the
    // actual billing days are calculated from:
    //
    // 01 Sep -> 30 Sep
    //
    // not:
    //
    // 01 Sep -> 01 Oct.
    final daysInBillingPeriod = _inclusiveDays(
      billingStart,
      normalizedBillingEnd,
    );

    final chargeableDays = _inclusiveDays(
      effectiveStart,
      effectiveEnd,
    );

    if (chargeableDays <= 0) {
      throw ArgumentError(
        'Chargeable days must be greater than zero.',
      );
    }

    if (chargeableDays > daysInBillingPeriod) {
      throw StateError(
        'Chargeable days cannot exceed '
            'billing period days.',
      );
    }

    final prorationFactor =
        chargeableDays / daysInBillingPeriod;

    final amount = _roundCurrency(
      monthlyRate * prorationFactor,
    );

    return MonthlyRentCalculation(
      monthlyRate: monthlyRate,
      amount: amount,
      chargeableDays: chargeableDays,
      daysInBillingPeriod: daysInBillingPeriod,
      prorationFactor: prorationFactor,
      chargePeriodStart: effectiveStart,
      chargePeriodEnd: effectiveEnd,
    );
  }

  DateTime _maxDate(DateTime first,
      DateTime second,) {
    return first.isAfter(second)
        ? first
        : second;
  }

  DateTime _minDate(DateTime first,
      DateTime second,) {
    return first.isBefore(second)
        ? first
        : second;
  }

  int _inclusiveDays(DateTime start,
      DateTime end,) {
    final startDate = _dateOnly(start);
    final endDate = _dateOnly(end);

    return endDate
        .difference(startDate)
        .inDays + 1;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  double _roundCurrency(double value) {
    return (value * 100).round() / 100;
  }
}