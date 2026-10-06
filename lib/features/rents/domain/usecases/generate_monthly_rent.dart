import '../entities/create_monthly_rent_request.dart';
import '../entities/generate_monthly_rent_request.dart';
import '../entities/monthly_rent.dart';
import '../entities/rent_rate.dart';
import '../repositories/monthly_rent_repository.dart';
import '../repositories/rent_rate_repository.dart';
import '../services/monthly_rent_generation_calculator.dart';

class GenerateMonthlyRent {
  final MonthlyRentRepository _monthlyRentRepository;
  final RentRateRepository _rentRateRepository;
  final MonthlyRentGenerationCalculator _calculator;

  const GenerateMonthlyRent({
    required this._monthlyRentRepository,
    required this._rentRateRepository,
    MonthlyRentGenerationCalculator? calculator,
  }) : _calculator =
      calculator ??
          const MonthlyRentGenerationCalculator();

  Future<List<MonthlyRent>> call(GenerateMonthlyRentRequest request,) async {
    final ownerId = request.ownerId.trim();
    final propertyId = request.propertyId.trim();
    final unitId = request.unitId.trim();
    final tenantId = request.tenantId.trim();

    // ------------------------------------------------------------------------
    // Basic validation
    // ------------------------------------------------------------------------

    if (ownerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (propertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (unitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (tenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    // ------------------------------------------------------------------------
    // Billing period
    //
    // billingPeriodEnd is EXCLUSIVE.
    //
    // Example:
    // 2026-09-01 -> 2026-10-01
    // means September 2026.
    // ------------------------------------------------------------------------

    if (!request.billingPeriodEnd.isAfter(
      request.billingPeriodStart,
    )) {
      throw ArgumentError(
        'Billing period end must be after '
            'billing period start.',
      );
    }

    // ------------------------------------------------------------------------
    // Tenancy period
    //
    // tenancyStart = inclusive
    // tenancyEnd   = inclusive
    // ------------------------------------------------------------------------

    if (request.tenancyEnd != null &&
        request.tenancyEnd!.isBefore(
          request.tenancyStart,
        )) {
      throw ArgumentError(
        'Tenancy end cannot be before tenancy start.',
      );
    }

    // ------------------------------------------------------------------------
    // Due date
    //
    // Due date must be inside the billing period.
    // ------------------------------------------------------------------------

    if (request.dueDate.isBefore(
      request.billingPeriodStart,
    )) {
      throw ArgumentError(
        'Due date cannot be before '
            'the billing period starts.',
      );
    }

    if (!request.dueDate.isBefore(
      request.billingPeriodEnd,
    )) {
      throw ArgumentError(
        'Due date must be within '
            'the billing period.',
      );
    }

    // ------------------------------------------------------------------------
    // Load complete rent-rate history.
    // ------------------------------------------------------------------------

    final rentRates =
    await _rentRateRepository.getRentRateHistoryByUnitId(
      ownerId: ownerId,
      unitId: unitId,
    );

    if (rentRates.isEmpty) {
      throw StateError(
        'No rent rate history is available '
            'for this unit.',
      );
    }

    // ------------------------------------------------------------------------
    // Calculate rent for the tenancy period and
    // all applicable rent-rate segments.
    // ------------------------------------------------------------------------

    final result = _calculator.calculate(
      billingPeriodStart: request.billingPeriodStart,
      billingPeriodEnd: request.billingPeriodEnd,
      tenancyStart: request.tenancyStart,
      tenancyEnd: request.tenancyEnd,
      rentRates: rentRates,
    );

    if (result.calculations.isEmpty) {
      return const <MonthlyRent>[];
    }

    final createdRents = <MonthlyRent>[];

    // ------------------------------------------------------------------------
    // Create MonthlyRent for every calculated segment.
    // ------------------------------------------------------------------------

    for (final calculation in result.calculations) {
      final matchingRate = _findMatchingRate(
        rentRates: rentRates,
        chargePeriodStart:
        calculation.chargePeriodStart,
        chargePeriodEnd:
        calculation.chargePeriodEnd,
      );

      if (matchingRate == null) {
        throw StateError(
          'Unable to resolve the rent rate for '
              'charge period '
              '${_formatDate(calculation.chargePeriodStart)} '
              '- '
              '${_formatDate(calculation.chargePeriodEnd)}.',
        );
      }

      // Defensive validation.
      //
      // The rate used to create the MonthlyRent must match
      // the rate used by the calculation.
      if ((matchingRate.amount -
          calculation.monthlyRate)
          .abs() >
          0.01) {
        throw StateError(
          'Rent rate mismatch detected for '
              'charge period '
              '${_formatDate(calculation.chargePeriodStart)} '
              '- '
              '${_formatDate(calculation.chargePeriodEnd)}.',
        );
      }

      final createRequest =
      CreateMonthlyRentRequest(
        ownerId: ownerId,
        propertyId: propertyId,
        unitId: unitId,
        tenantId: tenantId,
        tenantUserId: request.tenantUserId,
        rentRateId: matchingRate.id,
        monthlyRate: calculation.monthlyRate,
        amount: calculation.amount,
        chargeableDays:
        calculation.chargeableDays,
        daysInBillingPeriod:
        calculation.daysInBillingPeriod,
        chargePeriodStart:
        calculation.chargePeriodStart,
        chargePeriodEnd:
        calculation.chargePeriodEnd,
        billingPeriodStart:
        request.billingPeriodStart,
        billingPeriodEnd:
        request.billingPeriodEnd,
        dueDate: request.dueDate,
        status: MonthlyRentStatus.unpaid,
      );

      final monthlyRent =
      await _monthlyRentRepository
          .createMonthlyRent(
        createRequest,
      );

      createdRents.add(monthlyRent);
    }

    return createdRents;
  }

  // ==========================================================================
  // RATE RESOLUTION
  // ==========================================================================

  RentRate? _findMatchingRate({
    required List<RentRate> rentRates,
    required DateTime chargePeriodStart,
    required DateTime chargePeriodEnd,
  }) {
    final start = _dateOnly(
      chargePeriodStart,
    );

    final end = _dateOnly(
      chargePeriodEnd,
    );

    RentRate? selectedRate;

    for (final rate in rentRates) {
      final effectiveFrom = _dateOnly(
        rate.effectiveFrom,
      );

      final effectiveTo = rate.effectiveTo == null
          ? null
          : _dateOnly(
        rate.effectiveTo!,
      );

      // Rate must have started on or before
      // the charge period.
      if (effectiveFrom.isAfter(start)) {
        continue;
      }

      // effectiveTo is EXCLUSIVE.
      //
      // Example:
      // effectiveTo = 2026-10-10
      // means the rate applies through Oct 9.
      if (effectiveTo != null &&
          !start.isBefore(effectiveTo)) {
        continue;
      }

      // The rate must cover the charge period.
      if (effectiveTo != null &&
          !end.isBefore(effectiveTo)) {
        continue;
      }

      // If multiple rates somehow match,
      // select the latest effective rate.
      if (selectedRate == null ||
          rate.effectiveFrom.isAfter(
            selectedRate.effectiveFrom,
          )) {
        selectedRate = rate;
      }
    }

    return selectedRate;
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
    );
  }

  String _formatDate(DateTime date) {
    final normalized = _dateOnly(date);

    return '${normalized.year}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }
}