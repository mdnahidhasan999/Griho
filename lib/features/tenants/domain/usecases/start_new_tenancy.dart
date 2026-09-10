import '../entities/repositories/tenant_repository.dart';
import '../entities/tenant.dart';

class StartNewTenancy {
  final TenantRepository _repository;

  const StartNewTenancy({
    required this._repository,
  });

  Future<Tenant> call({
    required String tenantId,
    required String propertyId,
    required String unitId,
    required double amount,
  }) async {
    final normalizedTenantId = tenantId.trim();
    final normalizedPropertyId = propertyId.trim();
    final normalizedUnitId = unitId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }

    if (amount <= 0) {
      throw ArgumentError('Rent amount must be greater than zero.');
    }

    return _repository.startNewTenancy(
      tenantId: normalizedTenantId,
      propertyId: normalizedPropertyId,
      unitId: normalizedUnitId,
      amount: amount,
    );
  }
}