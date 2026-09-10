import '../entities/monthly_rent.dart';
import '../repositories/monthly_rent_repository.dart';

class GetMonthlyRentById {
  final MonthlyRentRepository _repository;

  const GetMonthlyRentById({required this._repository});

  Future<MonthlyRent?> call(String rentId) async {
    final normalizedRentId = rentId.trim();

    if (normalizedRentId.isEmpty) {
      return null;
    }

    return _repository.getMonthlyRentById(normalizedRentId);
  }
}
