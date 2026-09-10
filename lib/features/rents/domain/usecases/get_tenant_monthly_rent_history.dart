import '../entities/monthly_rent.dart';
import '../repositories/monthly_rent_repository.dart';

class GetTenantMonthlyRentHistory {
  final MonthlyRentRepository _repository;

  const GetTenantMonthlyRentHistory({
    required this._repository,
  });

  Future<List<MonthlyRent>> call({
    required String tenantId,
    required String ownerId,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedOwnerId = ownerId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    return _repository.getMonthlyRentHistoryByTenantId(
      tenantId: normalizedTenantId,
      ownerId: normalizedOwnerId,
    );
  }
}