import '../entities/create_monthly_rent_request.dart';
import '../entities/monthly_rent.dart';
import '../repositories/monthly_rent_repository.dart';

class CreateMonthlyRent {
  final MonthlyRentRepository _repository;

  const CreateMonthlyRent({
    required this._repository,
  });

  Future<MonthlyRent> call(
      CreateMonthlyRentRequest request,
      ) async {
    final ownerId = request.ownerId.trim();
    final propertyId = request.propertyId.trim();
    final unitId = request.unitId.trim();
    final tenantId = request.tenantId.trim();
    final rentRateId = request.rentRateId.trim();

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

    if (rentRateId.isEmpty) {
      throw ArgumentError(
        'Rent rate ID cannot be empty.',
      );
    }

    if (request.monthlyRate <= 0) {
      throw ArgumentError(
        'Monthly rent rate must be greater than zero.',
      );
    }

    if (request.amount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    if (request.chargeableDays <= 0) {
      throw ArgumentError(
        'Chargeable days must be greater than zero.',
      );
    }

    if (request.daysInBillingPeriod <= 0) {
      throw ArgumentError(
        'Billing period days must be greater than zero.',
      );
    }

    if (request.chargeableDays >
        request.daysInBillingPeriod) {
      throw ArgumentError(
        'Chargeable days cannot exceed billing period days.',
      );
    }

    if (!request.billingPeriodEnd.isAfter(
      request.billingPeriodStart,
    )) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    if (request.chargePeriodStart.isBefore(
      request.billingPeriodStart,
    )) {
      throw ArgumentError(
        'Charge period cannot start before the billing period.',
      );
    }

    if (request.chargePeriodEnd.isAfter(
      request.billingPeriodEnd,
    )) {
      throw ArgumentError(
        'Charge period cannot end after the billing period.',
      );
    }

    if (request.chargePeriodEnd.isBefore(
      request.chargePeriodStart,
    )) {
      throw ArgumentError(
        'Charge period end cannot be before charge period start.',
      );
    }

    if (request.dueDate.isBefore(
      request.billingPeriodStart,
    )) {
      throw ArgumentError(
        'Due date cannot be before the billing period starts.',
      );
    }

    final expectedAmount =
        request.monthlyRate *
            request.chargeableDays /
            request.daysInBillingPeriod;

    const amountTolerance = 0.01;

    if ((request.amount - expectedAmount).abs() >
        amountTolerance) {
      throw ArgumentError(
        'Rent amount does not match the expected '
            'prorated rent calculation.',
      );
    }

    return _repository.createMonthlyRent(
      request,
    );
  }
}