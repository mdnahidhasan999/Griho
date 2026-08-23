import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';

final propertyTenantsProvider =
FutureProvider.family<List<Tenant>, String>(
      (ref, propertyId) async {
    final repository = ref.read(
      tenantRepositoryProvider,
    );

    return repository.getTenantsByPropertyId(
      propertyId,
    );
  },
);