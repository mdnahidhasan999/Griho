import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/tenant_invitation.dart';
import '../models/tenant_invitation_model.dart';

class TenantInvitationDataSource {
  final FirebaseFirestore _firestore;

  TenantInvitationDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore =
      firestore ?? FirebaseFirestore.instance;

  // ============================================================
  // COLLECTION
  // ============================================================

  static const String _collectionName =
      'tenantInvitations';

  CollectionReference<Map<String, dynamic>>
  get _invitations {
    return _firestore.collection(
      _collectionName,
    );
  }

  // ============================================================
  // CREATE INVITATION
  // ============================================================

  Future<TenantInvitationModel> createInvitation({
    required String ownerId,
    required String tenantId,
    required String propertyId,
    required String unitId,
    required String phone,
  }) async {
    final normalizedPhone = phone.trim();

    if (normalizedPhone.isEmpty) {
      throw ArgumentError(
        'Tenant phone number cannot be empty.',
      );
    }

    // ----------------------------------------------------------
    // CHECK EXISTING PENDING INVITATION
    // ----------------------------------------------------------

    final existingSnapshot = await _invitations
        .where(
      'tenantId',
      isEqualTo: tenantId,
    )
        .where(
      'status',
      isEqualTo:
      TenantInvitationStatus.pending.name,
    )
        .limit(1)
        .get();

    if (existingSnapshot.docs.isNotEmpty) {
      throw StateError(
        'A pending invitation already exists for this tenant.',
      );
    }

    // ----------------------------------------------------------
    // CREATE ID
    // ----------------------------------------------------------

    final documentId = _invitations.doc().id;

    // ----------------------------------------------------------
    // CREATE TOKEN
    // ----------------------------------------------------------

    final token = _generateToken();

    // ----------------------------------------------------------
    // DATES
    // ----------------------------------------------------------

    final now = DateTime.now();

    final expiresAt = now.add(
      const Duration(days: 7),
    );

    // ----------------------------------------------------------
    // CREATE MODEL
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

    await _invitations
        .doc(documentId)
        .set(
      invitation.toFirestore(),
    );

    return invitation;
  }

  // ============================================================
  // GET INVITATION BY ID
  // ============================================================

  Future<TenantInvitationModel?> getInvitationById(
      String invitationId,
      ) async {
    final document = await _invitations
        .doc(invitationId)
        .get();

    if (!document.exists) {
      return null;
    }

    return TenantInvitationModel.fromFirestore(
      document,
    );
  }

  // ============================================================
  // GET INVITATION BY TOKEN
  //
  // Used during tenant registration.
  // ============================================================

  Future<TenantInvitationModel?> getInvitationByToken(
      String token,
      ) async {
    final normalizedToken = token.trim();

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

    // ----------------------------------------------------------
    // EXPIRED
    // ----------------------------------------------------------

    if (invitation.status ==
        TenantInvitationStatus.pending &&
        invitation.isExpired) {
      await _invitations
          .doc(invitation.id)
          .update({
        'status':
        TenantInvitationStatus.expired.name,
        'updatedAt':
        FieldValue.serverTimestamp(),
      });

      return TenantInvitationModel(
        id: invitation.id,
        ownerId: invitation.ownerId,
        tenantId: invitation.tenantId,
        phone: invitation.phone,
        propertyId: invitation.propertyId,
        unitId: invitation.unitId,
        status: TenantInvitationStatus.expired,
        token: invitation.token,
        createdAt: invitation.createdAt,
        updatedAt: DateTime.now(),
        expiresAt: invitation.expiresAt,
      );
    }

    return invitation;
  }

  // ============================================================
  // GET PENDING INVITATION BY TENANT ID
  // ============================================================

  Future<TenantInvitationModel?>
  getPendingInvitationByTenantId(
      String tenantId,
      ) async {
    final snapshot = await _invitations
        .where(
      'tenantId',
      isEqualTo: tenantId,
    )
        .where(
      'status',
      isEqualTo:
      TenantInvitationStatus.pending.name,
    )
        .orderBy(
      'createdAt',
      descending: true,
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

    // ----------------------------------------------------------
    // CHECK EXPIRATION
    // ----------------------------------------------------------

    if (invitation.isExpired) {
      await _invitations
          .doc(invitation.id)
          .update({
        'status':
        TenantInvitationStatus.expired.name,
        'updatedAt':
        FieldValue.serverTimestamp(),
      });

      return TenantInvitationModel(
        id: invitation.id,
        ownerId: invitation.ownerId,
        tenantId: invitation.tenantId,
        phone: invitation.phone,
        propertyId: invitation.propertyId,
        unitId: invitation.unitId,
        status: TenantInvitationStatus.expired,
        token: invitation.token,
        createdAt: invitation.createdAt,
        updatedAt: DateTime.now(),
        expiresAt: invitation.expiresAt,
      );
    }

    return invitation;
  }

  // ============================================================
  // ACCEPT INVITATION
  // ============================================================

  Future<void> acceptInvitation(
      String invitationId,
      ) async {
    final document =
    _invitations.doc(invitationId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      throw StateError(
        'Invitation does not exist.',
      );
    }

    final invitation =
    TenantInvitationModel.fromFirestore(
      snapshot,
    );

    // ----------------------------------------------------------
    // ALREADY ACCEPTED
    // ----------------------------------------------------------

    if (invitation.status ==
        TenantInvitationStatus.accepted) {
      return;
    }

    // ----------------------------------------------------------
    // EXPIRED
    // ----------------------------------------------------------

    if (invitation.isExpired) {
      await document.update({
        'status':
        TenantInvitationStatus.expired.name,
        'updatedAt':
        FieldValue.serverTimestamp(),
      });

      throw StateError(
        'This invitation has expired.',
      );
    }

    // ----------------------------------------------------------
    // ONLY PENDING CAN BE ACCEPTED
    // ----------------------------------------------------------

    if (invitation.status !=
        TenantInvitationStatus.pending) {
      throw StateError(
        'This invitation cannot be accepted.',
      );
    }

    await document.update({
      'status':
      TenantInvitationStatus.accepted.name,
      'updatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // CANCEL INVITATION
  // ============================================================

  Future<void> cancelInvitation(
      String invitationId,
      ) async {
    final document =
    _invitations.doc(invitationId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      return;
    }

    final invitation =
    TenantInvitationModel.fromFirestore(
      snapshot,
    );

    if (invitation.status !=
        TenantInvitationStatus.pending) {
      return;
    }

    await document.update({
      'status':
      TenantInvitationStatus.cancelled.name,
      'updatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // EXPIRE INVITATION
  // ============================================================

  Future<void> expireInvitation(
      String invitationId,
      ) async {
    final document =
    _invitations.doc(invitationId);

    final snapshot = await document.get();

    if (!snapshot.exists) {
      return;
    }

    final invitation =
    TenantInvitationModel.fromFirestore(
      snapshot,
    );

    if (invitation.status !=
        TenantInvitationStatus.pending) {
      return;
    }

    await document.update({
      'status':
      TenantInvitationStatus.expired.name,
      'updatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // GENERATE TOKEN
  // ============================================================

  String _generateToken() {
    const characters =
        'ABCDEFGHJKLMNPQRSTUVWXYZ'
        'abcdefghijkmnopqrstuvwxyz'
        '23456789';

    final random = Random.secure();

    return List.generate(
      32,
          (_) => characters[
      random.nextInt(
        characters.length,
      )],
    ).join();
  }
}