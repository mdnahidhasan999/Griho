import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/utils/phone_number_utils.dart';

import '../../../tenants/data/datasources/tenant_invitation_data_source.dart';

import '../../../tenants/domain/usecases/link_and_accept_tenant_invitation.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/registration_intent.dart';

import '../datasources/user_profile_datasource.dart';
import '../models/app_user_model.dart';

import 'griho_id_generator.dart';

// ================================================================
// REGISTRATION RESULT
// ================================================================

class UserRegistrationResult {
  final AppUser user;

  /// Pending invitation ID.
  ///
  /// If null, no invitation was found.
  final String? invitationId;

  const UserRegistrationResult({required this.user, this.invitationId});
}

// ================================================================
// USER REGISTRATION SERVICE
// ================================================================

class UserRegistrationService {
  final FirebaseAuth _firebaseAuth;

  final GrihoIdGenerator _grihoIdGenerator;

  final UserProfileDataSource _userProfileDataSource;

  final TenantInvitationDataSource _tenantInvitationDataSource;

  // Kept here for compatibility with the existing dependency setup.
  // IMPORTANT:
  // This service does NOT automatically accept invitations anymore.

  UserRegistrationService({
    FirebaseAuth? firebaseAuth,
    GrihoIdGenerator? grihoIdGenerator,
    UserProfileDataSource? userProfileDataSource,
    TenantInvitationDataSource? tenantInvitationDataSource,
    LinkAndAcceptTenantInvitation? linkAndAcceptTenantInvitation,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,

       _grihoIdGenerator = grihoIdGenerator ?? GrihoIdGenerator(),

       _userProfileDataSource =
           userProfileDataSource ?? UserProfileDataSource(),

       _tenantInvitationDataSource =
           tenantInvitationDataSource ?? TenantInvitationDataSource();

  // ==============================================================
  // REGISTER
  // ==============================================================

  Future<UserRegistrationResult> register({
    required RegistrationIntent intent,
    required String name,
  }) async {
    final firebaseUser = _firebaseAuth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
        'A Firebase authenticated user is '
        'required for registration.',
      );
    }

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Name cannot be empty.');
    }

    // ------------------------------------------------------------
    // EXISTING USER
    // ------------------------------------------------------------

    final existingUser = await _userProfileDataSource.getUserByUid(
      firebaseUser.uid,
    );

    if (existingUser != null) {
      return UserRegistrationResult(user: existingUser);
    }

    // ==========================================================
    // TENANT
    // ==========================================================

    if (intent == RegistrationIntent.tenant) {
      return _registerTenant(firebaseUser: firebaseUser, name: normalizedName);
    }

    // ==========================================================
    // OWNER
    // ==========================================================

    final owner = await _registerOwner(
      firebaseUser: firebaseUser,
      name: normalizedName,
    );

    return UserRegistrationResult(user: owner);
  }

  // ==============================================================
  // REGISTER OWNER
  // ==============================================================

  Future<AppUser> _registerOwner({
    required User firebaseUser,
    required String name,
  }) async {
    final publicId = await _grihoIdGenerator.generateAndReserve();

    final now = DateTime.now();

    final user = AppUser(
      uid: firebaseUser.uid,

      publicId: publicId,

      role: UserRole.owner,

      name: name,

      phoneNumber: firebaseUser.phoneNumber,

      email: firebaseUser.email,

      photoUrl: firebaseUser.photoURL,

      isActive: true,

      createdAt: now,

      updatedAt: now,
    );

    try {
      await _userProfileDataSource.createUser(AppUserModel.fromEntity(user));

      return user;
    } catch (error) {
      await _grihoIdGenerator.releaseReservation(publicId);

      rethrow;
    }
  }

  // ==============================================================
  // REGISTER TENANT
  // ==============================================================

  Future<UserRegistrationResult> _registerTenant({
    required User firebaseUser,
    required String name,
  }) async {
    final phone = firebaseUser.phoneNumber?.trim();

    if (phone == null || phone.isEmpty) {
      throw StateError(
        'A verified phone number is '
        'required for tenant registration.',
      );
    }

    if (!PhoneNumberUtils.isValid(phone)) {
      throw StateError(
        'Firebase returned an invalid '
        'phone number format.',
      );
    }

    // ==========================================================
    // FIND PENDING INVITATION
    // ==========================================================

    final invitation = await _tenantInvitationDataSource
        .getPendingInvitationByPhone(phone);

    if (invitation != null) {
      debugPrint(
        'TENANT REGISTRATION: '
        'pending invitation found: '
        '${invitation.id}',
      );
    } else {
      debugPrint(
        'TENANT REGISTRATION: '
        'no pending invitation found.',
      );
    }

    // ==========================================================
    // CREATE TENANT USER
    // ==========================================================

    final publicId = await _grihoIdGenerator.generateAndReserve();

    final now = DateTime.now();

    final user = AppUser(
      uid: firebaseUser.uid,

      publicId: publicId,

      role: UserRole.tenant,

      name: name,

      phoneNumber: phone,

      email: firebaseUser.email,

      photoUrl: firebaseUser.photoURL,

      isActive: true,

      createdAt: now,

      updatedAt: now,
    );

    try {
      // --------------------------------------------------------
      // CREATE APP USER
      // --------------------------------------------------------

      await _userProfileDataSource.createUser(AppUserModel.fromEntity(user));

      // --------------------------------------------------------
      // IMPORTANT
      // --------------------------------------------------------
      //
      // DO NOT:
      //
      // link tenant
      // accept invitation
      //
      // here.
      //
      // The invitation will be shown to the tenant first.
      //
      // Tenant will explicitly press:
      //
      //       Accept Invitation
      //
      // --------------------------------------------------------

      return UserRegistrationResult(user: user, invitationId: invitation?.id);
    } catch (error) {
      await _grihoIdGenerator.releaseReservation(publicId);

      rethrow;
    }
  }
}
