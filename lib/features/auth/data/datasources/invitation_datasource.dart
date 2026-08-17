import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/invitation_model.dart';

class InvitationDataSource {
  final FirebaseFirestore _firestore;

  InvitationDataSource({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _invitationsCollection {
    return _firestore.collection('invitations');
  }

  Future<void> createInvitation(
      InvitationModel invitation,
      ) async {
    await _invitationsCollection
        .doc(invitation.id)
        .set(invitation.toFirestore());
  }

  Future<InvitationModel?> getInvitationById(
      String invitationId,
      ) async {
    final document = await _invitationsCollection
        .doc(invitationId)
        .get();

    if (!document.exists) {
      return null;
    }

    return InvitationModel.fromFirestore(document);
  }

  Future<InvitationModel?> getPendingInvitationByCode(
      String invitationCode,
      ) async {
    final query = await _invitationsCollection
        .where(
      'invitationCode',
      isEqualTo: invitationCode,
    )
        .where(
      'status',
      isEqualTo: 'pending',
    )
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    return InvitationModel.fromFirestore(
      query.docs.first,
    );
  }

  Future<List<InvitationModel>> getPendingInvitationsForUser({
    required String userId,
    required String phoneNumber,
  }) async {
    final results = <InvitationModel>[];

    final userQuery = await _invitationsCollection
        .where(
      'targetUserId',
      isEqualTo: userId,
    )
        .where(
      'status',
      isEqualTo: 'pending',
    )
        .get();

    results.addAll(
      userQuery.docs.map(
        InvitationModel.fromFirestore,
      ),
    );

    final phoneQuery = await _invitationsCollection
        .where(
      'targetPhoneNumber',
      isEqualTo: phoneNumber,
    )
        .where(
      'status',
      isEqualTo: 'pending',
    )
        .get();

    final existingIds = results.map((item) => item.id).toSet();

    for (final document in phoneQuery.docs) {
      if (!existingIds.contains(document.id)) {
        results.add(
          InvitationModel.fromFirestore(document),
        );
      }
    }

    return results;
  }

  Future<void> updateInvitation(
      InvitationModel invitation,
      ) async {
    await _invitationsCollection
        .doc(invitation.id)
        .update(invitation.toFirestore());
  }
}