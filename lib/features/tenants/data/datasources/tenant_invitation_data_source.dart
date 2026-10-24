import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../rents/data/models/rent_rate_model.dart';
import '../../../rents/domain/entities/rent_rate.dart';
import '../../../units/domain/entities/unit.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_invitation.dart';
import '../models/tenant_invitation_model.dart';
import '../models/tenant_model.dart';

class TenantInvitationDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TenantInvitationDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ================================================================
  // COLLECTIONS
  // ================================================================

  CollectionReference<Map<String, dynamic>> get _invitations =>
      _firestore.collection('tenantInvitations');

  CollectionReference<Map<String, dynamic>> get _tenants =>
      _firestore.collection('tenants');

  CollectionReference<Map<String, dynamic>> get _properties =>
      _firestore.collection('properties');

  CollectionReference<Map<String, dynamic>> get _units =>
      _firestore.collection('units');

  CollectionReference<Map<String, dynamic>> get _tenantAccess =>
      _firestore.collection('tenantAccess');

  CollectionReference<Map<String, dynamic>> get _rentRates =>
      _firestore.collection('rentRates');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  // ================================================================
  // CREATE INVITATION
  //
  // Recipient identifiers:
  //   1. phone
  //   2. targetEmail
  //   3. targetGrihoId
  //
  // An existing tenantId is optional.
  // UID is never accepted as an invitation input.
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

    // Exactly one recipient identifier is required.
    final identifiers = <String?>[
      _normalize(phone),
      normalizedEmail,
      normalizedGrihoId,
    ];

    final suppliedIdentifierCount =
        identifiers
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

    if (currentUser == null || currentUser.uid != normalizedOwnerId) {
      throw StateError('Only the authenticated owner can create invitations.');
    }

    // --------------------------------------------------------------
    // PROPERTY
    // --------------------------------------------------------------

    final propertyReference = _properties.doc(normalizedPropertyId);
    final propertySnapshot = await propertyReference.get();

    if (!propertySnapshot.exists) {
      throw StateError('Property does not exist.');
    }

    final propertyData = propertySnapshot.data();

    if (propertyData == null) {
      throw StateError('Property data is missing.');
    }

    if (_normalize(propertyData['ownerId'] as String?) !=
        normalizedOwnerId) {
      throw StateError(
        'Selected property does not belong to the current owner.',
      );
    }

    final propertyStatus = propertyData['status'];

    if (propertyStatus is String &&
        propertyStatus
            .trim()
            .isNotEmpty &&
        propertyStatus.toLowerCase() != 'active') {
      throw StateError('Selected property is not active.');
    }

    // --------------------------------------------------------------
    // UNIT
    // --------------------------------------------------------------

    final unitReference = _units.doc(normalizedUnitId);
    final unitSnapshot = await unitReference.get();

    if (!unitSnapshot.exists) {
      throw StateError('Unit does not exist.');
    }

    final unitData = unitSnapshot.data();

    if (unitData == null) {
      throw StateError('Unit data is missing.');
    }

    if (_normalize(unitData['propertyId'] as String?) !=
        normalizedPropertyId) {
      throw StateError(
        'Selected unit does not belong to the selected property.',
      );
    }

    final unitStatus = unitData['status'];

    if (unitStatus is String &&
        unitStatus
            .trim()
            .isNotEmpty &&
        unitStatus.toLowerCase() != 'available') {
      throw StateError('Selected unit is not available.');
    }

    final existingUnitTenantUserId = unitData['tenantUserId'];

    if (existingUnitTenantUserId is String &&
        existingUnitTenantUserId
            .trim()
            .isNotEmpty) {
      throw StateError('Selected unit is already assigned to a tenant.');
    }

    // --------------------------------------------------------------
    // OPTIONAL EXISTING TENANT
    // --------------------------------------------------------------

    if (normalizedTenantId != null) {
      final tenantSnapshot =
      await _tenants.doc(normalizedTenantId).get();

      if (!tenantSnapshot.exists) {
        throw StateError(
          'The supplied tenant record does not exist. '
              'Leave tenantId empty for a new tenant invitation.',
        );
      }

      final tenant = TenantModel.fromFirestore(tenantSnapshot);

      if (tenant.ownerId != normalizedOwnerId) {
        throw StateError(
          'The tenant record does not belong to the current owner.',
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
        final existingPhone =
        PhoneNumberUtils.normalizeAndValidate(tenant.phone);

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

    // --------------------------------------------------------------
    // DUPLICATE PENDING INVITATIONS
    //
    // Check the selected unit to prevent multiple active invitations
    // from being issued for the same unit.
    // --------------------------------------------------------------

    final pendingSnapshot = await _invitations
        .where('ownerId', isEqualTo: normalizedOwnerId)
        .where('unitId', isEqualTo: normalizedUnitId)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
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

    // --------------------------------------------------------------
    // CREATE INVITATION
    // --------------------------------------------------------------

    final invitationReference = _invitations.doc();

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
      token: _generateToken(),
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(days: 7)),
    );

    await invitationReference.set(invitation.toMap());

    if (kDebugMode) {
      debugPrint(
        '[TENANT INVITATION] Created invitation ${invitation.id}',
      );
    }

    return invitation;
  }

  // ================================================================
  // REALTIME: INVITATIONS BY TENANT ID
  // ================================================================

  Stream<List<TenantInvitationModel>> watchInvitationsByTenantId(
      String tenantId,) {
    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return const Stream.empty();
    }

    return _invitations
        .where('tenantId', isEqualTo: normalizedTenantId)
        .snapshots()
        .map((snapshot) {
      final invitations = snapshot.docs
          .map(TenantInvitationModel.fromFirestore)
          .toList();

      invitations.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return invitations;
    });
  }

  // ================================================================
  // REALTIME: INVITATIONS BY PHONE
  // ================================================================

  Stream<List<TenantInvitationModel>> watchInvitationsByPhone(String phone,) {
    final normalizedPhone =
    PhoneNumberUtils.normalizeAndValidate(phone);

    return _invitations
        .where('phone', isEqualTo: normalizedPhone)
        .snapshots()
        .map((snapshot) {
      final invitations = snapshot.docs
          .map(TenantInvitationModel.fromFirestore)
          .toList();

      invitations.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return invitations;
    });
  }

  // ================================================================
  // REALTIME: PENDING INVITATION BY TENANT ID
  // ================================================================

  Stream<TenantInvitationModel?> watchPendingInvitationByTenantId(
      String tenantId,) {
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
  // GET INVITATION BY ID
  // ================================================================

  Future<TenantInvitationModel?> getInvitationById(String invitationId,) async {
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

  // ================================================================
  // GET INVITATION BY TOKEN
  // ================================================================

  Future<TenantInvitationModel?> getInvitationByToken(String token,) async {
    final normalizedToken = token.trim();

    if (normalizedToken.isEmpty) {
      throw ArgumentError('Invitation token cannot be empty.');
    }

    final snapshot = await _invitations
        .where('token', isEqualTo: normalizedToken)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final invitation =
    TenantInvitationModel.fromFirestore(snapshot.docs.first);

    if (invitation.status == TenantInvitationStatus.pending &&
        invitation.isExpired) {
      return null;
    }

    return invitation;
  }

  // ================================================================
  // GET PENDING INVITATION BY TENANT ID
  // ================================================================

  Future<TenantInvitationModel?> getPendingInvitationByTenantId(
      String tenantId,) async {
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
      final invitation =
      TenantInvitationModel.fromFirestore(document);

      if (invitation.isPending) {
        return invitation;
      }
    }

    return null;
  }

  // ================================================================
  // GET PENDING INVITATION BY PHONE
  // ================================================================

  Future<TenantInvitationModel?> getPendingInvitationByPhone(
      String phone,) async {
    final normalizedPhone =
    PhoneNumberUtils.normalizeAndValidate(phone);

    final snapshot = await _invitations
        .where('phone', isEqualTo: normalizedPhone)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .limit(20)
        .get();

    for (final document in snapshot.docs) {
      final invitation =
      TenantInvitationModel.fromFirestore(document);

      if (invitation.isPending) {
        return invitation;
      }
    }

    return null;
  }

  // ================================================================
  // GET PENDING INVITATION BY EMAIL
  //
  // This lookup alone does not prove ownership of the email address.
  // Verify Firebase email verification before accepting.
  // ================================================================

  Future<TenantInvitationModel?> getPendingInvitationByEmail(
      String email,) async {
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
      final invitation =
      TenantInvitationModel.fromFirestore(document);

      if (invitation.isPending) {
        return invitation;
      }
    }

    return null;
  }

  // ================================================================
  // GET PENDING INVITATION BY GRIHO ID
  //
  // Griho ID matching must be backed by verified user identity.
  // This query is not an authorization check.
  // ================================================================

  Future<TenantInvitationModel?> getPendingInvitationByGrihoId(
      String grihoId,) async {
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
      final invitation =
      TenantInvitationModel.fromFirestore(document);

      if (invitation.isPending) {
        return invitation;
      }
    }

    return null;
  }

  // ================================================================
  // ACCEPT INVITATION
  //
  // Important:
  // - This implementation accepts invitations linked to an existing
  //   tenant record.
  // - A new tenant invitation without tenantId needs a verified
  //   onboarding flow to collect the tenant name and phone number.
  // - Email and Griho ID invitations must not bypass identity checks.
  // ================================================================

  Future<void> acceptInvitation(String invitationId) async {
    final normalizedInvitationId = invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      throw ArgumentError('Invitation ID cannot be empty.');
    }

    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
        'You must be signed in to accept an invitation.',
      );
    }

    // Reload authentication claims/profile state before checking
    // verification flags.
    await firebaseUser.reload();

    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError('Your authentication session has expired.');
    }

    final invitationReference =
    _invitations.doc(normalizedInvitationId);

    await _firestore.runTransaction((transaction) async {
      final invitationSnapshot =
      await transaction.get(invitationReference);

      if (!invitationSnapshot.exists) {
        throw StateError('Invitation does not exist.');
      }

      final invitation =
      TenantInvitationModel.fromFirestore(invitationSnapshot);

      if (invitation.status != TenantInvitationStatus.pending) {
        throw StateError('This invitation is no longer pending.');
      }

      final now = DateTime.now();

      if (!now.isBefore(invitation.expiresAt)) {
        throw StateError('This invitation has expired.');
      }

      // ------------------------------------------------------------
      // VERIFY RECIPIENT IDENTITY
      // ------------------------------------------------------------

      await _verifyInvitationRecipient(
        invitation: invitation,
        user: currentUser,
      );

      // This version handles invitations linked to an existing tenant.
      // Do not create an incomplete tenant document when tenantId is null.
      final tenantId = _normalize(invitation.tenantId);

      if (tenantId == null) {
        throw StateError(
          'This invitation requires new-tenant onboarding. '
              'Collect and verify the recipient details before creating '
              'the tenant record.',
        );
      }

      final tenantReference = _tenants.doc(tenantId);
      final tenantAccessReference =
      _tenantAccess.doc(currentUser.uid);
      final propertyReference =
      _properties.doc(invitation.propertyId);
      final unitReference = _units.doc(invitation.unitId);

      // ------------------------------------------------------------
      // READ ALL DOCUMENTS BEFORE WRITES
      // ------------------------------------------------------------

      final tenantSnapshot =
      await transaction.get(tenantReference);
      final tenantAccessSnapshot =
      await transaction.get(tenantAccessReference);
      final propertySnapshot =
      await transaction.get(propertyReference);
      final unitSnapshot =
      await transaction.get(unitReference);

      if (!tenantSnapshot.exists) {
        throw StateError('Tenant does not exist.');
      }

      final tenant = TenantModel.fromFirestore(tenantSnapshot);

      if (tenant.ownerId != invitation.ownerId) {
        throw StateError(
          'Invitation owner does not match tenant owner.',
        );
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

      if (linkedUserId != null &&
          linkedUserId != currentUser.uid) {
        throw StateError(
          'This tenant record is linked to another account.',
        );
      }

      // ------------------------------------------------------------
      // PROPERTY
      // ------------------------------------------------------------

      if (!propertySnapshot.exists) {
        throw StateError('Invitation property no longer exists.');
      }

      final propertyData = propertySnapshot.data();

      if (propertyData == null) {
        throw StateError('Property data is missing.');
      }

      if (_normalize(propertyData['ownerId'] as String?) !=
          invitation.ownerId) {
        throw StateError(
          'Invitation property does not belong to its owner.',
        );
      }

      final propertyStatus = propertyData['status'];

      if (propertyStatus is String &&
          propertyStatus
              .trim()
              .isNotEmpty &&
          propertyStatus.toLowerCase() != 'active') {
        throw StateError('Invitation property is no longer active.');
      }

      // ------------------------------------------------------------
      // UNIT
      // ------------------------------------------------------------

      if (!unitSnapshot.exists) {
        throw StateError('Invitation unit no longer exists.');
      }

      final unitData = unitSnapshot.data();

      if (unitData == null) {
        throw StateError('Unit data is missing.');
      }

      if (_normalize(unitData['propertyId'] as String?) !=
          invitation.propertyId) {
        throw StateError(
          'Invitation unit does not belong to its property.',
        );
      }

      final unitStatus = unitData['status'];

      if (unitStatus is String &&
          unitStatus
              .trim()
              .isNotEmpty &&
          unitStatus.toLowerCase() != 'available') {
        throw StateError('This unit is no longer available.');
      }

      final unitTenantUserId =
      _normalize(unitData['tenantUserId'] as String?);

      if (unitTenantUserId != null &&
          unitTenantUserId != currentUser.uid) {
        throw StateError(
          'This unit is already assigned to another account.',
        );
      }

      // ------------------------------------------------------------
      // TENANT ACCESS
      // ------------------------------------------------------------

      if (tenantAccessSnapshot.exists) {
        final accessData = tenantAccessSnapshot.data();

        if (accessData == null) {
          throw StateError('Tenant access data is invalid.');
        }

        final accessTenantId =
        _normalize(accessData['tenantId'] as String?);
        final accessOwnerId =
        _normalize(accessData['ownerId'] as String?);

        if (accessTenantId != null && accessTenantId != tenantId) {
          throw StateError(
            'This account is already linked to another tenant.',
          );
        }

        if (accessOwnerId != null &&
            accessOwnerId != invitation.ownerId) {
          throw StateError(
            'This account already has tenant access for another owner.',
          );
        }
      }

      // ------------------------------------------------------------
      // RENT RATE
      // ------------------------------------------------------------

      final rentRateSnapshot = await _rentRates
          .where('unitId', isEqualTo: invitation.unitId)
          .where('ownerId', isEqualTo: invitation.ownerId)
          .where(
        'effectiveFrom',
        isLessThanOrEqualTo: Timestamp.fromDate(now),
      )
          .orderBy('effectiveFrom', descending: true)
          .limit(1)
          .get();

      RentRateModel? currentRentRate;

      if (rentRateSnapshot.docs.isNotEmpty) {
        final candidate = RentRateModel.fromFirestore(
          rentRateSnapshot.docs.first,
        );

        if (candidate.isApplicableAt(now)) {
          currentRentRate = candidate;
        }
      }

      final newRentRateReference = _rentRates.doc();

      final shouldCreateRentRate = currentRentRate == null ||
          currentRentRate.amount != invitation.rentAmount;

      // ------------------------------------------------------------
      // UPDATE TENANT
      // ------------------------------------------------------------

      transaction.update(tenantReference, {
        'userId': currentUser.uid,
        'status': TenantStatus.active.name,
        'accountStatus': TenantAccountStatus.registered.name,
        'confirmationStatus': TenantConfirmationStatus.confirmed.name,
        'tenancyStartedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // ------------------------------------------------------------
      // TENANT ACCESS
      // ------------------------------------------------------------

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

      // ------------------------------------------------------------
      // UNIT
      // ------------------------------------------------------------

      transaction.update(unitReference, {
        'status': UnitStatus.occupied.name,
        'tenantUserId': currentUser.uid,
        'updatedAt': Timestamp.fromDate(now),
      });

      // ------------------------------------------------------------
      // PROPERTY
      // ------------------------------------------------------------

      transaction.update(propertyReference, {
        'tenantUserIds': FieldValue.arrayUnion([currentUser.uid]),
        'updatedAt': Timestamp.fromDate(now),
      });

      // ------------------------------------------------------------
      // RENT RATE HISTORY
      // ------------------------------------------------------------

      if (shouldCreateRentRate) {
        if (currentRentRate != null) {
          final oldRentRateReference =
          _rentRates.doc(currentRentRate.id);

          transaction.update(oldRentRateReference, {
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

        transaction.set(
          newRentRateReference,
          newRentRate.toFirestore(),
        );
      }

      // ------------------------------------------------------------
      // MARK INVITATION ACCEPTED
      // ------------------------------------------------------------

      transaction.update(invitationReference, {
        'status': TenantInvitationStatus.accepted.name,
        'acceptedAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      if (kDebugMode) {
        debugPrint(
          '[TENANT INVITATION] Accepted: ${invitation.id}',
        );
      }
    });
  }

  // ================================================================
  // CANCEL OR REJECT INVITATION
  // ================================================================

  Future<void> cancelInvitation(String invitationId) async {
    final normalizedId = invitationId.trim();

    if (normalizedId.isEmpty) {
      throw ArgumentError('Invitation ID cannot be empty.');
    }

    final user = _auth.currentUser;

    if (user == null) {
      throw StateError(
        'You must be signed in to cancel or reject an invitation.',
      );
    }

    final reference = _invitations.doc(normalizedId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Invitation does not exist.');
      }

      final invitation =
      TenantInvitationModel.fromFirestore(snapshot);

      if (invitation.status != TenantInvitationStatus.pending) {
        throw StateError('Only pending invitations can be changed.');
      }

      final now = DateTime.now();

      if (invitation.ownerId == user.uid) {
        transaction.update(reference, {
          'status': TenantInvitationStatus.cancelled.name,
          'cancelledAt': Timestamp.fromDate(now),
          'updatedAt': Timestamp.fromDate(now),
        });
        return;
      }

      await _verifyInvitationRecipient(
        invitation: invitation,
        user: user,
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

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);

      if (!snapshot.exists) {
        throw StateError('Invitation does not exist.');
      }

      final invitation =
      TenantInvitationModel.fromFirestore(snapshot);

      if (invitation.ownerId != user.uid) {
        throw StateError('Only the owner can expire an invitation.');
      }

      if (invitation.status != TenantInvitationStatus.pending) {
        throw StateError('Only pending invitations can be expired.');
      }

      if (DateTime.now().isBefore(invitation.expiresAt)) {
        throw StateError(
          'This invitation has not expired yet.',
        );
      }

      transaction.update(reference, {
        'status': TenantInvitationStatus.expired.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ================================================================
  // RECIPIENT IDENTITY VERIFICATION
  // ================================================================

  Future<void> _verifyInvitationRecipient({
    required TenantInvitation invitation,
    required User user,
  }) async {
    final invitationPhone = _normalize(invitation.phone);
    final invitationEmail = _normalizeEmail(invitation.targetEmail);
    final invitationGrihoId =
    _normalizeGrihoId(invitation.targetGrihoId);

    if (invitationPhone != null) {
      final authPhoneRaw = _normalize(user.phoneNumber);

      if (authPhoneRaw == null) {
        throw StateError(
          'Verify your phone number before accepting this invitation.',
        );
      }

      final authPhone =
      PhoneNumberUtils.normalizeAndValidate(authPhoneRaw);
      final expectedPhone =
      PhoneNumberUtils.normalizeAndValidate(invitationPhone);

      if (authPhone != expectedPhone) {
        throw StateError(
          'Your verified phone number does not match this invitation.',
        );
      }

      return;
    }

    if (invitationEmail != null) {
      if (!user.emailVerified) {
        throw StateError(
          'Verify your email address before accepting this invitation.',
        );
      }

      final authEmail = _normalizeEmail(user.email);

      if (authEmail == null || authEmail != invitationEmail) {
        throw StateError(
          'Your verified email does not match this invitation.',
        );
      }

      return;
    }

    if (invitationGrihoId != null) {
      // Griho ID ownership must be established by a trusted mapping.
      // Never accept a Griho ID just because the user typed it.
      final userSnapshot = await _users.doc(user.uid).get();

      if (!userSnapshot.exists) {
        throw StateError(
          'Your Griho profile could not be verified.',
        );
      }

      final userData = userSnapshot.data();

      if (userData == null) {
        throw StateError('Your Griho profile data is missing.');
      }

      final storedGrihoId =
      _normalizeGrihoId(userData['grihoId'] as String?);

      if (storedGrihoId == null ||
          storedGrihoId != invitationGrihoId) {
        throw StateError(
          'Your verified Griho ID does not match this invitation.',
        );
      }

      return;
    }

    throw StateError(
      'This invitation has no valid recipient identifier.',
    );
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

  String? _readOptionalString(Map<String, dynamic> data,
      String field,) {
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