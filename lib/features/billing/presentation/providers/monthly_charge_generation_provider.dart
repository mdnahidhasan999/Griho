import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../rents/presentation/providers/monthly_rent_provider.dart';
import '../../domain/usecases/generate_monthly_charges.dart';
import 'monthly_bill_generation_provider.dart';

final generateMonthlyChargesProvider =
Provider<GenerateMonthlyCharges>((ref) {
  return GenerateMonthlyCharges(
    generateMonthlyRent: ref.read(
      generateMonthlyRentProvider,
    ),
    generateMonthlyBills: ref.read(
      generateMonthlyBillsProvider,
    ),
  );
});