import '../entities/rent_rate.dart';
import 'monthly_rent_calculator.dart';
import 'monthly_rent_rate_segment_resolver.dart';
import 'tenancy_billing_period_resolver.dart';

class MonthlyRentGenerationResult {
  final List<MonthlyRentCalculation> calculations;

  const MonthlyRentGenerationResult({
    required this.calculations,
  });

  double get totalAmount {
    return calculations.fold<double>(
      0,
          (total, calculation) =>
      total + calculation.amount,
    );
  }

  int get totalChargeableDays {
    return calculations.fold<int>(
      0,
          (total, calculation) =>
      total + calculation.chargeableDays,
    );
  }
}

class MonthlyRentGenerationCalculator {
  final TenancyBillingPeriodResolver
  _tenancyPeriodResolver;

  final MonthlyRentRateSegmentResolver
  _rateSegmentResolver;

  final MonthlyRentCalculator
  _rentCalculator;

  const MonthlyRentGenerationCalculator({
    TenancyBillingPeriodResolver? tenancyPeriodResolver,
    MonthlyRentRateSegmentResolver? rateSegmentResolver,
    MonthlyRentCalculator? rentCalculator,
  })  : _tenancyPeriodResolver =
      tenancyPeriodResolver ??
          const TenancyBillingPeriodResolver(),
        _rateSegmentResolver =
            rateSegmentResolver ??
                const MonthlyRentRateSegmentResolver(),
        _rentCalculator =
            rentCalculator ??
                const MonthlyRentCalculator();

  MonthlyRentGenerationResult calculate({
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
    required DateTime tenancyStart,
    DateTime? tenancyEnd,
    required List<RentRate> rentRates,
  }) {
    final tenancyPeriod =
    _tenancyPeriodResolver.resolve(
      billingPeriodStart: billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd,
      tenancyStart: tenancyStart,
      tenancyEnd: tenancyEnd,
    );

    if (tenancyPeriod == null) {
      return const MonthlyRentGenerationResult(
        calculations: [],
      );
    }

    final rateSegments =
    _rateSegmentResolver.resolve(
      rentRates: rentRates,
      chargePeriodStart:
      tenancyPeriod.chargePeriodStart,
      chargePeriodEnd:
      tenancyPeriod.chargePeriodEnd,
    );

    final calculations =
    <MonthlyRentCalculation>[];

    for (final segment in rateSegments) {
      final calculation =
      _rentCalculator.calculate(
        monthlyRate: segment.rentRate.amount,
        billingPeriodStart:
        billingPeriodStart,
        billingPeriodEnd:
        billingPeriodEnd,
        tenancyStart:
        segment.start,
        tenancyEnd:
        segment.end,
      );

      calculations.add(calculation);
    }

    return MonthlyRentGenerationResult(
      calculations: calculations,
    );
  }
}