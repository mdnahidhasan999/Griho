import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/monthly_bill.dart';
import '../../domain/usecases/generate_monthly_bills.dart';
import 'billing_rule_provider.dart';
import 'monthly_bill_provider.dart';

final generateMonthlyBillsProvider =
Provider<GenerateMonthlyBills>((ref) {
  final billingRuleRepository =
  ref.read(billingRuleRepositoryProvider);

  final monthlyBillRepository =
  ref.read(monthlyBillRepositoryProvider);

  return GenerateMonthlyBills(
    billingRuleRepository: billingRuleRepository,
    monthlyBillRepository: monthlyBillRepository,
  );
});

/// Generates monthly bills for a property.
///
/// The targets should contain only active tenant/unit
/// combinations that should receive monthly bills.
final generatePropertyMonthlyBillsProvider =
FutureProvider.family<
    List<MonthlyBill>,
    GenerateMonthlyBillsParams>(
      (ref, params) async {
    final generateMonthlyBills =
    ref.read(generateMonthlyBillsProvider);

    return generateMonthlyBills(
      ownerId: params.ownerId,
      propertyId: params.propertyId,
      targets: params.targets,
      billingPeriodStart: params.billingPeriodStart,
      billingPeriodEnd: params.billingPeriodEnd,
      dueDate: params.dueDate,
    );
  },
);

class GenerateMonthlyBillsParams {
  final String ownerId;
  final String propertyId;

  final List<MonthlyBillTarget> targets;

  final DateTime billingPeriodStart;
  final DateTime billingPeriodEnd;
  final DateTime dueDate;

  const GenerateMonthlyBillsParams({
    required this.ownerId,
    required this.propertyId,
    required this.targets,
    required this.billingPeriodStart,
    required this.billingPeriodEnd,
    required this.dueDate,
  });
}