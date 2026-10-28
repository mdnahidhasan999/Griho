import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/payment_workflow_datasource.dart';

final paymentWorkflowDataSourceProvider =
Provider<PaymentWorkflowDataSource>((ref) {
  return PaymentWorkflowDataSource();
});

final tenantPaymentTransactionsProvider =
StreamProvider<QuerySnapshot<Map<String, dynamic>>>((ref) {
  return ref
      .watch(paymentWorkflowDataSourceProvider)
      .watchTenantPayments();
});

final ownerPaymentTransactionsProvider = StreamProvider.family<
    QuerySnapshot<Map<String, dynamic>>,
    ({String ownerId, bool pendingOnly})>((ref, params) {
  return ref.watch(paymentWorkflowDataSourceProvider).watchOwnerPayments(
    ownerId: params.ownerId,
    pendingOnly: params.pendingOnly,
  );
});