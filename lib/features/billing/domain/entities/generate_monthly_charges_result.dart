import '../../../rents/domain/entities/monthly_rent.dart';
import 'monthly_bill.dart';

class GenerateMonthlyChargesResult {
  final List<MonthlyRent> generatedRents;
  final List<MonthlyBill> generatedBills;

  const GenerateMonthlyChargesResult({
    required this.generatedRents,
    required this.generatedBills,
  });

  int get totalGenerated =>
      generatedRents.length + generatedBills.length;

  bool get isEmpty =>
      generatedRents.isEmpty && generatedBills.isEmpty;
}