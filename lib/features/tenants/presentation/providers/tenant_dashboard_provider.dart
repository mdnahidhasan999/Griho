import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/tenant.dart';
import '../controllers/tenant_controller.dart';

// ============================================================================
// CURRENT TENANT
// ============================================================================
//
// Loads the tenant record linked to the currently authenticated Firebase
// user.
//
// Flow:
// Firebase Auth UID
//      ↓
// TenantRepository.getTenantByUserId()
//      ↓
// Tenant
//
// This provider does not modify any controller state.
// ============================================================================

final currentTenantProvider = FutureProvider<Tenant?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return null;
  }

  final userId = user.uid.trim();

  if (userId.isEmpty) {
    return null;
  }

  final repository = ref.read(tenantRepositoryProvider);

  return repository.getTenantByUserId(userId);
});