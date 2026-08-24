import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../properties/presentation/providers/current_owner_properties_provider.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';

final ownerTenantsProvider = FutureProvider<List<Tenant>>((ref) async {
  // ============================================================
  // 1. Get current owner's properties
  // ============================================================

  final properties = await ref.read(currentOwnerPropertiesProvider.future);

  if (properties.isEmpty) {
    return [];
  }

  // ============================================================
  // 2. Get tenant repository
  // ============================================================

  final repository = ref.read(tenantRepositoryProvider);

  // ============================================================
  // 3. Get tenants from all owner's properties
  // ============================================================

  final tenantLists = await Future.wait(
    properties.map((property) {
      return repository.getTenantsByPropertyId(property.id);
    }),
  );

  // ============================================================
  // 4. Combine all tenants
  // ============================================================

  final tenants = <Tenant>[];

  for (final tenantList in tenantLists) {
    tenants.addAll(tenantList);
  }

  // ============================================================
  // 5. Sort newest first
  // ============================================================

  tenants.sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return tenants;
});
