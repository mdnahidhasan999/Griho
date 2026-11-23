// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/payment_workflow_datasource.dart';

typedef PaymentQuerySnapshot = QuerySnapshot<JsonMap>;

final paymentWorkflowDataSourceProvider = Provider<PaymentWorkflowDataSource>((
  ref,
) {
  return PaymentWorkflowDataSource();
});

final tenantPaymentTransactionsProvider = StreamProvider<PaymentQuerySnapshot>((
  ref,
) {
  // Rebuild stream automatically when the signed-in account changes.
  ref.watch(authStateProvider);
  if (FirebaseAuth.instance.currentUser == null) {
    return const Stream.empty();
  }
  return ref.watch(paymentWorkflowDataSourceProvider).watchTenantPayments();
});

final ownerPaymentTransactionsProvider =
    StreamProvider.family<
      PaymentQuerySnapshot,
      ({String ownerId, bool pendingOnly})
    >((ref, params) {
      ref.watch(authStateProvider);
      if (FirebaseAuth.instance.currentUser == null ||
          params.ownerId.trim().isEmpty) {
        return const Stream.empty();
      }
      return ref
          .watch(paymentWorkflowDataSourceProvider)
          .watchOwnerPayments(
            ownerId: params.ownerId,
            pendingOnly: params.pendingOnly,
          );
    });
