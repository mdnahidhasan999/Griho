
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/monthly_bill.dart';

enum PaymentMethod {
  cash,
  bank,
  bkash,
  nagad,
  other,
}

enum PaymentReviewStatus {
  pending,
  confirmed,
  rejected,
}

class PaymentWorkflowDataSource {
  PaymentWorkflowDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('paymentTransactions');

  CollectionReference<Map<String, dynamic>> get _bills =>
      _firestore.collection('monthlyBills');

  String get _currentUid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in before continuing.');
    }
    return user.uid;
  }

  /// Tenant submits a payment claim.
  ///
  /// The bill balance is NOT changed until the owner confirms it.
  Future<String> submitPayment({
    required String billId,
    required double amount,
    required PaymentMethod method,
    String? reference,
    String? note,
  }) async {
    final uid = _currentUid;
    final normalizedBillId = billId.trim();

    if (normalizedBillId.isEmpty) {
      throw ArgumentError('Bill ID is required.');
    }

    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final billRef = _bills.doc(normalizedBillId);
    final paymentRef = _payments.doc();

    await _firestore.runTransaction((transaction) async {
      final billSnapshot = await transaction.get(billRef);

      if (!billSnapshot.exists) {
        throw StateError('Bill not found.');
      }

      final bill = billSnapshot.data()!;
      final tenantUserId = bill['tenantUserId'];
      final status = bill['status'];

      if (tenantUserId is! String || tenantUserId != uid) {
        throw StateError('You cannot submit payment for this bill.');
      }

      if (status == MonthlyBillStatus.paid.name ||
          status == MonthlyBillStatus.cancelled.name) {
        throw StateError('This bill cannot receive payments.');
      }

      final rawAmount = bill['amount'];
      final rawPaidAmount = bill['paidAmount'];

      if (rawAmount is! num || rawPaidAmount is! num) {
        throw StateError('Bill amount data is invalid.');
      }

      final billAmount = rawAmount.toDouble();
      final paidAmount = rawPaidAmount.toDouble();
      final remaining = billAmount - paidAmount;

      if (remaining <= 0 || amount > remaining + 0.001) {
        throw StateError(
          'Payment exceeds the remaining bill balance.',
        );
      }

      transaction.set(paymentRef, {
        'billId': normalizedBillId,
        'ownerId': bill['ownerId'],
        'propertyId': bill['propertyId'],
        'unitId': bill['unitId'],
        'tenantId': bill['tenantId'],
        'tenantUserId': uid,
        'amount': amount,
        'method': method.name,
        'reference': _cleanOptional(reference),
        'note': _cleanOptional(note),
        'status': PaymentReviewStatus.pending.name,
        'rejectionReason': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
      });
    });

    return paymentRef.id;
  }

  /// Owner confirms a pending payment.
  ///
  /// Bill balance and payment status are updated atomically.
  Future<void> confirmPayment({
    required String paymentId,
  }) async {
    final uid = _currentUid;
    final normalizedPaymentId = paymentId.trim();

    if (normalizedPaymentId.isEmpty) {
      throw ArgumentError('Payment ID is required.');
    }

    final paymentRef = _payments.doc(normalizedPaymentId);

    await _firestore.runTransaction((transaction) async {
      final paymentSnapshot = await transaction.get(paymentRef);

      if (!paymentSnapshot.exists) {
        throw StateError('Payment request not found.');
      }

      final payment = paymentSnapshot.data()!;

      if (payment['ownerId'] != uid) {
        throw StateError('Only the bill owner can confirm payment.');
      }

      if (payment['status'] != PaymentReviewStatus.pending.name) {
        throw StateError('This payment has already been reviewed.');
      }

      final billId = payment['billId'];
      final paymentAmount = payment['amount'];

      if (billId is! String ||
          billId.isEmpty ||
          paymentAmount is! num) {
        throw StateError('Payment request data is invalid.');
      }

      final billRef = _bills.doc(billId);

      // All transaction reads happen before any writes.
      final billSnapshot = await transaction.get(billRef);

      if (!billSnapshot.exists) {
        throw StateError('Associated bill not found.');
      }

      final bill = billSnapshot.data()!;

      if (bill['ownerId'] != uid ||
          bill['tenantUserId'] != payment['tenantUserId'] ||
          bill['tenantId'] != payment['tenantId'] ||
          bill['propertyId'] != payment['propertyId'] ||
          bill['unitId'] != payment['unitId']) {
        throw StateError('Payment does not match the bill.');
      }

      if (bill['status'] == MonthlyBillStatus.cancelled.name ||
          bill['status'] == MonthlyBillStatus.paid.name) {
        throw StateError('This bill cannot receive this payment.');
      }

      final rawAmount = bill['amount'];
      final rawPaidAmount = bill['paidAmount'];

      if (rawAmount is! num || rawPaidAmount is! num) {
        throw StateError('Bill amount data is invalid.');
      }

      final totalAmount = rawAmount.toDouble();
      final currentPaid = rawPaidAmount.toDouble();
      final remaining = totalAmount - currentPaid;
      final amountToConfirm = paymentAmount.toDouble();

      if (!amountToConfirm.isFinite ||
          amountToConfirm <= 0 ||
          amountToConfirm > remaining + 0.001) {
        throw StateError(
          'Payment amount is invalid or exceeds the remaining balance.',
        );
      }

      final newPaidAmount = currentPaid + amountToConfirm;
      final fullyPaid = newPaidAmount >= totalAmount - 0.001;

      transaction.update(billRef, {
        'paidAmount': fullyPaid ? totalAmount : newPaidAmount,
        'status': fullyPaid
            ? MonthlyBillStatus.paid.name
            : MonthlyBillStatus.partiallyPaid.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.update(paymentRef, {
        'status': PaymentReviewStatus.confirmed.name,
        'reviewedBy': uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Owner rejects a pending payment claim.
  /// The bill balance remains unchanged.
  Future<void> rejectPayment({
    required String paymentId,
    required String reason,
  }) async {
    final uid = _currentUid;
    final normalizedPaymentId = paymentId.trim();
    final normalizedReason = reason.trim();

    if (normalizedPaymentId.isEmpty) {
      throw ArgumentError('Payment ID is required.');
    }

    if (normalizedReason.isEmpty) {
      throw ArgumentError('Please provide a rejection reason.');
    }

    final paymentRef = _payments.doc(normalizedPaymentId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(paymentRef);

      if (!snapshot.exists) {
        throw StateError('Payment request not found.');
      }

      final payment = snapshot.data()!;

      if (payment['ownerId'] != uid) {
        throw StateError('Only the bill owner can reject payment.');
      }

      if (payment['status'] != PaymentReviewStatus.pending.name) {
        throw StateError('This payment has already been reviewed.');
      }

      transaction.update(paymentRef, {
        'status': PaymentReviewStatus.rejected.name,
        'rejectionReason': normalizedReason,
        'reviewedBy': uid,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Live payment history for the signed-in tenant.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchTenantPayments() {
    final uid = _currentUid;

    return _payments
        .where('tenantUserId', isEqualTo: uid)
        .snapshots();
  }

  /// Live payment history for an owner.
  ///
  /// Set pendingOnly to true to show requests awaiting review.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchOwnerPayments({
    required String ownerId,
    bool pendingOnly = false,
  }) {
    final uid = _currentUid;
    final normalizedOwnerId = ownerId.trim();

    if (normalizedOwnerId.isEmpty || normalizedOwnerId != uid) {
      throw StateError('You can only view your own property payments.');
    }

    Query<Map<String, dynamic>> query = _payments.where(
      'ownerId',
      isEqualTo: uid,
    );

    if (pendingOnly) {
      query = query.where(
        'status',
        isEqualTo: PaymentReviewStatus.pending.name,
      );
    }

    return query.snapshots();
  }

  String? _cleanOptional(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}
