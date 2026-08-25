import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/current_user_service.dart';
import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';

final tenantByPhoneProvider =
FutureProvider.family<Tenant?, String>((ref, phone) async {
  final repository =
  ref.read(tenantRepositoryProvider);

  final ownerId =
      CurrentUserService().requiredUid;

  return repository.findTenantByPhone(
    phone: phone,
    ownerId: ownerId,
  );
});