import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../units/domain/entities/unit.dart';
import '../../domain/entities/tenant.dart';
import '../../domain/entities/tenant_invitation.dart';
import '../models/tenant_invitation_model.dart';

class TenantInvitationDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  TenantInvitationDataSource({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // ============================================================
  // COLLECTIONS
  // ============================================================

  static const String _invitationCollectionName = 'tenantInvitations';

  static const String _tenantCollectionName = 'tenants';

  static const String _propertyCollectionName = 'properties';

  static const String _unitCollectionName = 'units';

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
  }) async {
    final currentUserId = _currentUserId;

    if (currentUserId != ownerId) {
      throw StateError('You are not authorized to create this invitation.');
    }

    final normalizedPhone = _normalizePhone(phone);

    final tenantReference = _tenants.doc(tenantId);

    final tenantSnapshot = await tenantReference.get();

    if (!tenantSnapshot.exists) {
      throw StateError('Tenant record does not exist.');
    }

    final tenantData = tenantSnapshot.data();

    if (tenantData == null) {
      throw StateError('Tenant data is unavailable.');
    }

    if (tenantData['ownerId'] != currentUserId) {
      throw StateError('You are not authorized to invite this tenant.');
    }

    if (tenantData['propertyId'] != propertyId) {
      throw StateError('Tenant property does not match the invitation.');
    }

    if (tenantData['unitId'] != unitId) {
      throw StateError('Tenant unit does not match the invitation.');
    }

    final tenantPhone = tenantData['phone']?.toString().trim();

    if (tenantPhone == null || tenantPhone.isEmpty) {
      throw StateError('Tenant phone number is not available.');
    }

    final normalizedTenantPhone = _normalizePhone(tenantPhone);

    if (normalizedTenantPhone != normalizedPhone) {
      throw StateError(
        'Invitation phone number does not match the tenant phone number.',
      );
    }

    final existingSnapshot = await _invitations
        .where('tenantId', isEqualTo: tenantId)
        .where('ownerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .limit(1)
        .get();

    if (existingSnapshot.docs.isNotEmpty) {
      final existingInvitation = TenantInvitationModel.fromFirestore(
        existingSnapshot.docs.first,
      );

      if (existingInvitation.isExpired) {
        await _deleteInvitationDocument(existingInvitation.id);
      } else {
        throw StateError(
          'A pending invitation already exists for this tenant.',
        );
      }
    }

    final documentReference = _invitations.doc();

    final invitationId = documentReference.id;

    final token = _generateToken();

    final now = DateTime.now();

    final expiresAt = now.add(const Duration(days: 7));

    final invitation = TenantInvitationModel(
      id: invitationId,
      ownerId: ownerId,
      tenantId: tenantId,
      phone: normalizedPhone,
      propertyId: propertyId,
      unitId: unitId,
      status: TenantInvitationStatus.pending,
      token: token,
      createdAt: now,
      updatedAt: now,
      expiresAt: expiresAt,
    );

    await documentReference.set(invitation.toFirestore());

    return invitation;
  }

  // ============================================================
  // GET INVITATION BY ID
  // ============================================================

  Future<TenantInvitationModel?> getInvitationById(String invitationId) async {
    final normalizedId = invitationId.trim();

    if (normalizedId.isEmpty) {
      return null;
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

  // ============================================================
  // GET INVITATION BY TOKEN
  // ============================================================

  Future<TenantInvitationModel?> getInvitationByToken(String token) async {
    final normalizedToken = token.trim();

    if (normalizedToken.isEmpty) {
      return null;
    }

    final snapshot = await _invitations
        .where('token', isEqualTo: normalizedToken)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final invitation = TenantInvitationModel.fromFirestore(snapshot.docs.first);

    if (invitation.status != TenantInvitationStatus.pending) {
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

  Future<TenantInvitationModel?> getPendingInvitationByTenantId(
    String tenantId,
  ) async {
    final currentUserId = _currentUserId;

    final normalizedTenantId = tenantId.trim();

    if (normalizedTenantId.isEmpty) {
      return null;
    }

    final snapshot = await _invitations
        .where('tenantId', isEqualTo: normalizedTenantId)
        .where('ownerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final invitation = TenantInvitationModel.fromFirestore(snapshot.docs.first);

    if (invitation.isExpired) {
      return null;
    }

    return invitation;
  }

  // ============================================================
  // GET PENDING INVITATION BY PHONE
  // ============================================================

  Future<TenantInvitationModel?> getPendingInvitationByPhone(
    String phone,
  ) async {
    final normalizedPhone = _normalizePhone(phone);

    final snapshot = await _invitations
        .where('phone', isEqualTo: normalizedPhone)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final invitation = TenantInvitationModel.fromFirestore(snapshot.docs.first);

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
  // 2. Tenant confirmation
  // 3. Invitation acceptance
  // 4. Unit tenant access
  // 5. Property tenant access
  //
  // All are completed inside one transaction.
  // ============================================================
  Future<void> acceptInvitation(String invitationId) async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      throw StateError(
        'You must be signed in before accepting this invitation.',
      );
    }

    final currentUserId = currentUser.uid.trim();

    if (currentUserId.isEmpty) {
      throw StateError('Your Firebase user ID is unavailable.');
    }

    // ----------------------------------------------------------
    // FIREBASE PHONE
    // ----------------------------------------------------------

    final firebasePhone = currentUser.phoneNumber?.trim();

    if (firebasePhone == null || firebasePhone.isEmpty) {
      throw StateError('Your Firebase phone number is not available.');
    }

    final normalizedFirebasePhone = _normalizePhone(firebasePhone);

    // ----------------------------------------------------------
    // INVITATION ID
    // ----------------------------------------------------------

    final normalizedInvitationId = invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      throw ArgumentError('Invitation ID cannot be empty.');
    }

    final invitationReference = _invitations.doc(normalizedInvitationId);

    // ----------------------------------------------------------
    // INITIAL INVITATION READ
    // ----------------------------------------------------------

    final invitationSnapshot = await invitationReference.get();

    if (!invitationSnapshot.exists) {
      throw StateError('Invitation does not exist.');
    }

    final invitation = TenantInvitationModel.fromFirestore(invitationSnapshot);

    if (invitation.status != TenantInvitationStatus.pending) {
      throw StateError('This invitation has already been used.');
    }

    if (invitation.isExpired) {
      throw StateError('This invitation has expired.');
    }

    // ----------------------------------------------------------
    // INVITATION PHONE MATCH
    // ----------------------------------------------------------

    final invitationPhone = _normalizePhone(invitation.phone);

    if (normalizedFirebasePhone != invitationPhone) {
      throw StateError('This invitation belongs to a different phone number.');
    }

    // ----------------------------------------------------------
    // INITIAL TENANT READ
    // ----------------------------------------------------------

    final tenantReference = _tenants.doc(invitation.tenantId);

    final tenantSnapshot = await tenantReference.get();

    if (!tenantSnapshot.exists) {
      throw StateError('Tenant record does not exist.');
    }

    final tenantData = tenantSnapshot.data();

    if (tenantData == null) {
      throw StateError('Tenant data is unavailable.');
    }

    if (tenantData['ownerId'] != invitation.ownerId) {
      throw StateError('Tenant owner does not match this invitation.');
    }

    if (tenantData['propertyId'] != invitation.propertyId) {
      throw StateError('Tenant property does not match the invitation.');
    }

    if (tenantData['unitId'] != invitation.unitId) {
      throw StateError('Tenant unit does not match the invitation.');
    }

    // ----------------------------------------------------------
    // TENANT PHONE MATCH
    // ----------------------------------------------------------

    final tenantPhone = tenantData['phone']?.toString().trim();

    if (tenantPhone == null || tenantPhone.isEmpty) {
      throw StateError('Tenant phone number is not available.');
    }

    final normalizedTenantPhone = _normalizePhone(tenantPhone);

    if (normalizedTenantPhone != normalizedFirebasePhone) {
      throw StateError('Your phone number does not match the tenant record.');
    }

    // ----------------------------------------------------------
    // EXISTING TENANT ACCOUNT LINK
    // ----------------------------------------------------------

    final existingUserId = tenantData['userId'];

    if (existingUserId != null &&
        existingUserId.toString().trim().isNotEmpty &&
        existingUserId != currentUserId) {
      throw StateError(
        'This tenant account is already linked to another user.',
      );
    }

    // ----------------------------------------------------------
    // REFERENCES
    // ----------------------------------------------------------

    final propertyReference = _properties.doc(invitation.propertyId);

    final unitReference = _units.doc(invitation.unitId);

    // ----------------------------------------------------------
    // TENANT ACCESS
    //
    // Document ID = Firebase Auth UID
    // ----------------------------------------------------------

    final tenantAccessReference = _firestore
        .collection('tenantAccess')
        .doc(currentUserId);

    // ==========================================================
    // ATOMIC TRANSACTION
    // ==========================================================

    await _firestore.runTransaction((transaction) async {
      // --------------------------------------------------------
      // FRESH READS
      // --------------------------------------------------------

      final freshInvitation = await transaction.get(invitationReference);

      final freshTenant = await transaction.get(tenantReference);

      final freshProperty = await transaction.get(propertyReference);

      final freshUnit = await transaction.get(unitReference);

      final freshTenantAccess = await transaction.get(tenantAccessReference);

      // --------------------------------------------------------
      // EXISTENCE
      // --------------------------------------------------------

      if (!freshInvitation.exists) {
        throw StateError('Invitation no longer exists.');
      }

      if (!freshTenant.exists) {
        throw StateError('Tenant record no longer exists.');
      }

      if (!freshProperty.exists) {
        throw StateError('Property record no longer exists.');
      }

      if (!freshUnit.exists) {
        throw StateError('Unit record no longer exists.');
      }

      // --------------------------------------------------------
      // DATA
      // --------------------------------------------------------

      final freshInvitationData = freshInvitation.data();

      final freshTenantData = freshTenant.data();

      final freshPropertyData = freshProperty.data();

      final freshUnitData = freshUnit.data();

      if (freshInvitationData == null ||
          freshTenantData == null ||
          freshPropertyData == null ||
          freshUnitData == null) {
        throw StateError(
          'Invitation, tenant, property, or unit data is unavailable.',
        );
      }

      // --------------------------------------------------------
      // INVITATION STATUS
      // --------------------------------------------------------

      if (freshInvitationData['status'] !=
          TenantInvitationStatus.pending.name) {
        throw StateError('This invitation has already been used.');
      }

      // --------------------------------------------------------
      // INVITATION EXPIRY
      // --------------------------------------------------------

      final expiresAt = _readDateTime(freshInvitationData['expiresAt']);

      if (expiresAt == null) {
        throw StateError('Invitation expiry date is invalid.');
      }

      if (!expiresAt.isAfter(DateTime.now())) {
        throw StateError('This invitation has expired.');
      }

      // --------------------------------------------------------
      // INVITATION PHONE
      // --------------------------------------------------------

      final freshInvitationPhone = _normalizePhone(
        freshInvitationData['phone']?.toString() ?? '',
      );

      if (freshInvitationPhone != normalizedFirebasePhone) {
        throw StateError(
          'This invitation belongs to a different phone number.',
        );
      }

      // --------------------------------------------------------
      // TENANT RELATIONSHIP
      // --------------------------------------------------------

      if (freshTenantData['ownerId'] != freshInvitationData['ownerId']) {
        throw StateError('Tenant owner does not match this invitation.');
      }

      if (freshTenantData['propertyId'] != freshInvitationData['propertyId']) {
        throw StateError('Tenant property does not match this invitation.');
      }

      if (freshTenantData['unitId'] != freshInvitationData['unitId']) {
        throw StateError('Tenant unit does not match this invitation.');
      }

      // --------------------------------------------------------
      // TENANT PHONE
      // --------------------------------------------------------

      final freshTenantPhone = _normalizePhone(
        freshTenantData['phone']?.toString() ?? '',
      );

      if (freshTenantPhone != normalizedFirebasePhone) {
        throw StateError('Your phone number does not match the tenant record.');
      }

      // --------------------------------------------------------
      // PROPERTY OWNER
      // --------------------------------------------------------

      if (freshPropertyData['ownerId'] != freshTenantData['ownerId']) {
        throw StateError('Property owner does not match the tenant owner.');
      }

      // --------------------------------------------------------
      // UNIT PROPERTY
      // --------------------------------------------------------

      if (freshUnitData['propertyId'] != freshTenantData['propertyId']) {
        throw StateError('Unit does not belong to the tenant property.');
      }

      // --------------------------------------------------------
      // EXISTING TENANT LINK
      // --------------------------------------------------------

      final linkedUserId = freshTenantData['userId'];

      if (linkedUserId != null &&
          linkedUserId.toString().trim().isNotEmpty &&
          linkedUserId != currentUserId) {
        throw StateError(
          'This tenant account is already linked to another user.',
        );
      }

      // --------------------------------------------------------
      // EXISTING UNIT LINK
      // --------------------------------------------------------

      final unitTenantUserId = freshUnitData['tenantUserId'];

      if (unitTenantUserId != null &&
          unitTenantUserId.toString().trim().isNotEmpty &&
          unitTenantUserId != currentUserId) {
        throw StateError(
          'This unit is already linked to another tenant account.',
        );
      }

      // --------------------------------------------------------
      // EXISTING TENANT ACCESS
      // --------------------------------------------------------

      Map<String, dynamic>? existingTenantAccessData;

      if (freshTenantAccess.exists) {
        final data = freshTenantAccess.data();

        if (data == null) {
          throw StateError('Tenant access data is unavailable.');
        }

        existingTenantAccessData = data;

        if (data['tenantId'] != freshInvitationData['tenantId']) {
          throw StateError('This user already has a different tenant access.');
        }

        if (data['propertyId'] != freshTenantData['propertyId']) {
          throw StateError('This user already has access to another property.');
        }

        if (data['unitId'] != freshTenantData['unitId']) {
          throw StateError('This user already has access to another unit.');
        }
      }
      // ========================================================
      // TENANT ACCOUNT LINK
      // ========================================================

      transaction.update(tenantReference, {
        'userId': currentUserId,
        'accountStatus': TenantAccountStatus.registered.name,
        'confirmationStatus': TenantConfirmationStatus.confirmed.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ========================================================
      // TENANT ACCESS
      // ========================================================

      final now = Timestamp.now();

      final existingCreatedAt = existingTenantAccessData?['createdAt'];

      transaction.set(tenantAccessReference, {
        'userId': currentUserId,
        'tenantId': invitation.tenantId,
        'ownerId': invitation.ownerId,
        'propertyId': invitation.propertyId,
        'unitId': invitation.unitId,
        'invitationId': invitationId,
        'createdAt': existingCreatedAt is Timestamp ? existingCreatedAt : now,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ========================================================
      // ACTIVE TENANT
      // ========================================================

      if (freshTenantData['status'] == TenantStatus.active.name) {
        transaction.update(unitReference, {
          'tenantUserId': currentUserId,
          'status': UnitStatus.occupied.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(propertyReference, {
          'tenantUserIds': FieldValue.arrayUnion([currentUserId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // ========================================================
      // ACCEPT INVITATION
      // ========================================================

      transaction.update(invitationReference, {
        'status': TenantInvitationStatus.accepted.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  // ============================================================
  // CANCEL INVITATION
  // OWNER ONLY
  // ============================================================

  Future<void> cancelInvitation(String invitationId) async {
    final currentUserId = _currentUserId;

    final normalizedInvitationId = invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      return;
    }

    final document = _invitations.doc(normalizedInvitationId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      return;
    }

    final invitation = TenantInvitationModel.fromFirestore(snapshot);

    if (invitation.ownerId != currentUserId) {
      throw StateError('You are not authorized to cancel this invitation.');
    }

    if (invitation.status != TenantInvitationStatus.pending) {
      return;
    }

    await _deleteInvitationDocument(invitation.id);
  }

  // ============================================================
  // EXPIRE INVITATION
  // OWNER ONLY
  // ============================================================

  Future<void> expireInvitation(String invitationId) async {
    final currentUserId = _currentUserId;

    final normalizedInvitationId = invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      return;
    }

    final document = _invitations.doc(normalizedInvitationId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      return;
    }

    final invitation = TenantInvitationModel.fromFirestore(snapshot);

    if (invitation.ownerId != currentUserId) {
      throw StateError('You are not authorized to expire this invitation.');
    }

    if (invitation.status != TenantInvitationStatus.pending) {
      return;
    }

    if (!invitation.isExpired) {
      throw StateError('This invitation has not expired yet.');
    }

    await _deleteInvitationDocument(invitation.id);
  }

  // ============================================================
  // DELETE INVITATION DOCUMENT
  // ============================================================

  Future<void> _deleteInvitationDocument(String invitationId) async {
    await _invitations.doc(invitationId).delete();
  }

  // ============================================================
  // TOKEN
  // ============================================================

  String _generateToken() {
    const characters =
        'ABCDEFGHJKLMNPQRSTUVWXYZ'
        'abcdefghijkmnopqrstuvwxyz'
        '23456789';

    final random = Random.secure();

    return List.generate(32, (_) {
      return characters[random.nextInt(characters.length)];
    }).join();
  }

  // ============================================================
  // DATE PARSER
  // ============================================================

  DateTime? _readDateTime(dynamic value) {
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
