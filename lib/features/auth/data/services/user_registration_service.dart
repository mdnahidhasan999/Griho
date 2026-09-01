import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';

import '../../../../core/utils/phone_number_utils.dart';

import '../../../tenants/data/datasources/tenant_invitation_data_source.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/registration_intent.dart';

import '../datasources/user_profile_datasource.dart';
import '../models/app_user_model.dart';

import 'griho_id_generator.dart';

// ================================================================
// USER REGISTRATION RESULT
// ================================================================

class UserRegistrationResult {
  final AppUser user;

  /// Pending invitation থাকলে তার ID।
  final String? invitationId;

  const UserRegistrationResult({
    required this.user,
    this.invitationId,
  });

  bool get hasPendingInvitation {
    return invitationId != null &&
        invitationId!.trim().isNotEmpty;
  }
}

// ================================================================
// USER REGISTRATION SERVICE
// ================================================================

class UserRegistrationService {
  final FirebaseAuth _firebaseAuth;

  final GrihoIdGenerator _grihoIdGenerator;

  final UserProfileDataSource _userProfileDataSource;

  final TenantInvitationDataSource _tenantInvitationDataSource;

  UserRegistrationService({
    FirebaseAuth? firebaseAuth,
    GrihoIdGenerator? grihoIdGenerator,
    UserProfileDataSource? userProfileDataSource,
    TenantInvitationDataSource? tenantInvitationDataSource,
  })
      : _firebaseAuth =
      firebaseAuth ?? FirebaseAuth.instance,
        _grihoIdGenerator =
            grihoIdGenerator ?? GrihoIdGenerator(),
        _userProfileDataSource =
            userProfileDataSource ??
                UserProfileDataSource(),
        _tenantInvitationDataSource =
            tenantInvitationDataSource ??
                TenantInvitationDataSource();

  // ============================================================
  // REGISTER
  // ============================================================

  Future<UserRegistrationResult> register({
    required RegistrationIntent intent,
    required String name,
  }) async {
    final firebaseUser =
        _firebaseAuth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
        'A Firebase authenticated user is required for registration.',
      );
    }

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError(
        'Name cannot be empty.',
      );
    }

    // ==========================================================
    // EXISTING USER
    // ==========================================================

    final existingUser =
    await _userProfileDataSource.getUserByUid(
      firebaseUser.uid,
    );

    if (existingUser != null) {
      return UserRegistrationResult(
        user: existingUser,
      );
    }

    // ==========================================================
    // TENANT
    // ==========================================================

    if (intent == RegistrationIntent.tenant) {
      return _registerTenant(
        firebaseUser: firebaseUser,
        name: normalizedName,
      );
    }

    // ==========================================================
    // OWNER
    // ==========================================================

    final user = await _registerOwner(
      firebaseUser: firebaseUser,
      name: normalizedName,
    );

    return UserRegistrationResult(
      user: user,
    );
  }

  // ============================================================
  // REGISTER OWNER
  // ============================================================

  Future<AppUser> _registerOwner({
    required User firebaseUser,
    required String name,
  }) async {
    final publicId =
    await _grihoIdGenerator.generateAndReserve();

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
      await _userProfileDataSource.createUser(
        AppUserModel.fromEntity(user),
      );

      return user;
    } catch (error) {
      await _grihoIdGenerator
          .releaseReservation(publicId);

      rethrow;
    }
  }

  // ============================================================
  // REGISTER TENANT
  // ============================================================

  Future<UserRegistrationResult> _registerTenant({
    required User firebaseUser,
    required String name,
  }) async {
    // ----------------------------------------------------------
    // FIREBASE PHONE
    // ----------------------------------------------------------

    final phone =
    firebaseUser.phoneNumber?.trim();

    if (phone == null || phone.isEmpty) {
      throw StateError(
        'A verified phone number is required for tenant registration.',
      );
    }

    if (!PhoneNumberUtils.isValid(phone)) {
      throw StateError(
        'Firebase returned an invalid phone number format.',
      );
    }

    // ----------------------------------------------------------
    // FIND PENDING INVITATION
    // ----------------------------------------------------------

    final invitation =
    await _tenantInvitationDataSource
        .getPendingInvitationByPhone(phone);

    // ----------------------------------------------------------
    // CREATE TENANT USER
    // ----------------------------------------------------------

    final user =
    await _registerTenantUser(
      firebaseUser: firebaseUser,
      name: name,
    );

    // ----------------------------------------------------------
    // NO INVITATION
    // ----------------------------------------------------------

    if (invitation == null) {
      debugPrint(
        'TENANT REGISTER: no pending invitation.',
      );

      return UserRegistrationResult(
        user: user,
      );
    }

    // ----------------------------------------------------------
    // INVITATION FOUND
    // ----------------------------------------------------------

    debugPrint(
      'TENANT REGISTER: pending invitation found.',
    );

    debugPrint(
      'TENANT REGISTER: invitationId = ${invitation.id}',
    );

    // ----------------------------------------------------------
    // IMPORTANT
    //
    // DO NOT ACCEPT INVITATION HERE.
    //
    // শুধু invitationId return হবে।
    //
    // TenantInvitationReceiveScreen
    // পরে Accept করবে।
    // ----------------------------------------------------------

    return UserRegistrationResult(
      user: user,
      invitationId: invitation.id,
    );
  }

  // ============================================================
  // REGISTER TENANT USER
  // ============================================================

  Future<AppUser> _registerTenantUser({
    required User firebaseUser,
    required String name,
  }) async {
    final publicId =
    await _grihoIdGenerator.generateAndReserve();

    final now = DateTime.now();

    final user = AppUser(
      uid: firebaseUser.uid,
      publicId: publicId,
      role: UserRole.tenant,
      name: name,
      phoneNumber: firebaseUser.phoneNumber,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _userProfileDataSource.createUser(
        AppUserModel.fromEntity(user),
      );

      return user;
    } catch (error) {
      await _grihoIdGenerator
          .releaseReservation(publicId);

      rethrow;
    }
  }
}