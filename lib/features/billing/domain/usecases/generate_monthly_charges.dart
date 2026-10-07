import '../../../rents/domain/entities/generate_monthly_rent_request.dart';
import '../../../rents/domain/entities/monthly_rent.dart';
import '../../../rents/domain/usecases/generate_monthly_rent.dart';
import '../../../tenants/domain/entities/tenancy_billing_target.dart';
import '../entities/generate_monthly_charges_result.dart';
import 'generate_monthly_bills.dart';

class GenerateMonthlyCharges {
  final GenerateMonthlyRent _generateMonthlyRent;
  final GenerateMonthlyBills _generateMonthlyBills;

  const GenerateMonthlyCharges({
    required this._generateMonthlyRent,
    required this._generateMonthlyBills,
  });

  Future<GenerateMonthlyChargesResult> call({
    required String ownerId,
    required String propertyId,
    required List<TenancyBillingTarget> tenancyTargets,
    required DateTime billingPeriodStart,
    required DateTime billingPeriodEnd,
    required DateTime dueDate,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedPropertyId = propertyId.trim();

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (!billingPeriodEnd.isAfter(billingPeriodStart)) {
      throw ArgumentError(
        'Billing period end must be after billing period start.',
      );
    }

    if (dueDate.isBefore(billingPeriodStart)) {
      throw ArgumentError(
        'Due date cannot be before the billing period starts.',
      );
    }

    final generatedRents = <MonthlyRent>[];

    for (final target in tenancyTargets) {
      final unitId = target.unitId.trim();
      final tenantId = target.tenantId.trim();

      if (unitId.isEmpty) {
        throw ArgumentError(
          'Unit ID cannot be empty in tenancy billing target.',
        );
      }

      if (tenantId.isEmpty) {
        throw ArgumentError(
          'Tenant ID cannot be empty in tenancy billing target.',
        );
      }

      final rentRequest = GenerateMonthlyRentRequest(
        ownerId: normalizedOwnerId,
        propertyId: normalizedPropertyId,
        unitId: unitId,
        tenantId: tenantId,
        tenantUserId: target.tenantUserId?.trim(),
        billingPeriodStart: billingPeriodStart,
        billingPeriodEnd: billingPeriodEnd,
        dueDate: dueDate,
        tenancyStart: target.tenancyStart,
        tenancyEnd: target.tenancyEnd,
      );

      final rents = await _generateMonthlyRent(rentRequest);

      generatedRents.addAll(rents);
    }

    final billTargets = <MonthlyBillTarget>[
      for (final target in tenancyTargets)
        MonthlyBillTarget(
          floorId: target.floorId.trim(),
          unitId: target.unitId.trim(),
          tenantId: target.tenantId.trim(),
          tenantUserId: target.tenantUserId?.trim(),
        ),
    ];

    final generatedBills = await _generateMonthlyBills(
      ownerId: normalizedOwnerId,
      propertyId: normalizedPropertyId,
      targets: billTargets,
      billingPeriodStart: billingPeriodStart,
      billingPeriodEnd: billingPeriodEnd,
      dueDate: dueDate,
    );

    return GenerateMonthlyChargesResult(
      generatedRents: generatedRents,
      generatedBills: generatedBills,
    );
  }
}