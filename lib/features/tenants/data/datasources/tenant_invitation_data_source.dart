// noinspection SpellCheckingInspection
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../rents/data/models/rent_rate_model.dart';
import '../../../rents/domain/entities/rent_rate.dart';
import '../../../units/domain/entities/unit.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_invitation.dart';
import '../models/tenant_invitation_model.dart';
import '../models/tenant_model.dart';

typedef JsonMap = Map<String, dynamic>;
typedef InvitationList = List<TenantInvitationModel>;

class TenantInvitationDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TenantInvitationDataSource({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // ================================================================
  // COLLECTIONS
  // ================================================================

  CollectionReference<JsonMap> get _invitations =>
      _firestore.collection('tenantInvitations');

  CollectionReference<JsonMap> get _tenants => _firestore.collection('tenants');

  CollectionReference<JsonMap> get _properties =>
      _firestore.collection('properties');

  CollectionReference<JsonMap> get _units => _firestore.collection('units');

  CollectionReference<JsonMap> get _tenantAccess =>
      _firestore.collection('tenantAccess');

  CollectionReference<JsonMap> get _rentRates =>
      _firestore.collection('rentRates');

  CollectionReference<JsonMap> get _users => _firestore.collection('users');

  CollectionReference<JsonMap> get _managerAccess =>
      _firestore.collection('managerAccess');

  Future<bool> _isOwnerOrActiveManager({
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

  // ================================================================
  // CREATE INVITATION (VERIFIED EMAIL MANDATORY)
  // ================================================================

  Future<TenantInvitationModel> createInvitation({
    required String ownerId,
    String? tenantId,
    required String propertyId,
    required String unitId,
    String? phone,
    String? targetName,
    String? targetEmail,
    String? targetGrihoId,
    required double rentAmount,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedTenantId = _normalize(tenantId);
    final normalizedPropertyId = propertyId.trim();
    final normalizedUnitId = unitId.trim();

    final normalizedName = _normalize(targetName);
    final normalizedEmail = _normalizeEmail(targetEmail);
    final normalizedGrihoId = _normalizeGrihoId(targetGrihoId);

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError('Owner ID cannot be empty.');
    }
    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError('Property ID cannot be empty.');
    }
    if (normalizedUnitId.isEmpty) {
      throw ArgumentError('Unit ID cannot be empty.');
    }
    if (!rentAmount.isFinite || rentAmount <= 0) {
      throw ArgumentError('Rent amount must be greater than zero.');
    }

    final identifiers = <String?>[
      _normalize(phone),
      normalizedEmail,
      normalizedGrihoId,
    ];

    final suppliedIdentifierCount = identifiers
        .where((value) => value != null)
        .length;

    if (suppliedIdentifierCount != 1) {
      throw ArgumentError(
        'Provide exactly one recipient identifier: phone, email, or Griho ID.',
      );
    }

    String? normalizedPhone;
    if (_normalize(phone) != null) {
      normalizedPhone = PhoneNumberUtils.normalizeAndValidate(phone!);
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('You must be signed in to create invitations.');
    }

    // Mandatory email verification before sending any invitation
    await currentUser.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null || !refreshedUser.emailVerified) {
      throw StateError(
        'Please verify your email address before sending an invitation.',
      );
    }

    final authorized = await _isOwnerOrActiveManager(
      uid: refreshedUser.uid,
      ownerId: normalizedOwnerId,
      propertyId: normalizedPropertyId,
    );

    if (!authorized) {
      throw StateError(
        'Only the property owner or an active manager can create invitations.',
      );
    }

    final docSnapshots = await Future.wait([
      _properties.doc(normalizedPropertyId).get(),
      _units.doc(normalizedUnitId).get(),
    ]);

    final propertySnapshot = docSnapshots[0];
    final unitSnapshot = docSnapshots[1];

    if (!propertySnapshot.exists || propertySnapshot.data() == null) {
      throw StateError('Property does not exist.');
    }

    final propertyData = propertySnapshot.data()!;
    if (_normalize(propertyData['ownerId'] as String?) != normalizedOwnerId) {
      throw StateError(
        'Selected property does not belong to the specified owner.',
      );
    }

    final propertyStatus = propertyData['status'];
    if (propertyStatus is String &&
        propertyStatus.trim().isNotEmpty &&
        propertyStatus.toLowerCase() != 'active') {
      throw StateError('Selected property is not active.');
    }

    if (!unitSnapshot.exists || unitSnapshot.data() == null) {
      throw StateError('Unit does not exist.');
    }

    final unitData = unitSnapshot.data()!;
    if (_normalize(unitData['propertyId'] as String?) != normalizedPropertyId) {
      throw StateError(
        'Selected unit does not belong to the selected property.',
      );
    }

    final unitStatus = unitData['status'];
    if (unitStatus is String &&
        unitStatus.trim().isNotEmpty &&
        unitStatus.toLowerCase() != 'available') {
      throw StateError('Selected unit is not available.');
    }

    final existingUnitTenantUserId = unitData['tenantUserId'];
    if (existingUnitTenantUserId is String &&
        existingUnitTenantUserId.trim().isNotEmpty) {
      throw StateError('Selected unit is already assigned to a tenant.');
    }

    if (normalizedTenantId != null) {
      final tenantSnapshot = await _tenants.doc(normalizedTenantId).get();

      if (!tenantSnapshot.exists) {
        throw StateError(
          'The supplied tenant record does not exist. '
          'Leave tenantId empty for a new tenant invitation.',
        );
      }

      final tenant = TenantModel.fromFirestore(tenantSnapshot);

      if (tenant.ownerId != normalizedOwnerId) {
        throw StateError(
          'The tenant record does not belong to the property owner.',
        );
      }

      if (tenant.propertyId != normalizedPropertyId ||
          tenant.unitId != normalizedUnitId) {
        throw StateError(
          'The existing tenant record does not match the selected property and unit.',
        );
      }

      if (tenant.status != TenantStatus.inactive) {
        throw StateError(
          'Only an inactive tenant can receive a new tenancy invitation.',
        );
      }

      if (normalizedPhone != null) {
        final existingPhone = PhoneNumberUtils.normalizeAndValidate(
          tenant.phone,
        );
        if (existingPhone != normalizedPhone) {
          throw StateError(
            'Invitation phone does not match the existing tenant phone.',
          );
        }
      }

      if (normalizedEmail != null &&
          _normalizeEmail(tenant.email) != normalizedEmail) {
        throw StateError(
          'Invitation email does not match the existing tenant email.',
        );
      }
    }

    final pendingSnapshot = await _invitations
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .limit(20)
        .get();

    final now = DateTime.now();
    for (final document in pendingSnapshot.docs) {
      final existing = TenantInvitationModel.fromFirestore(document);
      if (!existing.isExpired) {
        throw StateError(
          'A pending invitation already exists for this unit. '
          'Cancel it or wait until it expires before creating another.',
        );
      }
    }

    final invitationToken = _generateToken();
    final invitationReference = _invitations.doc(invitationToken);

    final invitation = TenantInvitationModel(
      id: invitationReference.id,
      ownerId: normalizedOwnerId,
      tenantId: normalizedTenantId,
      propertyId: normalizedPropertyId,
      unitId: normalizedUnitId,
      phone: normalizedPhone,
      targetName: normalizedName,
      targetEmail: normalizedEmail,
      targetGrihoId: normalizedGrihoId,
      propertyName: _readOptionalString(propertyData, 'name'),
      propertyCode: _readOptionalString(propertyData, 'propertyCode'),
      unitNumber: _readOptionalString(unitData, 'unitNumber'),
      unitName: _readOptionalString(unitData, 'name'),
      rentAmount: rentAmount,
      status: TenantInvitationStatus.pending,
      token: invitationToken,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(days: 7)),
    );

    await invitationReference.set(invitation.toMap());

    return invitation;
  }

  // ================================================================
  // REALTIME STREAMS (BOUNDED WITH LIMIT)
  // ================================================================

  Stream<InvitationList> watchInvitationsByTenantId(String tenantId) {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty) {
      return const Stream.empty();
    }

    return _invitations
        .where('tenantId', isEqualTo: normalizedTenantId)
        .limit(30)
        .snapshots()
        .map((snapshot) {
          final invitations = snapshot.docs
              .map(TenantInvitationModel.fromFirestore)
              .toList();
          invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return invitations;
        });
  }

  Stream<InvitationList> watchInvitationsByPhone(String phone) {
    final normalizedPhone = PhoneNumberUtils.normalizeAndValidate(phone);

    return _invitations
        .where('phone', isEqualTo: normalizedPhone)
        .limit(30)
        .snapshots()
        .map((snapshot) {
          final invitations = snapshot.docs
              .map(TenantInvitationModel.fromFirestore)
              .toList();
          invitations.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return invitations;
        });
  }

  Stream<TenantInvitationModel?> watchPendingInvitationByTenantId(
    String tenantId,
  ) {
    return watchInvitationsByTenantId(tenantId).map((invitations) {
      for (final invitation in invitations) {
        if (invitation.isPending) {
          return invitation;
        }
      }
      return null;
    });
  }

  // ================================================================
  // GETTERS
  // ================================================================

  Future<TenantInvitationModel?> getInvitationById(String invitationId) async {
    final normalizedId = invitationId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('Invitation ID cannot be empty.');
    }

    final snapshot = await _invitations.doc(normalizedId).get();
    if (!snapshot.exists) {
      return null;
    }

    final invitation = TenantInvitationModel.fromFirestore(snapshot);
    if (invitation.status == TenantInvitationStatus.pending &&
        invitation.isExpired) {
      return null;
    }

    return invitation;
  }

  Future<TenantInvitationModel?> getInvitationByToken(String token) async {
    final normalizedToken = token.trim();
    if (normalizedToken.isEmpty) {
      throw ArgumentError('Invitation token cannot be empty.');
    }

    final snapshot = await _invitations.doc(normalizedToken).get();
    if (!snapshot.exists) {
      return null;
    }

    final invitation = TenantInvitationModel.fromFirestore(snapshot);
    if (invitation.status == TenantInvitationStatus.pending &&
        invitation.isExpired) {
      return null;
    }

    return invitation;
  }

  Stream<InvitationList> watchInvitationsForRecipient({
    String? phone,
    String? email,
    String? grihoId,
  }) {
    final queries = <Query<JsonMap>>[];

    final p = _normalize(phone);
    if (p != null) {
      queries.add(
        _invitations
            .where('phone', isEqualTo: PhoneNumberUtils.normalizeAndValidate(p))
            .limit(30),
      );
    }
    final e = _normalizeEmail(email);
    if (e != null) {
      queries.add(_invitations.where('targetEmail', isEqualTo: e).limit(30));
    }
    final g = _normalizeGrihoId(grihoId);
    if (g != null) {
      queries.add(_invitations.where('targetGrihoId', isEqualTo: g).limit(30));
    }
    if (queries.isEmpty) {
      return Stream.value(const <TenantInvitationModel>[]);
    }

    late final StreamController<InvitationList> controller;
    final latest = List<InvitationList>.filled(
      queries.length,
      const <TenantInvitationModel>[],
    );
    final subs = <StreamSubscription<QuerySnapshot<JsonMap>>>[];

    void emit() {
      final byId = <String, TenantInvitationModel>{};
      for (final list in latest) {
        for (final item in list) {
          byId[item.id] = item;
        }
      }
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) {
        controller.add(merged);
      }
    }

    controller = StreamController<InvitationList>(
      onListen: () {
        for (var i = 0; i < queries.length; i++) {
          subs.add(
            queries[i].snapshots().listen((snap) {
              latest[i] = snap.docs
                  .map(TenantInvitationModel.fromFirestore)
                  .toList();
              emit();
            }, onError: controller.addError),
          );
        }
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  Future<TenantInvitationModel?> getPendingInvitationByTenantId(
    String tenantId,
  ) async {
    final normalizedTenantId = tenantId.trim();
    if (normalizedTenantId.isEmpty) {
      throw ArgumentError('Tenant ID cannot be empty.');
    }

    final snapshot = await _invitations
        .where('tenantId', isEqualTo: normalizedTenantId)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .limit(20)
        .get();

    for (final document in snapshot.docs) {
      final invitation = TenantInvitationModel.fromFirestore(document);
      if (invitation.isPending) {
        return invitation;
      }
    }

    return null;
  }

  Future<TenantInvitationModel?> getPendingInvitationByPhone(
    String phone,
  ) async {
    final normalizedPhone = PhoneNumberUtils.normalizeAndValidate(phone);

    final snapshot = await _invitations
        .where('phone', isEqualTo: normalizedPhone)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .limit(20)
        .get();

    for (final document in snapshot.docs) {
      final invitation = TenantInvitationModel.fromFirestore(document);
      if (invitation.isPending) {
        return invitation;
      }
    }

    return null;
  }

  Future<TenantInvitationModel?> getPendingInvitationByEmail(
    String email,
  ) async {
    final normalizedEmail = _normalizeEmail(email);
    if (normalizedEmail == null) {
      throw ArgumentError('A valid email address is required.');
    }

    final snapshot = await _invitations
        .where('targetEmail', isEqualTo: normalizedEmail)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .limit(20)
        .get();

    for (final document in snapshot.docs) {
      final invitation = TenantInvitationModel.fromFirestore(document);
      if (invitation.isPending) {
        return invitation;
      }
    }

    return null;
  }

  Future<TenantInvitationModel?> getPendingInvitationByGrihoId(
    String grihoId,
  ) async {
    final normalizedGrihoId = _normalizeGrihoId(grihoId);
    if (normalizedGrihoId == null) {
      throw ArgumentError('A valid Griho ID is required.');
    }

    final snapshot = await _invitations
        .where('targetGrihoId', isEqualTo: normalizedGrihoId)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .limit(20)
        .get();

    for (final document in snapshot.docs) {
      final invitation = TenantInvitationModel.fromFirestore(document);
      if (invitation.isPending) {
        return invitation;
      }
    }

    return null;
  }

  // ================================================================
  // ACCEPT INVITATION (VERIFIED EMAIL MANDATORY, SINGLE USER READ)
  // ================================================================

  Future<void> acceptInvitation(String invitationId) async {
    final normalizedInvitationId = invitationId.trim();
    if (normalizedInvitationId.isEmpty) {
      throw ArgumentError('Invitation ID cannot be empty.');
    }

    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError('You must be signed in to accept an invitation.');
    }

    await firebaseUser.reload();
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      throw StateError('Your authentication session has expired.');
    }

    if (!currentUser.emailVerified) {
      throw StateError(
        'Please verify your email address before accepting an invitation.',
      );
    }

    final invitationReference = _invitations.doc(normalizedInvitationId);
    final preCheckSnap = await invitationReference.get();
    if (!preCheckSnap.exists) {
      throw StateError('Invitation does not exist.');
    }

    final preInvitation = TenantInvitationModel.fromFirestore(preCheckSnap);

    final now = DateTime.now();
    final rentRateSnapshot = await _rentRates
        .where('unitId', isEqualTo: preInvitation.unitId)
        .where('ownerId', isEqualTo: preInvitation.ownerId)
        .where('effectiveFrom', isLessThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('effectiveFrom', descending: true)
        .limit(1)
        .get();

    DocumentReference<JsonMap>? candidateRentRateRef;
    if (rentRateSnapshot.docs.isNotEmpty) {
      candidateRentRateRef = rentRateSnapshot.docs.first.reference;
    }

    await _firestore.runTransaction((transaction) async {
      final invitationSnapshot = await transaction.get(invitationReference);
      if (!invitationSnapshot.exists) {
        throw StateError('Invitation does not exist.');
      }

      final invitation = TenantInvitationModel.fromFirestore(
        invitationSnapshot,
      );

      if (invitation.status != TenantInvitationStatus.pending) {
        throw StateError('This invitation is no longer pending.');
      }

      if (!now.isBefore(invitation.expiresAt)) {
        throw StateError('This invitation has expired.');
      }

      final tenantId = _normalize(invitation.tenantId);
      if (tenantId == null) {
        throw StateError(
          'This invitation requires new-tenant onboarding. '
          'Collect and verify the recipient details before creating '
          'the tenant record.',
        );
      }

      final tenantReference = _tenants.doc(tenantId);
      final tenantAccessReference = _tenantAccess.doc(currentUser.uid);
      final propertyReference = _properties.doc(invitation.propertyId);
      final unitReference = _units.doc(invitation.unitId);

      // ALL TRANSACTION READS FIRST
      final tenantSnapshot = await transaction.get(tenantReference);
      final tenantAccessSnapshot = await transaction.get(tenantAccessReference);
      final propertySnapshot = await transaction.get(propertyReference);
      final unitSnapshot = await transaction.get(unitReference);
      final accountSnapshot = await transaction.get(
        _users.doc(currentUser.uid),
      );
      final existingRentRateSnap = candidateRentRateRef != null
          ? await transaction.get(candidateRentRateRef)
          : null;

      final accountData = accountSnapshot.data();

      // Verify recipient identity using the already-read accountSnapshot (saves 1 read).
      _verifyInvitationRecipient(
        invitation: invitation,
        user: currentUser,
        userData: accountData,
      );

      if (!tenantSnapshot.exists) {
        throw StateError('Tenant does not exist.');
      }

      final tenant = TenantModel.fromFirestore(tenantSnapshot);

      if (tenant.ownerId != invitation.ownerId) {
        throw StateError('Invitation owner does not match tenant owner.');
      }
      if (tenant.propertyId != invitation.propertyId ||
          tenant.unitId != invitation.unitId) {
        throw StateError(
          'Tenant record does not match the invitation property and unit.',
        );
      }
      if (tenant.status != TenantStatus.inactive) {
        throw StateError('Tenant is already active.');
      }

      final linkedUserId = _normalize(tenant.userId);
      if (linkedUserId != null && linkedUserId != currentUser.uid) {
        throw StateError('This tenant record is linked to another account.');
      }

      if (!propertySnapshot.exists || propertySnapshot.data() == null) {
        throw StateError('Invitation property no longer exists.');
      }
      final propertyData = propertySnapshot.data()!;
      if (_normalize(propertyData['ownerId'] as String?) !=
          invitation.ownerId) {
        throw StateError('Invitation property does not belong to its owner.');
      }

      if (!unitSnapshot.exists || unitSnapshot.data() == null) {
        throw StateError('Invitation unit no longer exists.');
      }
      final unitData = unitSnapshot.data()!;
      if (_normalize(unitData['propertyId'] as String?) !=
          invitation.propertyId) {
        throw StateError('Invitation unit does not belong to its property.');
      }

      final unitStatus = unitData['status'];
      if (unitStatus is String &&
          unitStatus.trim().isNotEmpty &&
          unitStatus.toLowerCase() != 'available') {
        throw StateError('This unit is no longer available.');
      }

      final unitTenantUserId = _normalize(unitData['tenantUserId'] as String?);
      if (unitTenantUserId != null && unitTenantUserId != currentUser.uid) {
        throw StateError('This unit is already assigned to another account.');
      }

      if (tenantAccessSnapshot.exists && tenantAccessSnapshot.data() != null) {
        final accessData = tenantAccessSnapshot.data()!;
        final accessTenantId = _normalize(accessData['tenantId'] as String?);
        if (accessTenantId != null && accessTenantId != tenantId) {
          throw StateError('This account is already linked to another tenant.');
        }
      }

      RentRateModel? currentRentRate;
      if (existingRentRateSnap != null && existingRentRateSnap.exists) {
        final candidate = RentRateModel.fromFirestore(existingRentRateSnap);
        if (candidate.isApplicableAt(now)) {
          currentRentRate = candidate;
        }
      }

      final newRentRateReference = _rentRates.doc();
      final shouldCreateRentRate =
          currentRentRate == null ||
          currentRentRate.amount != invitation.rentAmount;

      // WRITES START HERE
      final accountEmail = _normalize(
        (accountData?['email'] as String?) ?? currentUser.email,
      )?.toLowerCase();
      final accountNid = _normalize(accountData?['nidNumber'] as String?);

      final contactUpdates = <String, dynamic>{
        if (accountEmail != null &&
            _normalize(tenantSnapshot.data()?['email'] as String?) == null)
          'email': accountEmail,
        if (accountNid != null &&
            _normalize(tenantSnapshot.data()?['nidNumber'] as String?) == null)
          'nidNumber': accountNid,
      };

      transaction.update(tenantReference, {
        ...contactUpdates,
        'userId': currentUser.uid,
        'status': TenantStatus.active.name,
        'accountStatus': TenantAccountStatus.registered.name,
        'confirmationStatus': TenantConfirmationStatus.confirmed.name,
        'tenancyStartedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      transaction.set(tenantAccessReference, {
        'userId': currentUser.uid,
        'tenantId': tenantId,
        'ownerId': invitation.ownerId,
        'propertyId': invitation.propertyId,
        'unitId': invitation.unitId,
        'invitationId': invitation.id,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      transaction.update(unitReference, {
        'status': UnitStatus.occupied.name,
        'tenantUserId': currentUser.uid,
        'updatedAt': Timestamp.fromDate(now),
      });

      transaction.update(propertyReference, {
        'tenantUserIds': FieldValue.arrayUnion([currentUser.uid]),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (shouldCreateRentRate) {
        if (currentRentRate != null && candidateRentRateRef != null) {
          transaction.update(candidateRentRateRef, {
            'effectiveTo': Timestamp.fromDate(now),
            'nextRentRateId': newRentRateReference.id,
            'updatedAt': Timestamp.fromDate(now),
          });
        }

        final source = currentRentRate == null
            ? RentRateSource.initial
            : RentRateSource.unit;

        final newRentRate = RentRateModel(
          id: newRentRateReference.id,
          ownerId: invitation.ownerId,
          propertyId: invitation.propertyId,
          unitId: invitation.unitId,
          amount: invitation.rentAmount,
          effectiveFrom: now,
          effectiveTo: null,
          source: source,
          previousRentRateId: currentRentRate?.id,
          nextRentRateId: null,
          createdAt: now,
          updatedAt: now,
        );

        transaction.set(newRentRateReference, newRentRate.toFirestore());
      }

      transaction.update(invitationReference, {
        'status': TenantInvitationStatus.accepted.name,
        'acceptedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    });
  }

  // ================================================================
  // CANCEL OR REJECT INVITATION (VERIFIED EMAIL MANDATORY)
  // ================================================================

  Future<void> cancelInvitation(String invitationId) async {
    final normalizedId = invitationId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('Invitation ID cannot be empty.');
    }

    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError(
        'You must be signed in to cancel or reject an invitation.',
      );
    }

    await firebaseUser.reload();
    final user = _auth.currentUser ?? firebaseUser;

    final reference = _invitations.doc(normalizedId);
    final preSnap = await reference.get();
    if (!preSnap.exists) {
      throw StateError('Invitation does not exist.');
    }
    final preInv = TenantInvitationModel.fromFirestore(preSnap);
    final isAdmin = await _isOwnerOrActiveManager(
      uid: user.uid,
      ownerId: preInv.ownerId,
      propertyId: preInv.propertyId,
    );

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('Invitation does not exist.');
      }

      final invitation = TenantInvitationModel.fromFirestore(snapshot);
      if (invitation.status != TenantInvitationStatus.pending) {
        throw StateError('Only pending invitations can be changed.');
      }

      final now = DateTime.now();

      if (isAdmin) {
        transaction.update(reference, {
          'status': TenantInvitationStatus.cancelled.name,
          'cancelledAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
        return;
      }

      JsonMap? userData;
      if (_normalizeEmail(invitation.targetEmail) == null) {
        final userSnap = await transaction.get(_users.doc(user.uid));
        userData = userSnap.data();
      }

      _verifyInvitationRecipient(
        invitation: invitation,
        user: user,
        userData: userData,
      );

      transaction.update(reference, {
        'status': TenantInvitationStatus.rejected.name,
        'rejectedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });
    });
  }

  // ================================================================
  // EXPIRE INVITATION
  // ================================================================

  Future<void> expireInvitation(String invitationId) async {
    final normalizedId = invitationId.trim();
    if (normalizedId.isEmpty) {
      throw ArgumentError('Invitation ID cannot be empty.');
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in.');
    }

    final reference = _invitations.doc(normalizedId);
    final preSnap = await reference.get();
    if (!preSnap.exists) {
      throw StateError('Invitation does not exist.');
    }
    final preInv = TenantInvitationModel.fromFirestore(preSnap);
    final isAdmin = await _isOwnerOrActiveManager(
      uid: user.uid,
      ownerId: preInv.ownerId,
      propertyId: preInv.propertyId,
    );

    if (!isAdmin) {
      throw StateError('Only the owner or manager can expire an invitation.');
    }

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw StateError('Invitation does not exist.');
      }

      final invitation = TenantInvitationModel.fromFirestore(snapshot);
      if (invitation.status != TenantInvitationStatus.pending) {
        throw StateError('Only pending invitations can be expired.');
      }

      if (DateTime.now().isBefore(invitation.expiresAt)) {
        throw StateError('This invitation has not expired yet.');
      }

      transaction.update(reference, {
        'status': TenantInvitationStatus.expired.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ================================================================
  // RECIPIENT IDENTITY VERIFICATION (SYNCHRONOUS — USES TRANSACTION DATA)
  // ================================================================

  void _verifyInvitationRecipient({
    required TenantInvitation invitation,
    required User user,
    required JsonMap? userData,
  }) {
    if (!user.emailVerified) {
      throw StateError(
        'Please verify your email address before responding to an invitation.',
      );
    }

    final invitationPhone = _normalize(invitation.phone);
    final invitationEmail = _normalizeEmail(invitation.targetEmail);
    final invitationGrihoId = _normalizeGrihoId(invitation.targetGrihoId);

    if (invitationEmail != null) {
      if (_normalizeEmail(user.email) != invitationEmail) {
        throw StateError('Your account email does not match this invitation.');
      }
      return;
    }

    if (userData == null) {
      throw StateError('Your Griho profile could not be found.');
    }

    if (invitationGrihoId != null) {
      if (_normalizeGrihoId(userData['publicId'] as String?) !=
          invitationGrihoId) {
        throw StateError('Your Griho ID does not match this invitation.');
      }
      return;
    }

    if (invitationPhone != null) {
      final profilePhone = _normalize(userData['phoneNumber'] as String?);
      if (profilePhone == null ||
          PhoneNumberUtils.normalizeAndValidate(profilePhone) !=
              PhoneNumberUtils.normalizeAndValidate(invitationPhone)) {
        throw StateError('Your phone number does not match this invitation.');
      }
      return;
    }

    throw StateError('This invitation has no valid recipient identifier.');
  }

  // ================================================================
  // HELPERS
  // ================================================================

  String _generateToken() {
    final random = Random.secure();
    const characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    return List.generate(
      32,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }

  String? _readOptionalString(JsonMap data, String field) {
    final value = data[field];
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String? _normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _normalizeEmail(String? value) {
    final normalized = _normalize(value)?.toLowerCase();
    if (normalized == null) {
      return null;
    }

    final atIndex = normalized.indexOf('@');
    if (atIndex <= 0 ||
        atIndex == normalized.length - 1 ||
        normalized.indexOf('@', atIndex + 1) != -1) {
      throw ArgumentError('Invalid email address.');
    }

    return normalized;
  }

  String? _normalizeGrihoId(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) {
      return null;
    }
    return normalized.toUpperCase();
  }
}
