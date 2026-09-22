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
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ================================================================
  // COLLECTIONS
  // ================================================================

  CollectionReference<Map<String, dynamic>> get _invitations {
    return _firestore.collection('tenantInvitations');
  }

  CollectionReference<Map<String, dynamic>> get _tenants {
    return _firestore.collection('tenants');
  }

  CollectionReference<Map<String, dynamic>> get _properties {
    return _firestore.collection('properties');
  }

  CollectionReference<Map<String, dynamic>> get _units {
    return _firestore.collection('units');
  }

  CollectionReference<Map<String, dynamic>> get _tenantAccess {
    return _firestore.collection('tenantAccess');
  }

  CollectionReference<Map<String, dynamic>> get _rentRates {
    return _firestore.collection('rentRates');
  }

  // ================================================================
  // CREATE INVITATION
  // ================================================================

  Future<TenantInvitationModel> createInvitation({
    required String ownerId,
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
    required double rentAmount,
  }) async {
    final normalizedOwnerId = ownerId.trim();
    final normalizedTenantId = tenantId.trim();
    final normalizedPropertyId = propertyId.trim();
    final normalizedUnitId = unitId.trim();

    if (normalizedOwnerId.isEmpty) {
      throw ArgumentError(
        'Owner ID cannot be empty.',
      );
    }

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    if (normalizedPropertyId.isEmpty) {
      throw ArgumentError(
        'Property ID cannot be empty.',
      );
    }

    if (normalizedUnitId.isEmpty) {
      throw ArgumentError(
        'Unit ID cannot be empty.',
      );
    }

    if (rentAmount <= 0) {
      throw ArgumentError(
        'Rent amount must be greater than zero.',
      );
    }

    final normalizedPhone =
    PhoneNumberUtils.normalizeAndValidate(phone);

    // --------------------------------------------------------------
    // TENANT
    // --------------------------------------------------------------

    final tenantReference =
    _tenants.doc(normalizedTenantId);

    final tenantSnapshot =
    await tenantReference.get();

    if (!tenantSnapshot.exists) {
      throw StateError(
        'Tenant does not exist.',
      );
    }

    final tenant =
    TenantModel.fromFirestore(
      tenantSnapshot,
    );

    if (tenant.ownerId != normalizedOwnerId) {
      throw StateError(
        'You are not authorized to create an invitation for this tenant.',
      );
    }

    if (tenant.status != TenantStatus.inactive) {
      throw StateError(
        'Only an inactive tenant can receive a new tenancy invitation.',
      );
    }

    if (tenant.accountStatus !=
        TenantAccountStatus.registered) {
      throw StateError(
        'Tenant must have a registered account before receiving '
            'a tenancy invitation.',
      );
    }

    final tenantUserId =
    tenant.userId?.trim();

    if (tenantUserId == null ||
        tenantUserId.isEmpty) {
      throw StateError(
        'Tenant account is not linked to a user account.',
      );
    }

    final tenantPhone =
    PhoneNumberUtils.normalizeAndValidate(
      tenant.phone,
    );

    if (tenantPhone != normalizedPhone) {
      throw StateError(
        'Invitation phone number does not match the tenant phone number.',
      );
    }

    // --------------------------------------------------------------
    // PROPERTY
    // --------------------------------------------------------------

    final propertyReference =
    _properties.doc(normalizedPropertyId);

    final propertySnapshot =
    await propertyReference.get();

    if (!propertySnapshot.exists) {
      throw StateError(
        'Property does not exist.',
      );
    }

    final propertyData =
    propertySnapshot.data();

    if (propertyData == null) {
      throw StateError(
        'Property data is missing.',
      );
    }

    final propertyOwnerId =
    (propertyData['ownerId'] as String?)?.trim();

    if (propertyOwnerId != normalizedOwnerId) {
      throw StateError(
        'Selected property does not belong to the current owner.',
      );
    }

    final propertyStatus =
    propertyData['status'];

    if (propertyStatus is String &&
        propertyStatus.trim().isNotEmpty &&
        propertyStatus.toLowerCase() != 'active') {
      throw StateError(
        'Selected property is not active.',
      );
    }

    // --------------------------------------------------------------
    // UNIT
    // --------------------------------------------------------------

    final unitReference =
    _units.doc(normalizedUnitId);

    final unitSnapshot =
    await unitReference.get();

    if (!unitSnapshot.exists) {
      throw StateError(
        'Unit does not exist.',
      );
    }

    final unitData =
    unitSnapshot.data();

    if (unitData == null) {
      throw StateError(
        'Unit data is missing.',
      );
    }

    final unitPropertyId =
    (unitData['propertyId'] as String?)?.trim();

    if (unitPropertyId != normalizedPropertyId) {
      throw StateError(
        'Selected unit does not belong to the selected property.',
      );
    }

    final unitStatus =
    unitData['status'];

    if (unitStatus is String &&
        unitStatus.trim().isNotEmpty &&
        unitStatus.toLowerCase() != 'available') {
      throw StateError(
        'Selected unit is not available.',
      );
    }

    final existingTenantUserId =
    unitData['tenantUserId'];

    if (existingTenantUserId is String &&
        existingTenantUserId.trim().isNotEmpty) {
      throw StateError(
        'Selected unit is already assigned to a tenant.',
      );
    }

    // --------------------------------------------------------------
    // EXISTING PENDING INVITATION
    // --------------------------------------------------------------

    final existingSnapshot = await _invitations
        .where(
      'ownerId',
      isEqualTo: normalizedOwnerId,
    )
        .where(
      'tenantId',
      isEqualTo: normalizedTenantId,
    )
        .where(
      'status',
      isEqualTo:
      TenantInvitationStatus.pending.name,
    )
        .get();

    final now = DateTime.now();

    for (final document in existingSnapshot.docs) {
      final existingInvitation =
      TenantInvitationModel.fromFirestore(
        document,
      );

      if (!existingInvitation.isExpired) {
        throw StateError(
          'A pending tenancy invitation already exists for this tenant.',
        );
      }

      await document.reference.delete();
    }

    // --------------------------------------------------------------
    // CREATE INVITATION
    // --------------------------------------------------------------

    final invitationReference =
    _invitations.doc();

    final invitation =
    TenantInvitationModel(
      id: invitationReference.id,
      ownerId: normalizedOwnerId,
      tenantId: normalizedTenantId,
      phone: normalizedPhone,
      propertyId: normalizedPropertyId,
      propertyName:
      _readOptionalString(
        propertyData,
        'name',
      ),
      propertyCode:
      _readOptionalString(
        propertyData,
        'propertyCode',
      ),
      unitId: normalizedUnitId,
      unitNumber:
      _readOptionalString(
        unitData,
        'unitNumber',
      ),
      unitName:
      _readOptionalString(
        unitData,
        'name',
      ),
      rentAmount: rentAmount,
      status:
      TenantInvitationStatus.pending,
      token: _generateToken(),
      createdAt: now,
      updatedAt: now,
      expiresAt:
      now.add(
        const Duration(days: 7),
      ),
    );

    await invitationReference.set(
      invitation.toFirestore(),
    );

    return invitation;
  }

  // ================================================================
  // REALTIME — ALL INVITATIONS BY TENANT
  // ================================================================

  Stream<List<TenantInvitationModel>>
  watchInvitationsByTenantId(
      String tenantId,
      ) {
    final normalizedTenantId =
    tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return const Stream.empty();
    }

    return _invitations
        .where(
      'tenantId',
      isEqualTo: normalizedTenantId,
    )
        .snapshots()
        .map(
          (snapshot) {
        final invitations =
        snapshot.docs
            .map(
          TenantInvitationModel
              .fromFirestore,
        )
            .toList();

        invitations.sort(
              (a, b) =>
              b.createdAt.compareTo(
                a.createdAt,
              ),
        );

        return invitations;
      },
    );
  }

  // ================================================================
  // REALTIME — PENDING INVITATION
  // ================================================================

  Stream<TenantInvitationModel?>
  watchPendingInvitationByTenantId(
      String tenantId,
      ) {
    return watchInvitationsByTenantId(
      tenantId,
    ).map(
          (invitations) {
        final now = DateTime.now();

        for (final invitation
        in invitations) {
          if (invitation.status ==
              TenantInvitationStatus.pending &&
              now.isBefore(
                invitation.expiresAt,
              )) {
            return invitation;
          }
        }

        return null;
      },
    );
  }

  // ================================================================
  // GET INVITATION BY ID
  // ================================================================

  Future<TenantInvitationModel?>
  getInvitationById(
      String invitationId,
      ) async {
    final normalizedInvitationId =
    invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      throw ArgumentError(
        'Invitation ID cannot be empty.',
      );
    }

    final snapshot =
    await _invitations
        .doc(normalizedInvitationId)
        .get();

    if (!snapshot.exists) {
      return null;
    }

    final invitation =
    TenantInvitationModel.fromFirestore(
      snapshot,
    );

    if (invitation.status ==
        TenantInvitationStatus.pending &&
        invitation.isExpired) {
      return null;
    }

    return invitation;
  }

  // ================================================================
  // GET INVITATION BY TOKEN
  // ================================================================

  Future<TenantInvitationModel?>
  getInvitationByToken(
      String token,
      ) async {
    final normalizedToken =
    token.trim();

    if (normalizedToken.isEmpty) {
      throw ArgumentError(
        'Invitation token cannot be empty.',
      );
    }

    final snapshot = await _invitations
        .where(
      'token',
      isEqualTo: normalizedToken,
    )
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final invitation =
    TenantInvitationModel.fromFirestore(
      snapshot.docs.first,
    );

    if (invitation.status !=
        TenantInvitationStatus.pending) {
      return invitation;
    }

    if (invitation.isExpired) {
      return null;
    }

    return invitation;
  }

  // ================================================================
  // GET PENDING INVITATION BY TENANT ID
  // ================================================================

  Future<TenantInvitationModel?>
  getPendingInvitationByTenantId(
      String tenantId,
      ) async {
    final normalizedTenantId =
    tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      throw ArgumentError(
        'Tenant ID cannot be empty.',
      );
    }

    final snapshot = await _invitations
        .where(
      'tenantId',
      isEqualTo: normalizedTenantId,
    )
        .where(
      'status',
      isEqualTo:
      TenantInvitationStatus.pending.name,
    )
        .limit(10)
        .get();

    for (final document
    in snapshot.docs) {
      final invitation =
      TenantInvitationModel.fromFirestore(
        document,
      );

      if (!invitation.isExpired) {
        return invitation;
      }
    }

    return null;
  }

  // ================================================================
  // GET PENDING INVITATION BY PHONE
  // ================================================================

  Future<TenantInvitationModel?>
  getPendingInvitationByPhone(
      String phone,
      ) async {
    final normalizedPhone =
    PhoneNumberUtils.normalizeAndValidate(
      phone,
    );

    final snapshot = await _invitations
        .where(
      'phone',
      isEqualTo: normalizedPhone,
    )
        .where(
      'status',
      isEqualTo:
      TenantInvitationStatus.pending.name,
    )
        .limit(10)
        .get();

    for (final document
    in snapshot.docs) {
      final invitation =
      TenantInvitationModel.fromFirestore(
        document,
      );

      if (!invitation.isExpired) {
        return invitation;
      }
    }

    return null;
  }

  // ================================================================
  // ACCEPT INVITATION
  // ================================================================

  Future<void> acceptInvitation(
      String invitationId,
      ) async {
    final normalizedInvitationId =
    invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      throw ArgumentError(
        'Invitation ID cannot be empty.',
      );
    }

    final firebaseUser =
        _auth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
        'You must be signed in to accept an invitation.',
      );
    }

    final userId =
        firebaseUser.uid;

    final invitationReference =
    _invitations.doc(
      normalizedInvitationId,
    );

    await _firestore.runTransaction(
          (transaction) async {
        // --------------------------------------------------------------
        // READ INVITATION
        // --------------------------------------------------------------

        final invitationSnapshot =
        await transaction.get(
          invitationReference,
        );

        if (!invitationSnapshot.exists) {
          throw StateError(
            'Invitation does not exist.',
          );
        }

        final invitation =
        TenantInvitationModel
            .fromFirestore(
          invitationSnapshot,
        );

        if (invitation.status !=
            TenantInvitationStatus.pending) {
          throw StateError(
            'This invitation is no longer pending.',
          );
        }

        final now =
        DateTime.now();

        if (!now.isBefore(
          invitation.expiresAt,
        )) {
          throw StateError(
            'This invitation has expired.',
          );
        }

        // --------------------------------------------------------------
        // REFERENCES
        // --------------------------------------------------------------

        final tenantReference =
        _tenants.doc(
          invitation.tenantId,
        );

        final tenantAccessReference =
        _tenantAccess.doc(userId);

        final propertyReference =
        _properties.doc(
          invitation.propertyId,
        );

        final unitReference =
        _units.doc(
          invitation.unitId,
        );

        // --------------------------------------------------------------
        // READ ALL DOCUMENTS
        // --------------------------------------------------------------

        final tenantSnapshot =
        await transaction.get(
          tenantReference,
        );

        final tenantAccessSnapshot =
        await transaction.get(
          tenantAccessReference,
        );

        final propertySnapshot =
        await transaction.get(
          propertyReference,
        );

        final unitSnapshot =
        await transaction.get(
          unitReference,
        );

        // --------------------------------------------------------------
        // TENANT
        // --------------------------------------------------------------

        if (!tenantSnapshot.exists) {
          throw StateError(
            'Tenant does not exist.',
          );
        }

        final tenant =
        TenantModel.fromFirestore(
          tenantSnapshot,
        );

        if (tenant.ownerId !=
            invitation.ownerId) {
          throw StateError(
            'Invitation owner does not match tenant owner.',
          );
        }

        if (tenant.status !=
            TenantStatus.inactive) {
          throw StateError(
            'Tenant is already active.',
          );
        }

        if (tenant.accountStatus !=
            TenantAccountStatus.registered) {
          throw StateError(
            'Tenant account is not registered.',
          );
        }

        final linkedUserId =
        tenant.userId?.trim();

        if (linkedUserId != null &&
            linkedUserId.isNotEmpty &&
            linkedUserId != userId) {
          throw StateError(
            'This tenant account is linked to another user.',
          );
        }

        // --------------------------------------------------------------
        // PHONE VALIDATION
        // --------------------------------------------------------------

        final tenantPhone =
        PhoneNumberUtils.normalizeAndValidate(
          tenant.phone,
        );

        final invitationPhone =
        PhoneNumberUtils.normalizeAndValidate(
          invitation.phone,
        );

        final authPhoneRaw =
            firebaseUser.phoneNumber;

        if (tenantPhone !=
            invitationPhone) {
          throw StateError(
            'Tenant phone does not match invitation phone.',
          );
        }

        if (authPhoneRaw != null &&
            authPhoneRaw.trim().isNotEmpty) {
          final authPhone =
          PhoneNumberUtils
              .normalizeAndValidate(
            authPhoneRaw,
          );

          if (authPhone !=
              invitationPhone) {
            throw StateError(
              'Signed-in phone number does not match invitation phone.',
            );
          }
        }

        // --------------------------------------------------------------
        // PROPERTY
        // --------------------------------------------------------------

        if (!propertySnapshot.exists) {
          throw StateError(
            'Invitation property no longer exists.',
          );
        }

        final propertyData =
        propertySnapshot.data();

        if (propertyData == null) {
          throw StateError(
            'Property data is missing.',
          );
        }

        final propertyOwnerId =
        (propertyData['ownerId']
        as String?)
            ?.trim();

        if (propertyOwnerId !=
            invitation.ownerId) {
          throw StateError(
            'Invitation property does not belong to the owner.',
          );
        }

        final propertyStatus =
        propertyData['status'];

        if (propertyStatus is String &&
            propertyStatus.trim().isNotEmpty &&
            propertyStatus.toLowerCase() !=
                'active') {
          throw StateError(
            'Invitation property is no longer active.',
          );
        }

        // --------------------------------------------------------------
        // UNIT
        // --------------------------------------------------------------

        if (!unitSnapshot.exists) {
          throw StateError(
            'Invitation unit no longer exists.',
          );
        }

        final unitData =
        unitSnapshot.data();

        if (unitData == null) {
          throw StateError(
            'Unit data is missing.',
          );
        }

        final unitPropertyId =
        (unitData['propertyId']
        as String?)
            ?.trim();

        if (unitPropertyId !=
            invitation.propertyId) {
          throw StateError(
            'Invitation unit does not belong to the invitation property.',
          );
        }

        final unitStatus =
        unitData['status'];

        if (unitStatus is String &&
            unitStatus.trim().isNotEmpty &&
            unitStatus.toLowerCase() !=
                'available') {
          throw StateError(
            'This unit is no longer available.',
          );
        }

        final existingUnitTenantUserId =
        unitData['tenantUserId'];

        if (existingUnitTenantUserId is String &&
            existingUnitTenantUserId
                .trim()
                .isNotEmpty) {
          throw StateError(
            'This unit is already assigned to a tenant.',
          );
        }

        // --------------------------------------------------------------
        // EXISTING TENANT ACCESS
        // --------------------------------------------------------------

        if (tenantAccessSnapshot.exists) {
          final accessData =
          tenantAccessSnapshot.data();

          if (accessData == null) {
            throw StateError(
              'Tenant access data is invalid.',
            );
          }

          final accessTenantId =
          accessData['tenantId'];

          if (accessTenantId is String &&
              accessTenantId.trim().isNotEmpty &&
              accessTenantId !=
                  invitation.tenantId) {
            throw StateError(
              'This account is already linked to another tenant.',
            );
          }

          final accessOwnerId =
          accessData['ownerId'];

          if (accessOwnerId is String &&
              accessOwnerId.trim().isNotEmpty &&
              accessOwnerId !=
                  invitation.ownerId) {
            throw StateError(
              'This account already has tenant access for another owner.',
            );
          }
        }

        // --------------------------------------------------------------
        // CURRENT RENT RATE
        // --------------------------------------------------------------

        final rentRateSnapshot =
        await _rentRates
            .where(
          'unitId',
          isEqualTo:
          invitation.unitId,
        )
            .where(
          'ownerId',
          isEqualTo:
          invitation.ownerId,
        )
            .where(
          'effectiveFrom',
          isLessThanOrEqualTo:
          Timestamp.fromDate(now),
        )
            .orderBy(
          'effectiveFrom',
          descending: true,
        )
            .limit(1)
            .get();

        RentRateModel?
        currentRentRate;

        if (rentRateSnapshot.docs
            .isNotEmpty) {
          final candidate =
          RentRateModel
              .fromFirestore(
            rentRateSnapshot.docs.first,
          );

          if (candidate.isApplicableAt(
            now,
          )) {
            currentRentRate =
                candidate;
          }
        }

        // --------------------------------------------------------------
        // RENT RATE REFERENCE
        // --------------------------------------------------------------

        final newRentRateReference =
        _rentRates.doc();

        final shouldCreateRentRate =
            currentRentRate == null ||
                currentRentRate.amount !=
                    invitation.rentAmount;

        // --------------------------------------------------------------
        // UPDATE TENANT
        // --------------------------------------------------------------

        transaction.update(
          tenantReference,
          {
            'userId': userId,
            'propertyId':
            invitation.propertyId,
            'unitId':
            invitation.unitId,
            'status':
            TenantStatus.active.name,
            'accountStatus':
            TenantAccountStatus
                .registered
                .name,
            'confirmationStatus':
            TenantConfirmationStatus
                .confirmed
                .name,
            'tenancyStartedAt':
            Timestamp.fromDate(now),
            'updatedAt':
            Timestamp.fromDate(now),
          },
        );

        // --------------------------------------------------------------
        // TENANT ACCESS
        // --------------------------------------------------------------

        transaction.set(
          tenantAccessReference,
          {
            'userId': userId,
            'tenantId':
            invitation.tenantId,
            'ownerId':
            invitation.ownerId,
            'propertyId':
            invitation.propertyId,
            'unitId':
            invitation.unitId,
            'invitationId':
            invitation.id,
            'createdAt':
            Timestamp.fromDate(now),
            'updatedAt':
            Timestamp.fromDate(now),
          },
        );

        // --------------------------------------------------------------
        // UNIT
        // --------------------------------------------------------------

        transaction.update(
          unitReference,
          {
            'status':
            UnitStatus.occupied.name,
            'tenantUserId':
            userId,
            'updatedAt':
            Timestamp.fromDate(now),
          },
        );

        // --------------------------------------------------------------
        // PROPERTY
        // --------------------------------------------------------------

        transaction.update(
          propertyReference,
          {
            'tenantUserIds':
            FieldValue.arrayUnion(
              [userId],
            ),
            'updatedAt':
            Timestamp.fromDate(now),
          },
        );

        // --------------------------------------------------------------
        // RENT RATE
        // --------------------------------------------------------------

        if (shouldCreateRentRate) {
          if (currentRentRate !=
              null) {
            final oldRentRateReference =
            _rentRates.doc(
              currentRentRate.id,
            );

            transaction.update(
              oldRentRateReference,
              {
                'effectiveTo':
                Timestamp.fromDate(
                  now,
                ),
                'nextRentRateId':
                newRentRateReference.id,
                'updatedAt':
                Timestamp.fromDate(
                  now,
                ),
              },
            );
          }

          final source =
          currentRentRate == null
              ? RentRateSource.initial
              : RentRateSource.unit;

          final newRentRate =
          RentRateModel(
            id:
            newRentRateReference.id,
            ownerId:
            invitation.ownerId,
            propertyId:
            invitation.propertyId,
            unitId:
            invitation.unitId,
            amount:
            invitation.rentAmount,
            effectiveFrom:
            now,
            effectiveTo:
            null,
            source:
            source,
            previousRentRateId:
            currentRentRate?.id,
            nextRentRateId:
            null,
            createdAt:
            now,
            updatedAt:
            now,
          );

          transaction.set(
            newRentRateReference,
            newRentRate.toFirestore(),
          );
        }

        // --------------------------------------------------------------
        // INVITATION → ACCEPTED
        // --------------------------------------------------------------

        transaction.update(
          invitationReference,
          {
            'status':
            TenantInvitationStatus
                .accepted
                .name,
            'updatedAt':
            Timestamp.fromDate(now),
          },
        );

        if (kDebugMode) {
          debugPrint(
            '[ACCEPT INVITATION] '
                'Invitation accepted: '
                '${invitation.id}',
          );
        }
      },
    );
  }

  // ================================================================
  // CANCEL / REJECT INVITATION
  // ================================================================

  Future<void> cancelInvitation(
      String invitationId,
      ) async {
    final normalizedInvitationId =
    invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      throw ArgumentError(
        'Invitation ID cannot be empty.',
      );
    }

    final firebaseUser =
        _auth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
        'You must be signed in to cancel an invitation.',
      );
    }

    final invitationReference =
    _invitations.doc(
      normalizedInvitationId,
    );

    final snapshot =
    await invitationReference.get();

    if (!snapshot.exists) {
      throw StateError(
        'Invitation does not exist.',
      );
    }

    final invitation =
    TenantInvitationModel
        .fromFirestore(
      snapshot,
    );

    if (invitation.status !=
        TenantInvitationStatus.pending) {
      throw StateError(
        'Only pending invitations can be cancelled or rejected.',
      );
    }

    final authUid =
        firebaseUser.uid;

    // --------------------------------------------------------------
    // TENANT REJECT
    // --------------------------------------------------------------

    final authPhoneRaw =
        firebaseUser.phoneNumber;

    if (authPhoneRaw != null &&
        authPhoneRaw.trim().isNotEmpty) {
      final authPhone =
      PhoneNumberUtils
          .normalizeAndValidate(
        authPhoneRaw,
      );

      final invitationPhone =
      PhoneNumberUtils
          .normalizeAndValidate(
        invitation.phone,
      );

      if (authPhone ==
          invitationPhone) {
        await invitationReference.update(
          {
            'status':
            TenantInvitationStatus
                .rejected
                .name,
            'updatedAt':
            FieldValue.serverTimestamp(),
          },
        );

        return;
      }
    }

    // --------------------------------------------------------------
    // OWNER CANCEL
    // --------------------------------------------------------------

    if (invitation.ownerId ==
        authUid) {
      await invitationReference.update(
        {
          'status':
          TenantInvitationStatus
              .cancelled
              .name,
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
      );

      return;
    }

    throw StateError(
      'You are not authorized to cancel this invitation.',
    );
  }

  // ================================================================
  // EXPIRE INVITATION
  // ================================================================

  Future<void> expireInvitation(
      String invitationId,
      ) async {
    final normalizedInvitationId =
    invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      throw ArgumentError(
        'Invitation ID cannot be empty.',
      );
    }

    final firebaseUser =
        _auth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
        'You must be signed in to expire an invitation.',
      );
    }

    final invitationReference =
    _invitations.doc(
      normalizedInvitationId,
    );

    final snapshot =
    await invitationReference.get();

    if (!snapshot.exists) {
      throw StateError(
        'Invitation does not exist.',
      );
    }

    final invitation =
    TenantInvitationModel
        .fromFirestore(
      snapshot,
    );

    if (invitation.ownerId !=
        firebaseUser.uid) {
      throw StateError(
        'Only the owner can expire an invitation.',
      );
    }

    if (invitation.status !=
        TenantInvitationStatus.pending) {
      throw StateError(
        'Only pending invitations can be expired.',
      );
    }

    await invitationReference.update(
      {
        'status':
        TenantInvitationStatus
            .expired
            .name,
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
    );
  }

  // ================================================================
  // HELPERS
  // ================================================================

  String _generateToken() {
    final random =
    Random.secure();

    const characters =
        'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

    return List.generate(
      12,
          (_) => characters[
      random.nextInt(
        characters.length,
      )],
    ).join();
  }

  String? _readOptionalString(
      Map<String, dynamic> data,
      String field,
      ) {
    final value =
    data[field];

    if (value == null) {
      return null;
    }

    if (value is! String) {
      return null;
    }

    final normalized =
    value.trim();

    return normalized.isEmpty
        ? null
        : normalized;
  }
}