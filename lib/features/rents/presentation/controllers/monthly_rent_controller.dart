// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/create_monthly_rent_request.dart';
import '../../domain/entities/monthly_rent.dart';
import '../../domain/usecases/create_monthly_rent.dart';
import '../providers/monthly_rent_provider.dart';

class MonthlyRentController extends Notifier<AsyncValue<void>> {
  late final CreateMonthlyRent _createMonthlyRent;

  @override
  AsyncValue<void> build() {
    _createMonthlyRent = ref.read(createMonthlyRentProvider);
    return const AsyncData(null);
  }

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

  void reset() {
    state = const AsyncData(null);
  }
}
