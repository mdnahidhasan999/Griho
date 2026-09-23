import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/create_monthly_rent_request.dart';
import '../../domain/entities/monthly_rent.dart';
import '../../domain/usecases/create_monthly_rent.dart';

class MonthlyRentController extends StateNotifier<AsyncValue<void>> {
  final CreateMonthlyRent _createMonthlyRent;

  MonthlyRentController({required this._createMonthlyRent})
    : super(const AsyncData(null));

  // ============================================================
  // CREATE MONTHLY RENT
  // ============================================================

  Future<MonthlyRent?> createMonthlyRent({
    required CreateMonthlyRentRequest request,
  }) async {
    state = const AsyncLoading();

    try {
      final monthlyRent = await _createMonthlyRent(request);

      state = const AsyncData(null);

      return monthlyRent;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);

      return null;
    }
  }

  // ============================================================
  // RESET
  // ============================================================

  void reset() {
    state = const AsyncData(null);
  }
}
