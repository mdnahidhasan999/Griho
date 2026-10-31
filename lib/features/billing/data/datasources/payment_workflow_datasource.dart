import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/monthly_bill.dart';

enum PaymentMethod { cash, bank, bkash, nagad, other }

enum PaymentReviewStatus { pending, confirmed, rejected }

class PaymentWorkflowDataSource {
  PaymentWorkflowDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _payments =>
      _firestore.collection('paymentTransactions');

  CollectionReference<Map<String, dynamic>> _billCollection(
      String collectionName,) {
    if (collectionName != 'monthlyBills' &&
        collectionName != 'monthlyRents') {
      throw ArgumentError('Unsupported bill collection.');
    }

    return _firestore.collection(collectionName);
  }

  String _normalizeBillCollection(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return 'monthlyBills';
    }

    if (normalized != 'monthlyBills' &&
        normalized != 'monthlyRents') {
      throw ArgumentError('Unsupported bill collection.');
    }

    return normalized;
  }

  String get _currentUid {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('Please sign in before continuing.');
    }

    return user.uid;
  }

  double _readAmount(Map<String, dynamic> data,
      String field, {
        double? defaultValue,
      }) {
    final value = data[field];

    if (value == null && defaultValue != null) {
      return defaultValue;
    }

    if (value is! num) {
      throw StateError('Invalid bill amount data: $field.');
    }

    final amount = value.toDouble();

    if (!amount.isFinite) {
      throw StateError('Invalid bill amount data: $field.');
    }

    return amount;
  }

  bool _isClosedBill(Map<String, dynamic> bill) {
    final status = bill['status'];

    return status == MonthlyBillStatus.paid.name ||
        status == MonthlyBillStatus.cancelled.name;
  }

  void _validatePaymentAmount({
    required double billAmount,
    required double paidAmount,
    required double pendingAmount,
    required double requestedAmount,
  }) {
    if (billAmount <= 0 ||
        paidAmount < 0 ||
        pendingAmount < 0 ||
        paidAmount + pendingAmount > billAmount + 0.001) {
      throw StateError('Bill amount data is invalid.');
    }

    if (!requestedAmount.isFinite || requestedAmount <= 0) {
      throw ArgumentError(
        'Payment amount must be greater than zero.',
      );
    }

    final remaining = billAmount - paidAmount - pendingAmount;

    if (remaining <= 0 ||
        requestedAmount > remaining + 0.001) {
      throw StateError(
        'Payment exceeds the remaining payable balance.',
      );
    }
  }

  void _validatePaymentOwnership({
    required Map<String, dynamic> bill,
    required Map<String, dynamic> payment,
    required String ownerId,
  }) {
    if (bill['ownerId'] != ownerId ||
        bill['tenantUserId'] != payment['tenantUserId'] ||
        bill['tenantId'] != payment['tenantId'] ||
        bill['propertyId'] != payment['propertyId'] ||
        bill['unitId'] != payment['unitId']) {
      throw StateError('Payment does not match the bill.');
    }
  }

  String? _cleanOptional(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  // ------------------------------------------------------------
  // SUBMIT SINGLE PAYMENT
  // ------------------------------------------------------------

  Future<String> submitPayment({
    required String billId,
    required double amount,
    required PaymentMethod method,
    String billCollection = 'monthlyBills',
    String? reference,
    String? note,
    String? batchId,
  }) async {
    final uid = _currentUid;

    final normalizedBillId = billId.trim();
    final normalizedCollection = _normalizeBillCollection(
      billCollection,
    );

    if (normalizedBillId.isEmpty) {
      throw ArgumentError('Bill ID is required.');
    }

    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError(
        'Payment amount must be greater than zero.',
      );
    }

    final billRef = _billCollection(
      normalizedCollection,
    ).doc(normalizedBillId);

    final paymentRef = _payments.doc();

    final normalizedBatchId =
    batchId
        ?.trim()
        .isNotEmpty == true
        ? batchId!.trim()
        : paymentRef.id;

    await _firestore.runTransaction((transaction) async {
      final billSnapshot = await transaction.get(billRef);

      if (!billSnapshot.exists) {
        throw StateError('Bill not found.');
      }

      final bill = billSnapshot.data()!;

      if (bill['tenantUserId'] != uid) {
        throw StateError(
          'You cannot submit payment for this bill.',
        );
      }

      if (_isClosedBill(bill)) {
        throw StateError(
          'This bill cannot receive payments.',
        );
      }

      final billAmount = _readAmount(bill, 'amount');

      final paidAmount = _readAmount(
        bill,
        'paidAmount',
        defaultValue: 0,
      );

      final pendingAmount = _readAmount(
        bill,
        'pendingPaymentAmount',
        defaultValue: 0,
      );

      _validatePaymentAmount(
        billAmount: billAmount,
        paidAmount: paidAmount,
        pendingAmount: pendingAmount,
        requestedAmount: amount,
      );

      final ownerId = bill['ownerId'];
      final propertyId = bill['propertyId'];
      final unitId = bill['unitId'];
      final tenantId = bill['tenantId'];

      if (ownerId is! String ||
          propertyId is! String ||
          unitId is! String ||
          tenantId is! String) {
        throw StateError('Bill ownership data is invalid.');
      }

      transaction.update(billRef, {
        'pendingPaymentAmount': pendingAmount + amount,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      transaction.set(paymentRef, {
        'batchId': normalizedBatchId,
        'billId': normalizedBillId,
        'ownerId': ownerId,
        'propertyId': propertyId,
        'unitId': unitId,
        'tenantId': tenantId,
        'tenantUserId': uid,
        'amount': amount,
        'billCollection': normalizedCollection,
        'method': method.name,
        'reference': _cleanOptional(reference),
        'note': _cleanOptional(note),
        'status': PaymentReviewStatus.pending.name,
        'reservationApplied': true,
        'rejectionReason': null,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
      });
    });

    return paymentRef.id;
  }

  // ------------------------------------------------------------
  // SUBMIT MULTIPLE PAYMENTS
  // ------------------------------------------------------------

  Future<Map<String, String>> submitPayments({
    required Map<String, double> amountsByBillId,
    required Map<String, String> collectionsByBillId,
    required PaymentMethod method,
    String? reference,
    String? note,
  }) async {
    _currentUid;

    if (amountsByBillId.isEmpty) {
      throw ArgumentError('Select at least one bill.');
    }

    if (amountsByBillId.length != collectionsByBillId.length ||
        amountsByBillId.keys
            .toSet()
            .difference(collectionsByBillId.keys.toSet())
            .isNotEmpty) {
      throw ArgumentError(
        'Every selected bill must have a collection name.',
      );
    }

    final batchId = _payments
        .doc()
        .id;

    final createdPayments = <String, String>{};

    for (final entry in amountsByBillId.entries) {
      final billId = entry.key;

      final paymentId = await submitPayment(
        billId: billId,
        amount: entry.value,
        method: method,
        billCollection: collectionsByBillId[billId]!,
        reference: reference,
        note: note,
        batchId: batchId,
      );

      createdPayments[billId] = paymentId;
    }

    return createdPayments;
  }

  // ------------------------------------------------------------
  // CONFIRM PAYMENT
  // ------------------------------------------------------------

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
        throw StateError(
          'Only the bill owner can confirm payment.',
        );
      }

      if (payment['status'] != PaymentReviewStatus.pending.name) {
        throw StateError(
          'This payment has already been reviewed.',
        );
      }

      final billId = payment['billId'];
      final paymentAmountValue = payment['amount'];

      if (billId is! String ||
          billId.isEmpty ||
          paymentAmountValue is! num) {
        throw StateError('Payment request data is invalid.');
      }

      final paymentAmount = paymentAmountValue.toDouble();

      if (!paymentAmount.isFinite || paymentAmount <= 0) {
        throw StateError('Payment amount is invalid.');
      }

      final billCollection = _normalizeBillCollection(
        payment['billCollection'] as String?,
      );

      final billRef = _billCollection(
        billCollection,
      ).doc(billId);

      final billSnapshot = await transaction.get(billRef);

      if (!billSnapshot.exists) {
        throw StateError('Associated bill not found.');
      }

      final bill = billSnapshot.data()!;

      _validatePaymentOwnership(
        bill: bill,
        payment: payment,
        ownerId: uid,
      );

      if (_isClosedBill(bill)) {
        throw StateError(
          'This bill cannot receive this payment.',
        );
      }

      if (payment['reservationApplied'] != true) {
        throw StateError(
          'Payment reservation is missing. '
              'Please reconcile this payment before confirming.',
        );
      }

      final billAmount = _readAmount(bill, 'amount');

      final paidAmount = _readAmount(
        bill,
        'paidAmount',
        defaultValue: 0,
      );

      final pendingAmount = _readAmount(
        bill,
        'pendingPaymentAmount',
        defaultValue: 0,
      );

      if (pendingAmount + 0.001 < paymentAmount) {
        throw StateError(
          'Payment reservation data is invalid.',
        );
      }

      if (paidAmount + paymentAmount > billAmount + 0.001) {
        throw StateError(
          'Payment exceeds the remaining bill balance.',
        );
      }

      final newPaidAmount = paidAmount + paymentAmount;

      final newPendingAmount =
      (pendingAmount - paymentAmount)
          .clamp(0.0, double.infinity)
          .toDouble();

      final fullyPaid = newPaidAmount >= billAmount - 0.001;

      transaction.update(billRef, {
        'paidAmount': fullyPaid ? billAmount : newPaidAmount,
        'pendingPaymentAmount': newPendingAmount,
        'status': fullyPaid
            ? MonthlyBillStatus.paid.name
            : MonthlyBillStatus.partiallyPaid.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'lastPaymentId': normalizedPaymentId,
      });

      transaction.update(paymentRef, {
        'status': PaymentReviewStatus.confirmed.name,
        'reviewedBy': uid,
        'reservationApplied': false,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ------------------------------------------------------------
  // REJECT PAYMENT
  // ------------------------------------------------------------

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
      throw ArgumentError(
        'Please provide a rejection reason.',
      );
    }

    final paymentRef = _payments.doc(normalizedPaymentId);

    await _firestore.runTransaction((transaction) async {
      final paymentSnapshot = await transaction.get(paymentRef);

      if (!paymentSnapshot.exists) {
        throw StateError('Payment request not found.');
      }

      final payment = paymentSnapshot.data()!;

      if (payment['ownerId'] != uid) {
        throw StateError(
          'Only the bill owner can reject payment.',
        );
      }

      if (payment['status'] != PaymentReviewStatus.pending.name) {
        throw StateError(
          'This payment has already been reviewed.',
        );
      }

      final billId = payment['billId'];
      final paymentAmountValue = payment['amount'];

      if (billId is! String ||
          billId.isEmpty ||
          paymentAmountValue is! num) {
        throw StateError('Payment request data is invalid.');
      }

      final paymentAmount = paymentAmountValue.toDouble();

      if (!paymentAmount.isFinite || paymentAmount <= 0) {
        throw StateError('Payment amount is invalid.');
      }

      final billCollection = _normalizeBillCollection(
        payment['billCollection'] as String?,
      );

      final billRef = _billCollection(
        billCollection,
      ).doc(billId);

      final billSnapshot = await transaction.get(billRef);

      if (!billSnapshot.exists) {
        throw StateError('Associated bill not found.');
      }

      final bill = billSnapshot.data()!;

      _validatePaymentOwnership(
        bill: bill,
        payment: payment,
        ownerId: uid,
      );

      if (payment['reservationApplied'] == true) {
        final pendingAmount = _readAmount(
          bill,
          'pendingPaymentAmount',
          defaultValue: 0,
        );

        if (pendingAmount + 0.001 < paymentAmount) {
          throw StateError(
            'Payment reservation data is invalid.',
          );
        }

        final newPendingAmount =
        (pendingAmount - paymentAmount)
            .clamp(0.0, double.infinity)
            .toDouble();

        transaction.update(billRef, {
          'pendingPaymentAmount': newPendingAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      transaction.update(paymentRef, {
        'status': PaymentReviewStatus.rejected.name,
        'rejectionReason': normalizedReason,
        'reviewedBy': uid,
        'reservationApplied': false,
        'reviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ------------------------------------------------------------
  // TENANT PAYMENT STREAM
  // ------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchTenantPayments() {
    final uid = _currentUid;

    return _payments
        .where('tenantUserId', isEqualTo: uid)
        .snapshots();
  }

  // ------------------------------------------------------------
  // OWNER PAYMENT STREAM
  // ------------------------------------------------------------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchOwnerPayments({
    required String ownerId,
    bool pendingOnly = false,
  }) {
    final uid = _currentUid;
    final normalizedOwnerId = ownerId.trim();

    if (normalizedOwnerId.isEmpty || normalizedOwnerId != uid) {
      throw StateError(
        'You can only view your own property payments.',
      );
    }

    Query<Map<String, dynamic>> query =
    _payments.where('ownerId', isEqualTo: uid);

    if (pendingOnly) {
      query = query.where(
        'status',
        isEqualTo: PaymentReviewStatus.pending.name,
      );
    }

    return query.snapshots();
  }
}