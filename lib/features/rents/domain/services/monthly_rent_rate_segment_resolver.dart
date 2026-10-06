import '../entities/rent_rate.dart';

class MonthlyRentRateSegment {
  final RentRate rentRate;
  final DateTime start;
  final DateTime end;

  const MonthlyRentRateSegment({
    required this.rentRate,
    required this.start,
    required this.end,
  });

  int get chargeableDays =>
      end
          .difference(start)
          .inDays + 1;
}

class MonthlyRentRateSegmentResolver {
  const MonthlyRentRateSegmentResolver();

  List<MonthlyRentRateSegment> resolve({
    required List<RentRate> rentRates,
    required DateTime chargePeriodStart,
    required DateTime chargePeriodEnd,
  }) {
    if (!chargePeriodEnd.isAfter(chargePeriodStart) &&
        !_isSameCalendarDay(
          chargePeriodStart,
          chargePeriodEnd,
        )) {
      throw ArgumentError(
        'Charge period end must not be before charge period start.',
      );
    }

    if (rentRates.isEmpty) {
      throw StateError(
        'No rent rate history is available for the charge period.',
      );
    }

    final normalizedStart = _dateOnly(
      chargePeriodStart,
    );

    final normalizedEnd = _dateOnly(
      chargePeriodEnd,
    );

    final applicableRates = rentRates
        .where(
          (rate) =>
          _overlapsPeriod(
            rate,
            normalizedStart,
            normalizedEnd,
          ),
    )
        .toList()
      ..sort(
            (a, b) =>
            a.effectiveFrom.compareTo(
              b.effectiveFrom,
            ),
      );

    if (applicableRates.isEmpty) {
      throw StateError(
        'No applicable rent rate was found for the charge period.',
      );
    }

    final segments = <MonthlyRentRateSegment>[];

    DateTime cursor = normalizedStart;

    while (!cursor.isAfter(normalizedEnd)) {
      final rate = _findRateForDate(
        applicableRates,
        cursor,
      );

      if (rate == null) {
        throw StateError(
          'No rent rate is applicable on '
              '${_formatDate(cursor)}.',
        );
      }

      final rateStart = _dateOnly(
        rate.effectiveFrom,
      );

      final rateEndExclusive = rate.effectiveTo == null
          ? null
          : _dateOnly(rate.effectiveTo!);

      final segmentStart = cursor.isAfter(rateStart)
          ? cursor
          : rateStart;

      DateTime segmentEnd;

      if (rateEndExclusive == null) {
        segmentEnd = normalizedEnd;
      } else {
        final dayBeforeRateEnds = rateEndExclusive.subtract(
          const Duration(days: 1),
        );

        segmentEnd = dayBeforeRateEnds.isBefore(
          normalizedEnd,
        )
            ? dayBeforeRateEnds
            : normalizedEnd;
      }

      if (segmentEnd.isBefore(segmentStart)) {
        throw StateError(
          'Invalid rent-rate segment detected.',
        );
      }

      segments.add(
        MonthlyRentRateSegment(
          rentRate: rate,
          start: segmentStart,
          end: segmentEnd,
        ),
      );

      cursor = segmentEnd.add(
        const Duration(days: 1),
      );
    }

    _validateContinuousCoverage(
      segments,
      normalizedStart,
      normalizedEnd,
    );

    return segments;
  }

  RentRate? _findRateForDate(List<RentRate> rates,
      DateTime date,) {
    RentRate? selected;

    for (final rate in rates) {
      final effectiveFrom = _dateOnly(
        rate.effectiveFrom,
      );

      final effectiveTo = rate.effectiveTo == null
          ? null
          : _dateOnly(rate.effectiveTo!);

      if (date.isBefore(effectiveFrom)) {
        continue;
      }

      if (effectiveTo != null &&
          !date.isBefore(effectiveTo)) {
        continue;
      }

      if (selected == null ||
          rate.effectiveFrom.isAfter(
            selected.effectiveFrom,
          )) {
        selected = rate;
      }
    }

    return selected;
  }

  bool _overlapsPeriod(RentRate rate,
      DateTime periodStart,
      DateTime periodEnd,) {
    final rateStart = _dateOnly(
      rate.effectiveFrom,
    );

    final rateEndExclusive = rate.effectiveTo == null
        ? null
        : _dateOnly(rate.effectiveTo!);

    if (rateEndExclusive != null &&
        !rateEndExclusive.isAfter(periodStart)) {
      return false;
    }

    if (rateStart.isAfter(periodEnd)) {
      return false;
    }

    return true;
  }

  void _validateContinuousCoverage(List<MonthlyRentRateSegment> segments,
      DateTime expectedStart,
      DateTime expectedEnd,) {
    if (segments.isEmpty) {
      throw StateError(
        'Rent-rate segments cannot be empty.',
      );
    }

    if (!_isSameCalendarDay(
      segments.first.start,
      expectedStart,
    )) {
      throw StateError(
        'Rent-rate history does not cover the beginning '
            'of the charge period.',
      );
    }

    if (!_isSameCalendarDay(
      segments.last.end,
      expectedEnd,
    )) {
      throw StateError(
        'Rent-rate history does not cover the end '
            'of the charge period.',
      );
    }

    for (var index = 1; index < segments.length; index++) {
      final previous = segments[index - 1];
      final current = segments[index];

      final expectedNextStart = previous.end.add(
        const Duration(days: 1),
      );

      if (!_isSameCalendarDay(
        current.start,
        expectedNextStart,
      )) {
        throw StateError(
          'Rent-rate history contains a gap between '
              '${_formatDate(previous.end)} and '
              '${_formatDate(current.start)}.',
        );
      }
    }
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  bool _isSameCalendarDay(DateTime first,
      DateTime second,) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }
}