// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/monthly_bill.dart';

typedef JsonMap = Map<String, dynamic>;
typedef StringMap = Map<String, String>;
typedef DoubleMap = Map<String, double>;
typedef PaymentQueryStream = Stream<QuerySnapshot<JsonMap>>;

enum PaymentMethod { cash, bank, bkash, nagad, other }

enum PaymentReviewStatus { pending, confirmed, rejected }

class PaymentWorkflowDataSource {
  PaymentWorkflowDataSource({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<JsonMap> get _payments =>
      _firestore.collection('paymentTransactions');

  CollectionReference<JsonMap> get _managerAccess =>
      _firestore.collection('managerAccess');

  CollectionReference<JsonMap> _billCollection(String collectionName) {
    if (collectionName != 'monthlyBills' && collectionName != 'monthlyRents') {
      throw ArgumentError('Unsupported bill collection.');
    }
    return _firestore.collection(collectionName);
  }

  String _normalizeBillCollection(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return 'monthlyBills';
    }
    if (normalized != 'monthlyBills' && normalized != 'monthlyRents') {
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

  Future<bool> _canReviewPropertyPayment({
    required String uid,
    required String ownerId,
    required String propertyId,
  }) async {
    if (uid == ownerId) {
      return true;
    }
    final accessDoc = await _managerAccess.doc('${uid}_$propertyId').get();
    return accessDoc.exists && accessDoc.data()?['status'] == 'active';
  }

  double _readAmount(JsonMap data, String field, {double? defaultValue}) {
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

  bool _isClosedBill(JsonMap bill) {
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
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final remaining = billAmount - paidAmount - pendingAmount;
    if (remaining <= 0 || requestedAmount > remaining + 0.001) {
      throw StateError('Payment exceeds the remaining payable balance.');
    }
  }

  void _validatePaymentOwnership({
    required JsonMap bill,
    required JsonMap payment,
  }) {
    if (bill['ownerId'] != payment['ownerId'] ||
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
    String? proofUrl,
  }) async {
    final result = await submitPayments(
      amountsByBillId: {billId: amount},
      collectionsByBillId: {billId: billCollection},
      method: method,
      reference: reference,
      note: note,
      batchId: batchId,
      proofUrl: proofUrl,
    );
    return result[billId.trim()]!;
  }

  // ------------------------------------------------------------
  // SUBMIT MULTIPLE PAYMENTS (SINGLE ATOMIC TRANSACTION, NO DOUBLE BILL READS)
  // ------------------------------------------------------------
  Future<StringMap> submitPayments({
    required DoubleMap amountsByBillId,
    required StringMap collectionsByBillId,
    required PaymentMethod method,
    String? reference,
    String? note,
    String? batchId,
    String? proofUrl,
  }) async {
    final uid = _currentUid;

    if (amountsByBillId.isEmpty) {
      throw ArgumentError('Select at least one bill.');
    }

    if (amountsByBillId.length != collectionsByBillId.length ||
        amountsByBillId.keys
            .toSet()
            .difference(collectionsByBillId.keys.toSet())
            .isNotEmpty) {
      throw ArgumentError('Every selected bill must have a collection name.');
    }

    final normalizedBatchId = batchId?.trim().isNotEmpty == true
        ? batchId!.trim()
        : _payments.doc().id;

    String grihoId = '—';
    String tenantName = 'Resident';
    final userDoc = await _firestore.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      final uData = userDoc.data()!;
      grihoId = (uData['publicId'] ?? uData['phoneNumber'] ?? '—').toString();
      tenantName = (uData['name'] ?? 'Resident').toString();
    }

    final entries = <_PreparedPaymentItem>[];
    for (final entry in amountsByBillId.entries) {
      final normalizedBillId = entry.key.trim();
      if (normalizedBillId.isEmpty) {
        throw ArgumentError('Bill ID is required.');
      }

      final requestedAmount = entry.value;
      if (!requestedAmount.isFinite || requestedAmount <= 0) {
        throw ArgumentError('Payment amount must be greater than zero.');
      }

      final normalizedCollection = _normalizeBillCollection(
        collectionsByBillId[entry.key],
      );

      entries.add(
        _PreparedPaymentItem(
          billId: normalizedBillId,
          collectionName: normalizedCollection,
          billRef: _billCollection(normalizedCollection).doc(normalizedBillId),
          paymentRef: _payments.doc(),
          requestedAmount: requestedAmount,
        ),
      );
    }

    final createdPayments = <String, String>{};
    final cleanedRef = _cleanOptional(reference);
    final cleanedNote = _cleanOptional(note);
    final cleanedProof = _cleanOptional(proofUrl);

    await _firestore.runTransaction((transaction) async {
      // 1. Read every target bill once inside the transaction.
      final billSnapshots = <DocumentSnapshot<JsonMap>>[];
      for (final item in entries) {
        billSnapshots.add(await transaction.get(item.billRef));
      }

      // 2. Validate bills and collect unique property/unit IDs.
      final validatedBills = <JsonMap>[];
      final uniquePropertyIds = <String>{};
      final uniqueUnitIds = <String>{};

      for (var i = 0; i < entries.length; i++) {
        final item = entries[i];
        final snap = billSnapshots[i];

        if (!snap.exists || snap.data() == null) {
          throw StateError('Bill ${item.billId} no longer exists.');
        }

        final bill = snap.data()!;
        if (bill['tenantUserId'] != uid) {
          throw StateError('You cannot submit payment for this bill.');
        }

        if (_isClosedBill(bill)) {
          throw StateError('This bill cannot receive payments.');
        }

        final billAmount = _readAmount(bill, 'amount');
        final paidAmount = _readAmount(bill, 'paidAmount', defaultValue: 0);
        final pendingAmount = _readAmount(
          bill,
          'pendingPaymentAmount',
          defaultValue: 0,
        );

        _validatePaymentAmount(
          billAmount: billAmount,
          paidAmount: paidAmount,
          pendingAmount: pendingAmount,
          requestedAmount: item.requestedAmount,
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

        if (propertyId.trim().isNotEmpty) {
          uniquePropertyIds.add(propertyId.trim());
        }
        if (unitId.trim().isNotEmpty) {
          uniqueUnitIds.add(unitId.trim());
        }

        validatedBills.add(bill);
      }

      // 3. Read unique property & unit names inside the transaction (before writes).
      final propertyNameCache = <String, String>{};
      for (final propertyId in uniquePropertyIds) {
        final propDoc = await transaction.get(
          _firestore.collection('properties').doc(propertyId),
        );
        propertyNameCache[propertyId] = (propDoc.data()?['name'] ?? 'Property')
            .toString();
      }

      final unitNameCache = <String, String>{};
      for (final unitId in uniqueUnitIds) {
        final unitDoc = await transaction.get(
          _firestore.collection('units').doc(unitId),
        );
        final uData = unitDoc.data();
        unitNameCache[unitId] =
            (uData?['name'] ??
                    (uData?['unitNumber'] != null
                        ? 'Unit ${uData?['unitNumber']}'
                        : 'Unit'))
                .toString();
      }

      // 4. Perform all writes atomically.
      for (var i = 0; i < entries.length; i++) {
        final item = entries[i];
        final bill = validatedBills[i];
        final pendingAmount = _readAmount(
          bill,
          'pendingPaymentAmount',
          defaultValue: 0,
        );

        final propertyId = (bill['propertyId'] as String).trim();
        final unitId = (bill['unitId'] as String).trim();
        final billType = item.collectionName == 'monthlyRents'
            ? 'rent'
            : (bill['type'] ?? 'utility').toString();

        transaction.update(item.billRef, {
          'pendingPaymentAmount': pendingAmount + item.requestedAmount,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.set(item.paymentRef, {
          'batchId': normalizedBatchId,
          'billId': item.billId,
          'billType': billType,
          'billTitle': bill['title'],
          'billingPeriodStart': bill['billingPeriodStart'],
          'ownerId': bill['ownerId'],
          'propertyId': propertyId,
          'propertyName': propertyNameCache[propertyId] ?? 'Property',
          'unitId': unitId,
          'unitName': unitNameCache[unitId] ?? 'Unit',
          'tenantId': bill['tenantId'],
          'tenantName': tenantName,
          'grihoId': grihoId,
          'tenantUserId': uid,
          'amount': item.requestedAmount,
          'billCollection': item.collectionName,
          'method': method.name,
          'reference': cleanedRef,
          'note': cleanedNote,
          'proofUrl': cleanedProof,
          'status': PaymentReviewStatus.pending.name,
          'reservationApplied': true,
          'rejectionReason': null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'reviewedAt': null,
          'reviewedBy': null,
        });

        createdPayments[item.billId] = item.paymentRef.id;
      }
    });

    return createdPayments;
  }

  // ------------------------------------------------------------
  // CONFIRM PAYMENT (OWNER OR ACTIVE MANAGER)
  // ------------------------------------------------------------
  Future<void> confirmPayment({required String paymentId}) async {
    final uid = _currentUid;
    final normalizedPaymentId = paymentId.trim();

    if (normalizedPaymentId.isEmpty) {
      throw ArgumentError('Payment ID is required.');
    }

    final paymentRef = _payments.doc(normalizedPaymentId);
    final preSnap = await paymentRef.get();
    if (!preSnap.exists || preSnap.data() == null) {
      throw StateError('Payment request not found.');
    }

    final preData = preSnap.data()!;
    final authorized = await _canReviewPropertyPayment(
      uid: uid,
      ownerId: (preData['ownerId'] ?? '').toString(),
      propertyId: (preData['propertyId'] ?? '').toString(),
    );

    if (!authorized) {
      throw StateError(
        'Only the property owner or an active manager can confirm payment.',
      );
    }

    await _firestore.runTransaction((transaction) async {
      final paymentSnapshot = await transaction.get(paymentRef);
      if (!paymentSnapshot.exists || paymentSnapshot.data() == null) {
        throw StateError('Payment request not found.');
      }

      final payment = paymentSnapshot.data()!;
      if (payment['status'] != PaymentReviewStatus.pending.name) {
        throw StateError('This payment has already been reviewed.');
      }

      final billId = payment['billId'];
      final paymentAmountValue = payment['amount'];

      if (billId is! String || billId.isEmpty || paymentAmountValue is! num) {
        throw StateError('Payment request data is invalid.');
      }

      final paymentAmount = paymentAmountValue.toDouble();
      if (!paymentAmount.isFinite || paymentAmount <= 0) {
        throw StateError('Payment amount is invalid.');
      }

      final billCollection = _normalizeBillCollection(
        payment['billCollection'] as String?,
      );

      final billRef = _billCollection(billCollection).doc(billId);
      final billSnapshot = await transaction.get(billRef);

      if (!billSnapshot.exists || billSnapshot.data() == null) {
        throw StateError('Associated bill not found.');
      }

      final bill = billSnapshot.data()!;
      _validatePaymentOwnership(bill: bill, payment: payment);

      if (_isClosedBill(bill)) {
        throw StateError('This bill cannot receive this payment.');
      }

      if (payment['reservationApplied'] != true) {
        throw StateError('Payment reservation is missing.');
      }

      final billAmount = _readAmount(bill, 'amount');
      final paidAmount = _readAmount(bill, 'paidAmount', defaultValue: 0);
      final pendingAmount = _readAmount(
        bill,
        'pendingPaymentAmount',
        defaultValue: 0,
      );

      if (pendingAmount + 0.001 < paymentAmount) {
        throw StateError('Payment reservation data is invalid.');
      }

      if (paidAmount + paymentAmount > billAmount + 0.001) {
        throw StateError('Payment exceeds the remaining bill balance.');
      }

      final newPaidAmount = paidAmount + paymentAmount;
      final newPendingAmount = (pendingAmount - paymentAmount)
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
  // REJECT PAYMENT (OWNER OR ACTIVE MANAGER)
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
      throw ArgumentError('Please provide a rejection reason.');
    }

    final paymentRef = _payments.doc(normalizedPaymentId);
    final preSnap = await paymentRef.get();
    if (!preSnap.exists || preSnap.data() == null) {
      throw StateError('Payment request not found.');
    }

    final preData = preSnap.data()!;
    final authorized = await _canReviewPropertyPayment(
      uid: uid,
      ownerId: (preData['ownerId'] ?? '').toString(),
      propertyId: (preData['propertyId'] ?? '').toString(),
    );

    if (!authorized) {
      throw StateError(
        'Only the property owner or an active manager can reject payment.',
      );
    }

    await _firestore.runTransaction((transaction) async {
      final paymentSnapshot = await transaction.get(paymentRef);
      if (!paymentSnapshot.exists || paymentSnapshot.data() == null) {
        throw StateError('Payment request not found.');
      }

      final payment = paymentSnapshot.data()!;
      if (payment['status'] != PaymentReviewStatus.pending.name) {
        throw StateError('This payment has already been reviewed.');
      }

      final billId = payment['billId'];
      final paymentAmountValue = payment['amount'];

      if (billId is! String || billId.isEmpty || paymentAmountValue is! num) {
        throw StateError('Payment request data is invalid.');
      }

      final paymentAmount = paymentAmountValue.toDouble();
      if (!paymentAmount.isFinite || paymentAmount <= 0) {
        throw StateError('Payment amount is invalid.');
      }

      final billCollection = _normalizeBillCollection(
        payment['billCollection'] as String?,
      );

      final billRef = _billCollection(billCollection).doc(billId);
      final billSnapshot = await transaction.get(billRef);

      if (!billSnapshot.exists || billSnapshot.data() == null) {
        throw StateError('Associated bill not found.');
      }

      final bill = billSnapshot.data()!;
      _validatePaymentOwnership(bill: bill, payment: payment);

      if (payment['reservationApplied'] == true) {
        final pendingAmount = _readAmount(
          bill,
          'pendingPaymentAmount',
          defaultValue: 0,
        );

        if (pendingAmount + 0.001 < paymentAmount) {
          throw StateError('Payment reservation data is invalid.');
        }

        final newPendingAmount = (pendingAmount - paymentAmount)
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
  // BOUNDED STREAMS
  // ------------------------------------------------------------
  PaymentQueryStream watchTenantPayments() {
    final uid = _currentUid;
    return _payments
        .where('tenantUserId', isEqualTo: uid)
        .limit(150)
        .snapshots();
  }

  PaymentQueryStream watchOwnerPayments({
    required String ownerId,
    bool pendingOnly = false,
  }) {
    _currentUid;
    final normalizedOwnerId = ownerId.trim();

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }

    Query<JsonMap> query = _payments.where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    );

    if (pendingOnly) {
      query = query.where(
        'status',
        isEqualTo: PaymentReviewStatus.pending.name,
      );
    }

    return query.limit(pendingOnly ? 100 : 200).snapshots();
  }

  PaymentQueryStream watchManagedPropertyPayments({
    required List<String> propertyIds,
    bool pendingOnly = false,
  }) {
    _currentUid;
    final scopedIds = propertyIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .take(10)
        .toList();

    if (scopedIds.isEmpty) {
      return const Stream.empty();
    }

    Query<JsonMap> query = _payments.where('propertyId', whereIn: scopedIds);

    if (pendingOnly) {
      query = query.where(
        'status',
        isEqualTo: PaymentReviewStatus.pending.name,
      );
    }

    return query.limit(pendingOnly ? 100 : 200).snapshots();
  }
}

class _PreparedPaymentItem {
  final String billId;
  final String collectionName;
  final DocumentReference<JsonMap> billRef;
  final DocumentReference<JsonMap> paymentRef;
  final double requestedAmount;

  const _PreparedPaymentItem({
    required this.billId,
    required this.collectionName,
    required this.billRef,
    required this.paymentRef,
    required this.requestedAmount,
  });
}
