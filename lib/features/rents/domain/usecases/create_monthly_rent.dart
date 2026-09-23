import '../entities/create_monthly_rent_request.dart';
import '../entities/monthly_rent.dart';
import '../repositories/monthly_rent_repository.dart';

class CreateMonthlyRent {
  final MonthlyRentRepository _repository;

  const CreateMonthlyRent({required this._repository});

  Future<MonthlyRent> call(CreateMonthlyRentRequest request) async {
    if (request.ownerId.trim().isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }
    if (request.propertyId.trim().isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (request.unitId.trim().isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    if (request.tenantId.trim().isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    if (request.rentRateId.trim().isEmpty) {
      throw ArgumentError('Rent rate ID cannot be empty.');
    }

    if (request.amount <= 0) {
      throw ArgumentError('Rent amount must be greater than zero.');
    }

    if (!request.billingPeriodEnd.isAfter(request.billingPeriodStart)) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    if (request.dueDate.isBefore(request.billingPeriodStart)) {
      throw ArgumentError(
        'Due date cannot be before the billing period starts.',
      );
    }

    return _repository.createMonthlyRent(request);
  }
}
