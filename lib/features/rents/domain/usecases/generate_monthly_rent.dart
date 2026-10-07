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
  }) : _calculator = calculator ?? const MonthlyRentGenerationCalculator();

  Future<List<MonthlyRent>> call(GenerateMonthlyRentRequest request) async {
    final ownerId = request.ownerId.trim();
    final propertyId = request.propertyId.trim();
    final unitId = request.unitId.trim();
    final tenantId = request.tenantId.trim();

    // ------------------------------------------------------------------------
    // Basic validation
    // ------------------------------------------------------------------------

    if (ownerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    if (propertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (unitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    if (tenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    // ------------------------------------------------------------------------
    // Billing period
    //
    // billingPeriodStart = inclusive
    // billingPeriodEnd   = exclusive
    //
    // Example:
    //
    // 2026-09-01 -> 2026-10-01
    //
    // means September 2026.
    // ------------------------------------------------------------------------

    if (!request.billingPeriodEnd.isAfter(request.billingPeriodStart)) {
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
        request.tenancyEnd!.isBefore(request.tenancyStart)) {
      throw ArgumentError('Tenancy end cannot be before tenancy start.');
    }

    // ------------------------------------------------------------------------
    // Due date
    //
    // The due date is NOT required to be inside the billing period.
    //
    // Example:
    //
    // October billing:
    // billingPeriodStart = 2026-10-01
    // billingPeriodEnd   = 2026-11-01
    // dueDate            = 2026-11-10
    //
    // This is valid.
    //
    // The only invalid case here is a due date before the beginning
    // of the billing period.
    // ------------------------------------------------------------------------

    if (request.dueDate.isBefore(request.billingPeriodStart)) {
      throw ArgumentError(
        'Due date cannot be before '
        'the billing period starts.',
      );
    }

    // ------------------------------------------------------------------------
    // Load complete rent-rate history.
    // ------------------------------------------------------------------------

    final rentRates = await _rentRateRepository.getRentRateHistoryByUnitId(
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

    // ------------------------------------------------------------------------
    // Load existing rents for this unit and billing period once.
    //
    // This makes generation idempotent:
    //
    // - Existing historical rent remains untouched.
    // - Missing charge segments can still be generated.
    // - Re-running the same generation does not create duplicates.
    // ------------------------------------------------------------------------

    final existingRents = await _monthlyRentRepository
        .getMonthlyRentsByUnitAndPeriod(
          ownerId: ownerId,
          unitId: unitId,
          billingPeriodStart: request.billingPeriodStart,
        );

    final createdRents = <MonthlyRent>[];

    // ------------------------------------------------------------------------
    // Create MonthlyRent for every calculated segment.
    // ------------------------------------------------------------------------

    for (final calculation in result.calculations) {
      final matchingRate = _findMatchingRate(
        rentRates: rentRates,
        chargePeriodStart: calculation.chargePeriodStart,
        chargePeriodEnd: calculation.chargePeriodEnd,
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

      // ----------------------------------------------------------------------
      // Defensive rate validation
      //
      // The rent rate stored in MonthlyRent must be the same rate
      // that was used by the calculator.
      // ----------------------------------------------------------------------

      if ((matchingRate.amount - calculation.monthlyRate).abs() > 0.01) {
        throw StateError(
          'Rent rate mismatch detected for '
          'charge period '
          '${_formatDate(calculation.chargePeriodStart)} '
          '- '
          '${_formatDate(calculation.chargePeriodEnd)}.',
        );
      }

      // ----------------------------------------------------------------------
      // Idempotency check
      //
      // A tenant may have multiple rent segments in the same billing month
      // because of:
      //
      // 1. Mid-month tenancy changes.
      // 2. Mid-month rent-rate changes.
      //
      // Therefore we identify an existing rent by:
      //
      // owner + unit + tenant + exact charge period.
      //
      // Existing records are historical and must never be modified.
      // ----------------------------------------------------------------------

      final alreadyExists = _hasExistingCharge(
        existingRents: existingRents,
        tenantId: tenantId,
        chargePeriodStart: calculation.chargePeriodStart,
        chargePeriodEnd: calculation.chargePeriodEnd,
      );

      if (alreadyExists) {
        continue;
      }

      final createRequest = CreateMonthlyRentRequest(
        ownerId: ownerId,
        propertyId: propertyId,
        unitId: unitId,
        tenantId: tenantId,
        tenantUserId: request.tenantUserId,
        rentRateId: matchingRate.id,
        monthlyRate: calculation.monthlyRate,
        amount: calculation.amount,
        chargeableDays: calculation.chargeableDays,
        daysInBillingPeriod: calculation.daysInBillingPeriod,
        chargePeriodStart: calculation.chargePeriodStart,
        chargePeriodEnd: calculation.chargePeriodEnd,
        billingPeriodStart: request.billingPeriodStart,
        billingPeriodEnd: request.billingPeriodEnd,
        dueDate: request.dueDate,
        status: MonthlyRentStatus.unpaid,
      );

      try {
        final monthlyRent = await _monthlyRentRepository.createMonthlyRent(
          createRequest,
        );

        createdRents.add(monthlyRent);
      } on StateError catch (error) {
        // --------------------------------------------------------------------
        // Race-condition protection
        //
        // Another generation request may have created this exact rent
        // between our read/check above and this create operation.
        //
        // The datasource transaction is still the final duplicate guard.
        //
        // Only the known duplicate error is ignored.
        // Any other StateError must still propagate.
        // --------------------------------------------------------------------

        if (!_isDuplicateError(error)) {
          rethrow;
        }
      }
    }

    return createdRents;
  }

  // ==========================================================================
  // EXISTING CHARGE CHECK
  // ==========================================================================

  bool _hasExistingCharge({
    required List<MonthlyRent> existingRents,
    required String tenantId,
    required DateTime chargePeriodStart,
    required DateTime chargePeriodEnd,
  }) {
    final normalizedTenantId = tenantId.trim();
    final normalizedStart = _dateOnly(chargePeriodStart);
    final normalizedEnd = _dateOnly(chargePeriodEnd);

    for (final existingRent in existingRents) {
      if (existingRent.tenantId.trim() != normalizedTenantId) {
        continue;
      }

      if (!_isSameDate(existingRent.chargePeriodStart, normalizedStart)) {
        continue;
      }

      if (!_isSameDate(existingRent.chargePeriodEnd, normalizedEnd)) {
        continue;
      }

      return true;
    }

    return false;
  }

  // ==========================================================================
  // DUPLICATE ERROR CHECK
  // ==========================================================================

  bool _isDuplicateError(StateError error) {
    return error.message ==
        'Monthly rent already exists for this tenant and charge period.';
  }

  // ==========================================================================
  // RATE RESOLUTION
  // ==========================================================================

  RentRate? _findMatchingRate({
    required List<RentRate> rentRates,
    required DateTime chargePeriodStart,
    required DateTime chargePeriodEnd,
  }) {
    final start = _dateOnly(chargePeriodStart);
    final end = _dateOnly(chargePeriodEnd);

    RentRate? selectedRate;

    for (final rate in rentRates) {
      final effectiveFrom = _dateOnly(rate.effectiveFrom);

      final effectiveTo = rate.effectiveTo == null
          ? null
          : _dateOnly(rate.effectiveTo!);

      // ----------------------------------------------------------------------
      // effectiveFrom is inclusive.
      //
      // Example:
      // effectiveFrom = 2026-10-10
      //
      // The rate can apply from October 10 onward.
      // ----------------------------------------------------------------------

      if (effectiveFrom.isAfter(start)) {
        continue;
      }

      // ----------------------------------------------------------------------
      // effectiveTo is EXCLUSIVE.
      //
      // Example:
      //
      // effectiveTo = 2026-10-10
      //
      // means the rate applies through October 9.
      // ----------------------------------------------------------------------

      if (effectiveTo != null && !start.isBefore(effectiveTo)) {
        continue;
      }

      // ----------------------------------------------------------------------
      // The complete charge period must be covered by this rate.
      // ----------------------------------------------------------------------

      if (effectiveTo != null && !end.isBefore(effectiveTo)) {
        continue;
      }

      // ----------------------------------------------------------------------
      // If multiple rates somehow match, select the latest
      // effective rate.
      // ----------------------------------------------------------------------

      if (selectedRate == null ||
          rate.effectiveFrom.isAfter(selectedRate.effectiveFrom)) {
        selectedRate = rate;
      }
    }

    return selectedRate;
  }

  // ==========================================================================
  // DATE HELPERS
  // ==========================================================================

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDate(DateTime first, DateTime second) {
    final firstDate = _dateOnly(first);
    final secondDate = _dateOnly(second);

    return firstDate.year == secondDate.year &&
        firstDate.month == secondDate.month &&
        firstDate.day == secondDate.day;
  }

  String _formatDate(DateTime date) {
    final normalized = _dateOnly(date);

    return '${normalized.year}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }
}
