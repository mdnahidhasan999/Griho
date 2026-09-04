import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/search_registered_tenant.dart';
import '../controllers/tenant_controller.dart';

final searchRegisteredTenantProvider = Provider<SearchRegisteredTenant>((ref) {
  return SearchRegisteredTenant(repository: ref.read(tenantRepositoryProvider));
});
