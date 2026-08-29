import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

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

  CollectionReference<Map<String, dynamic>> get _invitations {
    return _firestore.collection(_invitationCollectionName);
  }

  CollectionReference<Map<String, dynamic>> get _tenants {
    return _firestore.collection(_tenantCollectionName);
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
  //
  // OWNER ONLY
  //
  // Rules:
  // 1. Phone cannot be empty.
  // 2. Same tenant cannot have multiple pending invitations.
  // 3. Invitation is valid for 7 days.
  // ============================================================

  Future<TenantInvitationModel> createInvitation({
    required String ownerId,
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
  }) async {
    // ----------------------------------------------------------
    // VERIFY CURRENT USER
    // ----------------------------------------------------------

    final currentUserId = _currentUserId;

    if (currentUserId != ownerId) {
      throw StateError('You are not authorized to create this invitation.');
    }

    // ----------------------------------------------------------
    // NORMALIZE PHONE
    // ----------------------------------------------------------

    final normalizedPhone = phone.trim();

    if (normalizedPhone.isEmpty) {
      throw ArgumentError('Tenant phone number cannot be empty.');
    }

    // ----------------------------------------------------------
    // CHECK EXISTING PENDING INVITATION
    // ----------------------------------------------------------
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

      // --------------------------------------------------------
      // IF EXISTING INVITATION IS ALREADY EXPIRED,
      // DELETE IT AND ALLOW NEW INVITATION.
      // --------------------------------------------------------

      if (existingInvitation.isExpired) {
        await _deleteInvitationDocument(existingInvitation.id);
      } else {
        throw StateError(
          'A pending invitation already exists for this tenant.',
        );
      }
    }

    // ----------------------------------------------------------
    // CREATE DOCUMENT ID
    // ----------------------------------------------------------

    final documentId = _invitations.doc().id;

    // ----------------------------------------------------------
    // CREATE SECURE TOKEN
    // ----------------------------------------------------------

    final token = _generateToken();

    // ----------------------------------------------------------
    // DATES
    // ----------------------------------------------------------

    final now = DateTime.now();

    // ----------------------------------------------------------
    // INVITATION VALID FOR 7 DAYS
    // ----------------------------------------------------------

    final expiresAt = now.add(const Duration(days: 7));

    // ----------------------------------------------------------
    // MODEL
    // ----------------------------------------------------------

    final invitation = TenantInvitationModel(
      id: documentId,
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

    // ----------------------------------------------------------
    // SAVE
    // ----------------------------------------------------------

    await _invitations.doc(documentId).set(invitation.toFirestore());

    return invitation;
  }

  // ============================================================
  // GET INVITATION BY ID
  //
  // If expired:
  // delete it immediately and return null.
  // ============================================================

  Future<TenantInvitationModel?> getInvitationById(String invitationId) async {
    final document = await _invitations.doc(invitationId).get();

    if (!document.exists) {
      return null;
    }

    final invitation = TenantInvitationModel.fromFirestore(document);

    // ----------------------------------------------------------
    // EXPIRED
    // ----------------------------------------------------------

    if (invitation.isExpired &&
        invitation.status == TenantInvitationStatus.pending) {
      await _deleteInvitationDocument(invitation.id);

      return null;
    }

    return invitation;
  }

  // ============================================================
  // GET INVITATION BY TOKEN
  //
  // Used during tenant registration.
  //
  // Invalid / expired invitation:
  // return null.
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

    // ----------------------------------------------------------
    // ONLY PENDING INVITATIONS CAN BE USED
    // ----------------------------------------------------------

    if (invitation.status != TenantInvitationStatus.pending) {
      return null;
    }

    // ----------------------------------------------------------
    // EXPIRED
    // ----------------------------------------------------------

    if (invitation.isExpired) {
      await _deleteInvitationDocument(invitation.id);

      return null;
    }

    return invitation;
  }

  // ============================================================
  // GET PENDING INVITATION BY TENANT ID
  //
  // OWNER USE
  // ============================================================
  Future<TenantInvitationModel?> getPendingInvitationByTenantId(
    String tenantId,
  ) async {
    final currentUserId = _currentUserId;

    final snapshot = await _invitations
        .where('tenantId', isEqualTo: tenantId)
        .where('ownerId', isEqualTo: currentUserId)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final invitation = TenantInvitationModel.fromFirestore(snapshot.docs.first);

    if (invitation.isExpired) {
      await _deleteInvitationDocument(invitation.id);

      return null;
    }

    return invitation;
  }

  // ============================================================
  // GET PENDING INVITATION BY PHONE
  //
  // TENANT ACCOUNT LINKING
  //
  // Firebase Auth-এর phone number দিয়ে pending invitation খোঁজা হয়.
  //
  // Rules:
  // 1. Phone empty হলে null.
  // 2. শুধু pending invitation খোঁজা হবে.
  // 3. Expired হলে permanently delete হবে.
  // 4. Valid invitation return হবে.
  // ============================================================

  Future<TenantInvitationModel?> getPendingInvitationByPhone(
    String phone,
  ) async {
    final normalizedPhone = phone.trim();

    if (normalizedPhone.isEmpty) {
      return null;
    }

    final snapshot = await _invitations
        .where('phone', isEqualTo: normalizedPhone)
        .where('status', isEqualTo: TenantInvitationStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final invitation = TenantInvitationModel.fromFirestore(snapshot.docs.first);

    // ----------------------------------------------------------
    // EXPIRED
    // ----------------------------------------------------------

    if (invitation.isExpired) {
      await _deleteInvitationDocument(invitation.id);

      return null;
    }

    return invitation;
  }

  // ============================================================
  // ACCEPT INVITATION
  //
  // TENANT ONLY
  //
  // Current Firebase user must match the tenant's userId.
  //
  // IMPORTANT:
  // The invitation itself does not contain userId.
  // We therefore read the related tenant document.
  // ============================================================

  Future<void> acceptInvitation(String invitationId) async {
    final currentUserId = _currentUserId;

    final invitationDocument = _invitations.doc(invitationId);

    final invitationSnapshot = await invitationDocument.get();

    if (!invitationSnapshot.exists) {
      throw StateError('Invitation does not exist.');
    }

    final invitation = TenantInvitationModel.fromFirestore(invitationSnapshot);

    // ----------------------------------------------------------
    // INVITATION MUST BE PENDING
    // ----------------------------------------------------------

    if (invitation.status != TenantInvitationStatus.pending) {
      throw StateError('This invitation cannot be accepted.');
    }

    // ----------------------------------------------------------
    // EXPIRED
    // ----------------------------------------------------------

    if (invitation.isExpired) {
      await _deleteInvitationDocument(invitation.id);

      throw StateError('This invitation has expired.');
    }

    // ----------------------------------------------------------
    // READ TENANT
    // ----------------------------------------------------------

    final tenantDocument = _tenants.doc(invitation.tenantId);

    final tenantSnapshot = await tenantDocument.get();

    if (!tenantSnapshot.exists) {
      throw StateError('Tenant account record does not exist.');
    }

    final tenantData = tenantSnapshot.data();

    if (tenantData == null) {
      throw StateError('Tenant data is unavailable.');
    }

    // ----------------------------------------------------------
    // CHECK TENANT USER ID
    // ----------------------------------------------------------

    final tenantUserId = tenantData['userId'];

    // ----------------------------------------------------------
    // TENANT ACCOUNT MUST BE LINKED
    // ----------------------------------------------------------

    if (tenantUserId == null || tenantUserId.toString().trim().isEmpty) {
      throw StateError('Tenant account is not linked yet.');
    }

    // ----------------------------------------------------------
    // ONLY THE LINKED TENANT CAN ACCEPT
    // ----------------------------------------------------------

    if (tenantUserId != currentUserId) {
      throw StateError('You are not authorized to accept this invitation.');
    }

    // ----------------------------------------------------------
    // ACCEPT
    // ----------------------------------------------------------

    await invitationDocument.update({
      'status': TenantInvitationStatus.accepted.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // CANCEL INVITATION
  //
  // OWNER OR TENANT
  //
  // OWNER:
  // currentUser.uid == invitation.ownerId
  //
  // TENANT:
  // currentUser.uid == tenant.userId
  //
  // After cancellation:
  // invitation document is permanently deleted.
  // ============================================================

  Future<void> cancelInvitation(String invitationId) async {
    final currentUserId = _currentUserId;

    final invitationDocument = _invitations.doc(invitationId);

    final invitationSnapshot = await invitationDocument.get();

    if (!invitationSnapshot.exists) {
      return;
    }

    final invitation = TenantInvitationModel.fromFirestore(invitationSnapshot);

    // ----------------------------------------------------------
    // ONLY PENDING INVITATIONS CAN BE CANCELLED
    // ----------------------------------------------------------

    if (invitation.status != TenantInvitationStatus.pending) {
      return;
    }

    // ----------------------------------------------------------
    // OWNER CHECK
    // ----------------------------------------------------------

    final isOwner = invitation.ownerId == currentUserId;

    // ----------------------------------------------------------
    // TENANT CHECK
    // ----------------------------------------------------------

    bool isTenant = false;

    final tenantDocument = _tenants.doc(invitation.tenantId);

    final tenantSnapshot = await tenantDocument.get();

    if (tenantSnapshot.exists) {
      final tenantData = tenantSnapshot.data();

      final tenantUserId = tenantData?['userId'];

      isTenant = tenantUserId == currentUserId;
    }

    // ----------------------------------------------------------
    // AUTHORIZATION
    // ----------------------------------------------------------

    if (!isOwner && !isTenant) {
      throw StateError('You are not authorized to cancel this invitation.');
    }

    // ----------------------------------------------------------
    // DELETE INVITATION
    //
    // We do NOT keep "cancelled" invitation documents.
    // ==========================================================

    await _deleteInvitationDocument(invitation.id);
  }

  // ============================================================
  // EXPIRE INVITATION
  //
  // If still pending and expired:
  // permanently delete it.
  // ============================================================

  Future<void> expireInvitation(String invitationId) async {
    final currentUserId = _currentUserId;

    final document = _invitations.doc(invitationId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      return;
    }

    final invitation = TenantInvitationModel.fromFirestore(snapshot);

    // ----------------------------------------------------------
    // OWNER AUTHORIZATION
    // ----------------------------------------------------------

    if (invitation.ownerId != currentUserId) {
      throw StateError('You are not authorized to expire this invitation.');
    }

    // ----------------------------------------------------------
    // ONLY PENDING INVITATION
    // ----------------------------------------------------------

    if (invitation.status != TenantInvitationStatus.pending) {
      return;
    }

    // ----------------------------------------------------------
    // ONLY EXPIRED INVITATIONS
    // ----------------------------------------------------------

    if (!invitation.isExpired) {
      throw StateError('This invitation has not expired yet.');
    }

    // ----------------------------------------------------------
    // DELETE
    // ----------------------------------------------------------

    await _deleteInvitationDocument(invitation.id);
  }

  // ============================================================
  // DELETE INVITATION DOCUMENT
  //
  // This deletes ONLY the invitation.
  //
  // It does NOT delete:
  // - Firebase Auth account
  // - Tenant document
  // - Property
  // - Unit
  // ============================================================

  Future<void> _deleteInvitationDocument(String invitationId) async {
    await _invitations.doc(invitationId).delete();
  }

  // ============================================================
  // GENERATE SECURE TOKEN
  // ============================================================

  String _generateToken() {
    const characters =
        'ABCDEFGHJKLMNPQRSTUVWXYZ'
        'abcdefghijkmnopqrstuvwxyz'
        '23456789';

    final random = Random.secure();

    return List.generate(
      32,
      (_) => characters[random.nextInt(characters.length)],
    ).join();
  }
}
