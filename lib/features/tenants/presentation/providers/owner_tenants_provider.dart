// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/tenant_model.dart';
import '../../domain/entities/tenant.dart';

final ownerTenantsProvider = FutureProvider<List<Tenant>>((ref) async {
  final uid = await ref.watch(
    authStateProvider.selectAsync((user) => user?.uid),
  );

  if (uid == null || uid.trim().isEmpty) {
    return const <Tenant>[];
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('tenants')
      .where('ownerId', isEqualTo: uid.trim())
      .limit(200)
      .get();

  final tenants = snapshot.docs.map(TenantModel.fromFirestore).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return tenants;
});
