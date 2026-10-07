import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tenants/presentation/providers/tenancy_history_provider.dart';
import '../../domain/services/tenancy_billing_target_resolver.dart';

final tenancyBillingTargetResolverProvider =
Provider<TenancyBillingTargetResolver>((ref) {
  return TenancyBillingTargetResolver(
    repository: ref.read(tenancyHistoryRepositoryProvider),
  );
});