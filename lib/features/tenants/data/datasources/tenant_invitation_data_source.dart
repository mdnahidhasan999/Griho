import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../rents/domain/entities/rent_rate.dart';
import '../../../units/domain/entities/unit.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_invitation.dart';
import '../models/tenant_invitation_model.dart';

class TenantInvitationDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TenantInvitationDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ============================================================
  // COLLECTIONS
  // ============================================================

  static const String _invitationCollectionName = 'tenantInvitations';
  static const String _tenantCollectionName = 'tenants';
  static const String _propertyCollectionName = 'properties';
  static const String _unitCollectionName = 'units';
  static const String _tenantAccessCollectionName = 'tenantAccess';
  static const String _rentRateCollectionName = 'rentRates';

  CollectionReference<Map<String, dynamic>> get _invitations {
    return _firestore.collection(_invitationCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _tenants {
    return _firestore.collection(_tenantCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _properties {
    return _firestore.collection(_propertyCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _units {
    return _firestore.collection(_unitCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _tenantAccess {
    return _firestore.collection(_tenantAccessCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _rentRates {
    return _firestore.collection(_rentRateCollectionName);
  }

  // ============================================================
  // PHONE
  // ============================================================

  String _normalizePhone(String phone) {
    return PhoneNumberUtils.normalizeAndValidate(phone);
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  String get _currentUserId {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('You must be signed in.');
    }

    return user.uid;
  }

  // ============================================================
  // CREATE INVITATION
  // OWNER ONLY
  // ============================================================

  Future<TenantInvitationModel> createInvitation({
    required String ownerId,
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
    required double rentAmount,
  }) async {
    final currentUserId = _currentUserId;

    if (currentUserId != ownerId) {
      throw StateError(
        'You are not authorized to create this invitation.',
      );
    }

    if (rentAmount <= 0) {
      throw ArgumentError(
        'Monthly rent must be greater than zero.',
      );
    }

    final normalizedPhone = _normalizePhone(phone);

    // ==========================================================
    // TENANT
    // ==========================================================

    final tenantReference = _tenants.doc(tenantId);

    final tenantSnapshot = await tenantReference.get();

    if (!tenantSnapshot.exists) {
      throw StateError(
        'Tenant record does not exist.',
      );
    }

    final tenantData = tenantSnapshot.data();

    if (tenantData == null) {
      throw StateError(
        'Tenant data is unavailable.',
      );
    }

    if (tenantData['ownerId'] != currentUserId) {
      throw StateError(
        'You are not authorized to invite this tenant.',
      );
    }

    if (tenantData['propertyId'] != propertyId) {
      throw StateError(
        'Tenant property does not match the invitation.',
      );
    }

    if (tenantData['unitId'] != unitId) {
      throw StateError(
        'Tenant unit does not match the invitation.',
      );
    }

    // ==========================================================
    // TENANT PHONE
    // ==========================================================

    final tenantPhone =
    tenantData['phone']?.toString().trim();

    if (tenantPhone == null || tenantPhone.isEmpty) {
      throw StateError(
        'Tenant phone number is not available.',
      );
    }

    final normalizedTenantPhone =
    _normalizePhone(tenantPhone);

    if (normalizedTenantPhone != normalizedPhone) {
      throw StateError(
        'Invitation phone number does not match the tenant phone number.',
      );
    }

    // ==========================================================
    // PROPERTY
    // ==========================================================

    final propertyReference =
    _properties.doc(propertyId);

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
        'Property data is unavailable.',
      );
    }

    if (propertyData['ownerId'] != currentUserId) {
      throw StateError(
        'You are not authorized to use this property.',
      );
    }

    final propertyName =
    propertyData['name'];

    if (propertyName is! String ||
        propertyName
            .trim()
            .isEmpty) {
      throw StateError(
        'Property name is missing or invalid.',
      );
    }

    final normalizedPropertyName =
    propertyName.trim();

    final propertyCode =
    propertyData['propertyCode'];

    if (propertyCode is! String ||
        propertyCode
            .trim()
            .isEmpty) {
      throw StateError(
        'Property code is missing or invalid.',
      );
    }

    final normalizedPropertyCode =
    propertyCode.trim();

    // ==========================================================
    // UNIT
    // ==========================================================

    final unitReference =
    _units.doc(unitId);

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
        'Unit data is unavailable.',
      );
    }

    if (unitData['propertyId'] != propertyId) {
      throw StateError(
        'Unit property does not match the invitation.',
      );
    }

    final unitNumber =
    unitData['unitNumber'];

    if (unitNumber is! String ||
        unitNumber
            .trim()
            .isEmpty) {
      throw StateError(
        'Unit number is missing or invalid.',
      );
    }

    final normalizedUnitNumber =
    unitNumber.trim();

    final rawUnitName =
    unitData['name'];

    final normalizedUnitName =
    rawUnitName is String &&
        rawUnitName
            .trim()
            .isNotEmpty
        ? rawUnitName.trim()
        : null;

    // ==========================================================
    // EXISTING PENDING INVITATION
    // ==========================================================

    final existingSnapshot = await _invitations
        .where(
      'tenantId',
      isEqualTo: tenantId,
    )
        .where(
      'ownerId',
      isEqualTo: currentUserId,
    )
        .where(
      'status',
      isEqualTo:
      TenantInvitationStatus.pending.name,
    )
        .limit(1)
        .get();

    if (existingSnapshot.docs.isNotEmpty) {
      final existingInvitation =
      TenantInvitationModel.fromFirestore(
        existingSnapshot.docs.first,
      );

      if (existingInvitation.isExpired) {
        await _deleteInvitationDocument(
          existingInvitation.id,
        );
      } else {
        throw StateError(
          'A pending invitation already exists for this tenant.',
        );
      }
    }

    // ==========================================================
    // CREATE INVITATION
    // ==========================================================

    final documentReference =
    _invitations.doc();

    final invitationId =
        documentReference.id;

    final token =
    _generateToken();

    final now =
    DateTime.now();

    final expiresAt =
    now.add(
      const Duration(days: 7),
    );

    final invitation =
    TenantInvitationModel(
      id: invitationId,
      ownerId: ownerId,
      tenantId: tenantId,
      phone: normalizedPhone,
      propertyId: propertyId,
      propertyName: normalizedPropertyName,
      propertyCode: normalizedPropertyCode,
      unitId: unitId,
      unitNumber: normalizedUnitNumber,
      unitName: normalizedUnitName,
      rentAmount: rentAmount,
      status: TenantInvitationStatus.pending,
      token: token,
      createdAt: now,
      updatedAt: now,
      expiresAt: expiresAt,
    );

    await documentReference.set(
      invitation.toFirestore(),
    );

    return invitation;
  }

  // ============================================================
  // GET INVITATION BY ID
  // ============================================================

  Future<TenantInvitationModel?> getInvitationById(String invitationId,) async {
    final normalizedId =
    invitationId.trim();

    if (normalizedId.isEmpty) {
      return null;
    }

    final snapshot =
    await _invitations
        .doc(normalizedId)
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

  // ============================================================
  // GET INVITATION BY TOKEN
  // ============================================================

  Future<TenantInvitationModel?> getInvitationByToken(String token,) async {
    final normalizedToken =
    token.trim();

    if (normalizedToken.isEmpty) {
      return null;
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
      return null;
    }

    if (invitation.isExpired) {
      return null;
    }

    return invitation;
  }

  // ============================================================
  // GET PENDING INVITATION BY TENANT ID
  // OWNER ONLY
  // ============================================================

  Future<TenantInvitationModel?>
  getPendingInvitationByTenantId(String tenantId,) async {
    final currentUserId =
        _currentUserId;

    final normalizedTenantId =
    tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return null;
    }

    final snapshot = await _invitations
        .where(
      'tenantId',
      isEqualTo: normalizedTenantId,
    )
        .where(
      'ownerId',
      isEqualTo: currentUserId,
    )
        .where(
      'status',
      isEqualTo:
      TenantInvitationStatus.pending.name,
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

    if (invitation.isExpired) {
      return null;
    }

    return invitation;
  }

  // ============================================================
  // GET PENDING INVITATION BY PHONE
  // ============================================================

  Future<TenantInvitationModel?>
  getPendingInvitationByPhone(String phone,) async {
    final normalizedPhone =
    _normalizePhone(phone);

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
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final invitation =
    TenantInvitationModel.fromFirestore(
      snapshot.docs.first,
    );

    if (invitation.isExpired) {
      return null;
    }

    return invitation;
  }

  // ============================================================
  // ACCEPT INVITATION
  //
  // ATOMIC:
  //
  // 1. Tenant account link
  // 2. Tenant active status
  // 3. Tenant confirmation
  // 4. Tenancy start timestamp
  // 5. Tenant access
  // 6. Unit occupied
  // 7. Property tenant access
  // 8. Initial RentRate
  // 9. Invitation accepted
  //
  // Everything is committed in ONE transaction.
  //
  // IMPORTANT:
  // Property and Unit are intentionally NOT read by the client
  // inside this transaction.
  //
  // Their final state is validated by Firestore Security Rules
  // through getAfter().
  // ============================================================

  Future<void> acceptInvitation(String invitationId,) async {
    final currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      throw StateError(
        'You must be signed in before accepting this invitation.',
      );
    }

    final currentUserId =
    currentUser.uid.trim();

    if (currentUserId.isEmpty) {
      throw StateError(
        'Your Firebase user ID is unavailable.',
      );
    }

    final firebasePhone =
    currentUser.phoneNumber?.trim();

    if (firebasePhone == null ||
        firebasePhone.isEmpty) {
      throw StateError(
        'Your Firebase phone number is not available.',
      );
    }

    final normalizedFirebasePhone =
    _normalizePhone(firebasePhone);

    final normalizedInvitationId =
    invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      throw ArgumentError(
        'Invitation ID cannot be empty.',
      );
    }

    final invitationReference =
    _invitations.doc(
      normalizedInvitationId,
    );

    // ==========================================================
    // INITIAL INVITATION READ
    // ==========================================================

    final invitationSnapshot =
    await invitationReference.get();

    if (!invitationSnapshot.exists) {
      throw StateError(
        'Invitation does not exist.',
      );
    }

    final invitation =
    TenantInvitationModel.fromFirestore(
      invitationSnapshot,
    );

    if (invitation.status !=
        TenantInvitationStatus.pending) {
      throw StateError(
        'This invitation has already been used.',
      );
    }

    if (invitation.isExpired) {
      throw StateError(
        'This invitation has expired.',
      );
    }

    final invitationPhone =
    _normalizePhone(
      invitation.phone,
    );

    if (normalizedFirebasePhone !=
        invitationPhone) {
      throw StateError(
        'This invitation belongs to a different phone number.',
      );
    }

    // ==========================================================
    // REFERENCES
    // ==========================================================

    final tenantReference =
    _tenants.doc(
      invitation.tenantId,
    );

    final propertyReference =
    _properties.doc(
      invitation.propertyId,
    );

    final unitReference =
    _units.doc(
      invitation.unitId,
    );

    final tenantAccessReference =
    _tenantAccess.doc(
      currentUserId,
    );

    // ==========================================================
    // ONE TRANSACTION
    // ==========================================================

    await _firestore.runTransaction(
          (transaction) async {
        // ========================================================
        // READ PHASE
        //
        // Only documents that the invited tenant is permitted
        // to read are read here.
        //
        // Property and Unit are intentionally omitted.
        // ========================================================

        final freshInvitation =
        await transaction.get(
          invitationReference,
        );

        final freshTenant =
        await transaction.get(
          tenantReference,
        );

        final freshTenantAccess =
        await transaction.get(
          tenantAccessReference,
        );

        if (!freshInvitation.exists) {
          throw StateError(
            'Invitation no longer exists.',
          );
        }

        if (!freshTenant.exists) {
          throw StateError(
            'Tenant record no longer exists.',
          );
        }

        final freshInvitationData =
        freshInvitation.data();

        final freshTenantData =
        freshTenant.data();

        if (freshInvitationData == null ||
            freshTenantData == null) {
          throw StateError(
            'Invitation or tenant data is unavailable.',
          );
        }

        // ========================================================
        // INVITATION STATUS
        // ========================================================

        if (freshInvitationData['status'] !=
            TenantInvitationStatus.pending.name) {
          throw StateError(
            'This invitation has already been used.',
          );
        }

        // ========================================================
        // INVITATION EXPIRY
        // ========================================================

        final expiresAt =
        _readDateTime(
          freshInvitationData['expiresAt'],
        );

        if (expiresAt == null) {
          throw StateError(
            'Invitation expiry date is invalid.',
          );
        }

        if (!expiresAt.isAfter(
          DateTime.now(),
        )) {
          throw StateError(
            'This invitation has expired.',
          );
        }

        // ========================================================
        // INVITATION PHONE
        // ========================================================

        final freshInvitationPhone =
        _normalizePhone(
          freshInvitationData['phone']
              ?.toString() ??
              '',
        );

        if (freshInvitationPhone !=
            normalizedFirebasePhone) {
          throw StateError(
            'This invitation belongs to a different phone number.',
          );
        }

        // ========================================================
        // INVITATION RENT
        // ========================================================

        final rawRentAmount =
        freshInvitationData['rentAmount'];

        if (rawRentAmount is! num ||
            rawRentAmount <= 0) {
          throw StateError(
            'Invitation monthly rent is missing or invalid.',
          );
        }

        final invitationRentAmount =
        rawRentAmount.toDouble();

        // ========================================================
        // INVITATION IDENTITY
        // ========================================================

        if (freshInvitationData['ownerId'] is! String ||
            freshInvitationData['tenantId'] is! String ||
            freshInvitationData['propertyId'] is! String ||
            freshInvitationData['unitId'] is! String) {
          throw StateError(
            'Invitation relationship data is invalid.',
          );
        }

        if (freshInvitationData['tenantId'] !=
            invitation.tenantId) {
          throw StateError(
            'Invitation tenant has changed.',
          );
        }

        if (freshInvitationData['propertyId'] !=
            invitation.propertyId) {
          throw StateError(
            'Invitation property has changed.',
          );
        }

        if (freshInvitationData['unitId'] !=
            invitation.unitId) {
          throw StateError(
            'Invitation unit has changed.',
          );
        }

        // ========================================================
        // TENANT RELATIONSHIP
        // ========================================================

        if (freshTenantData['ownerId'] !=
            freshInvitationData['ownerId']) {
          throw StateError(
            'Tenant owner does not match this invitation.',
          );
        }

        if (freshTenantData['propertyId'] !=
            freshInvitationData['propertyId']) {
          throw StateError(
            'Tenant property does not match the invitation.',
          );
        }

        if (freshTenantData['unitId'] !=
            freshInvitationData['unitId']) {
          throw StateError(
            'Tenant unit does not match the invitation.',
          );
        }

        // ========================================================
        // TENANT PHONE
        // ========================================================

        final freshTenantPhone =
        _normalizePhone(
          freshTenantData['phone']
              ?.toString() ??
              '',
        );

        if (freshTenantPhone !=
            normalizedFirebasePhone) {
          throw StateError(
            'Your phone number does not match the tenant record.',
          );
        }

        // ========================================================
        // EXISTING TENANT LINK
        // ========================================================

        final linkedUserId =
        freshTenantData['userId'];

        if (linkedUserId != null &&
            linkedUserId
                .toString()
                .trim()
                .isNotEmpty &&
            linkedUserId != currentUserId) {
          throw StateError(
            'This tenant account is already linked to another user.',
          );
        }

        // ========================================================
        // EXISTING TENANT ACCESS
        // ========================================================

        Map<String, dynamic>?
        existingTenantAccessData;

        if (freshTenantAccess.exists) {
          final data =
          freshTenantAccess.data();

          if (data == null) {
            throw StateError(
              'Tenant access data is unavailable.',
            );
          }

          existingTenantAccessData =
              data;

          if (data['tenantId'] !=
              freshInvitationData['tenantId']) {
            throw StateError(
              'This user already has a different tenant access.',
            );
          }

          if (data['ownerId'] !=
              freshTenantData['ownerId']) {
            throw StateError(
              'This user already has access to another owner.',
            );
          }

          if (data['propertyId'] !=
              freshTenantData['propertyId']) {
            throw StateError(
              'This user already has access to another property.',
            );
          }

          if (data['unitId'] !=
              freshTenantData['unitId']) {
            throw StateError(
              'This user already has access to another unit.',
            );
          }
        }

        // ========================================================
        // TENANCY START TIME
        //
        // The exact same timestamp is used for:
        //
        // tenant.tenancyStartedAt
        // ==
        // rentRate.effectiveFrom
        //
        // ========================================================

        final now =
        DateTime.now();

        final tenancyStartedAt =
            now;

        // ========================================================
        // TENANT ACCOUNT LINK + ACTIVE TENANCY
        // ========================================================

        final tenantUpdate =
        <String, dynamic>{
          'userId': currentUserId,
          'status':
          TenantStatus.active.name,
          'accountStatus':
          TenantAccountStatus.registered.name,
          'confirmationStatus':
          TenantConfirmationStatus
              .confirmed
              .name,
          'tenancyStartedAt':
          Timestamp.fromDate(
            tenancyStartedAt,
          ),
          'updatedAt':
          Timestamp.fromDate(now),
        };

        transaction.update(
          tenantReference,
          tenantUpdate,
        );

        // ========================================================
        // TENANT ACCESS
        // ========================================================

        final existingCreatedAt =
        existingTenantAccessData?[
        'createdAt'];

        transaction.set(
          tenantAccessReference,
          {
            'userId': currentUserId,
            'tenantId':
            invitation.tenantId,
            'ownerId':
            invitation.ownerId,
            'propertyId':
            invitation.propertyId,
            'unitId':
            invitation.unitId,
            'invitationId':
            normalizedInvitationId,
            'createdAt':
            existingCreatedAt is Timestamp
                ? existingCreatedAt
                : Timestamp.fromDate(
              now,
            ),
            'updatedAt':
            Timestamp.fromDate(now),
          },
        );

        // ========================================================
        // UNIT
        //
        // Firestore Rules validate that the unit:
        //
        // - belongs to the invitation property
        // - was previously unassigned
        // - becomes occupied
        // - becomes assigned to the current user
        //
        // through getAfter().
        // ========================================================

        transaction.update(
          unitReference,
          {
            'tenantUserId':
            currentUserId,
            'status':
            UnitStatus.occupied.name,
            'updatedAt':
            Timestamp.fromDate(now),
          },
        );

        // ========================================================
        // PROPERTY
        //
        // Firestore Rules validate the property transition
        // through getAfter().
        // ========================================================

        transaction.update(
          propertyReference,
          {
            'tenantUserIds':
            FieldValue.arrayUnion([
              currentUserId,
            ]),
            'updatedAt':
            Timestamp.fromDate(now),
          },
        );

        // ========================================================
        // INITIAL RENT RATE
        //
        // Amount comes ONLY from the invitation.
        //
        // Firestore Rules independently verify:
        //
        // RentRate.amount == invitation.rentAmount
        //
        // ========================================================

        final rentRateReference =
        _rentRates.doc();

        final initialRentRate =
        <String, dynamic>{
          'ownerId':
          invitation.ownerId,
          'propertyId':
          invitation.propertyId,
          'unitId':
          invitation.unitId,
          'tenantId':
          invitation.tenantId,
          'tenantUserId':
          currentUserId,
          'amount':
          invitationRentAmount,
          'effectiveFrom':
          Timestamp.fromDate(
            tenancyStartedAt,
          ),
          'effectiveTo':
          null,
          'source':
          RentRateSource.initial.name,
          'createdAt':
          Timestamp.fromDate(now),
          'updatedAt':
          Timestamp.fromDate(now),
        };

        transaction.set(
          rentRateReference,
          initialRentRate,
        );

        // ========================================================
        // ACCEPT INVITATION
        // ========================================================

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
      },
    );
  }

  // ============================================================
  // CANCEL / REJECT INVITATION
  // ============================================================

  Future<void> cancelInvitation(String invitationId,) async {
    final currentUserId =
        _currentUserId;

    final normalizedInvitationId =
    invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      throw ArgumentError(
        'Invitation ID cannot be empty.',
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
    TenantInvitationModel.fromFirestore(
      snapshot,
    );

    if (invitation.status !=
        TenantInvitationStatus.pending) {
      throw StateError(
        'This invitation is no longer pending.',
      );
    }

    // ==========================================================
    // OWNER CANCEL
    // ==========================================================

    if (invitation.ownerId ==
        currentUserId) {
      await invitationReference.update({
        'status':
        TenantInvitationStatus
            .cancelled
            .name,
        'updatedAt':
        FieldValue.serverTimestamp(),
      });

      return;
    }

    // ==========================================================
    // TENANT REJECT
    // ==========================================================

    final firebaseUser =
        _auth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
        'You must be signed in.',
      );
    }

    final firebasePhone =
    firebaseUser.phoneNumber?.trim();

    if (firebasePhone == null ||
        firebasePhone.isEmpty) {
      throw StateError(
        'Your Firebase phone number is not available.',
      );
    }

    final normalizedFirebasePhone =
    PhoneNumberUtils
        .normalizeAndValidate(
      firebasePhone,
    );

    final normalizedInvitationPhone =
    PhoneNumberUtils
        .normalizeAndValidate(
      invitation.phone,
    );

    if (normalizedFirebasePhone !=
        normalizedInvitationPhone) {
      throw StateError(
        'You are not authorized to reject this invitation.',
      );
    }

    await invitationReference.update({
      'status':
      TenantInvitationStatus
          .rejected
          .name,
      'updatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // EXPIRE INVITATION
  // OWNER ONLY
  // ============================================================

  Future<void> expireInvitation(String invitationId,) async {
    final currentUserId =
        _currentUserId;

    final normalizedInvitationId =
    invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      return;
    }

    final document =
    _invitations.doc(
      normalizedInvitationId,
    );

    final snapshot =
    await document.get();

    if (!snapshot.exists) {
      return;
    }

    final invitation =
    TenantInvitationModel.fromFirestore(
      snapshot,
    );

    if (invitation.ownerId !=
        currentUserId) {
      throw StateError(
        'You are not authorized to expire this invitation.',
      );
    }

    if (invitation.status !=
        TenantInvitationStatus.pending) {
      return;
    }

    if (!invitation.isExpired) {
      throw StateError(
        'This invitation has not expired yet.',
      );
    }

    await _deleteInvitationDocument(
      invitation.id,
    );
  }

  // ============================================================
  // DELETE INVITATION DOCUMENT
  // ============================================================

  Future<void> _deleteInvitationDocument(String invitationId,) async {
    await _invitations
        .doc(invitationId)
        .delete();
  }

  // ============================================================
  // TOKEN
  // ============================================================

  String _generateToken() {
    const characters =
        'ABCDEFGHJKLMNPQRSTUVWXYZ'
        'abcdefghijkmnopqrstuvwxyz'
        '23456789';

    final random =
    Random.secure();

    return List.generate(
      32,
          (_) {
        return characters[
        random.nextInt(
          characters.length,
        )
        ];
      },
    ).join();
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  DateTime? _readDateTime(dynamic value,) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}