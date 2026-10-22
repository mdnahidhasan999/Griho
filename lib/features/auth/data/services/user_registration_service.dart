import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../tenants/data/datasources/tenant_invitation_data_source.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/registration_intent.dart';
import '../datasources/user_profile_datasource.dart';
import '../models/app_user_model.dart';
import 'griho_id_generator.dart';

class UserRegistrationResult {
  final AppUser user;
  final String? invitationId;

  const UserRegistrationResult({
    required this.user,
    this.invitationId,
  });

  bool get hasPendingInvitation {
    return invitationId != null && invitationId!.trim().isNotEmpty;
  }
}

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
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _grihoIdGenerator = grihoIdGenerator ?? GrihoIdGenerator(),
        _userProfileDataSource =
            userProfileDataSource ?? UserProfileDataSource(),
        _tenantInvitationDataSource =
            tenantInvitationDataSource ?? TenantInvitationDataSource();

  // Retrieves an existing Griho profile using the Firebase UID.
  Future<AppUserModel?> getUserProfileByFirebaseUid(String uid) async {
    final normalizedUid = uid.trim();

    if (normalizedUid.isEmpty) {
      return null;
    }

    return _userProfileDataSource.getUserByUid(normalizedUid);
  }

  // Creates a new Griho profile or completes an existing incomplete profile.
  Future<AppUser> createOrUpdateUserProfile({
    required User firebaseUser,
    required String name,
    required String phoneNumber,
  }) async {
    final currentFirebaseUser = _firebaseAuth.currentUser;

    if (currentFirebaseUser == null ||
        currentFirebaseUser.uid != firebaseUser.uid) {
      throw StateError(
        'The authenticated Firebase user does not match the requested profile.',
      );
    }

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Name cannot be empty.');
    }

    final normalizedPhone = PhoneNumberUtils.normalizeAndValidate(
      phoneNumber,
    );

    final existingUser = await _userProfileDataSource.getUserByUid(
      firebaseUser.uid,
    );

    if (existingUser != null) {
      final existingPhone = existingUser.phoneNumber?.trim() ?? '';

      if (existingPhone.isNotEmpty) {
        final normalizedExistingPhone =
        PhoneNumberUtils.normalizeAndValidate(existingPhone);

        if (normalizedExistingPhone != normalizedPhone) {
          throw StateError(
            'The phone number is already set and cannot be changed.',
          );
        }

        return existingUser;
      }

      await _ensurePhoneAvailable(
        phoneNumber: normalizedPhone,
        currentUid: firebaseUser.uid,
      );

      final updatedUser = AppUserModel(
        uid: existingUser.uid,
        publicId: existingUser.publicId,
        name: normalizedName,
        phoneNumber: normalizedPhone,
        email: firebaseUser.email ?? existingUser.email,
        photoUrl: firebaseUser.photoURL ?? existingUser.photoUrl,
        defaultDashboard: existingUser.defaultDashboard ?? 'home',
        isActive: existingUser.isActive,
        createdAt: existingUser.createdAt,
        updatedAt: DateTime.now(),
      );

      await _userProfileDataSource.updateUser(updatedUser);

      return updatedUser;
    }

    await _ensurePhoneAvailable(
      phoneNumber: normalizedPhone,
      currentUid: firebaseUser.uid,
    );

    final publicId = await _grihoIdGenerator.generateAndReserve();
    final now = DateTime.now();

    final newUser = AppUserModel(
      uid: firebaseUser.uid,
      publicId: publicId,
      name: normalizedName,
      phoneNumber: normalizedPhone,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
      defaultDashboard: 'home',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _userProfileDataSource.createUser(newUser);
      return newUser;
    } catch (error) {
      try {
        await _grihoIdGenerator.releaseReservation(publicId);
      } catch (_) {
        // Preserve the original profile creation error.
      }

      rethrow;
    }
  }

  // Checks whether a phone number is already associated with another user.
  Future<void> _ensurePhoneAvailable({
    required String phoneNumber,
    required String currentUid,
  }) async {
    final existingUser = await _userProfileDataSource.getUserByPhone(
      phoneNumber,
    );

    if (existingUser != null && existingUser.uid != currentUid) {
      throw StateError(
        'This phone number is already associated with another account.',
      );
    }
  }

  // Registers a user using the existing registration intent flow.
  Future<UserRegistrationResult> register({
    required RegistrationIntent intent,
    required String name,
    required String phoneNumber,
  }) async {
    final firebaseUser = _firebaseAuth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
        'An authenticated Firebase user is required for registration.',
      );
    }

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError('Name cannot be empty.');
    }

    final normalizedPhone = PhoneNumberUtils.normalizeAndValidate(
      phoneNumber,
    );

    final existingUser = await _userProfileDataSource.getUserByUid(
      firebaseUser.uid,
    );

    if (existingUser != null) {
      final existingPhone = existingUser.phoneNumber?.trim() ?? '';

      if (existingPhone.isNotEmpty &&
          existingPhone != normalizedPhone) {
        throw StateError(
          'The phone number is already set and cannot be changed.',
        );
      }

      if (existingPhone.isEmpty) {
        await _ensurePhoneAvailable(
          phoneNumber: normalizedPhone,
          currentUid: firebaseUser.uid,
        );

        final updatedUser = AppUserModel(
          uid: existingUser.uid,
          publicId: existingUser.publicId,
          name: normalizedName,
          phoneNumber: normalizedPhone,
          email: firebaseUser.email ?? existingUser.email,
          photoUrl: firebaseUser.photoURL ?? existingUser.photoUrl,
          defaultDashboard:
          existingUser.defaultDashboard ??
              (intent == RegistrationIntent.tenant ? 'tenant' : 'owner'),
          isActive: existingUser.isActive,
          createdAt: existingUser.createdAt,
          updatedAt: DateTime.now(),
        );

        await _userProfileDataSource.updateUser(updatedUser);

        return UserRegistrationResult(user: updatedUser);
      }

      return UserRegistrationResult(user: existingUser);
    }

    await _ensurePhoneAvailable(
      phoneNumber: normalizedPhone,
      currentUid: firebaseUser.uid,
    );

    if (intent == RegistrationIntent.tenant) {
      return _registerTenant(
        firebaseUser: firebaseUser,
        name: normalizedName,
        phoneNumber: normalizedPhone,
      );
    }

    final user = await _registerOwner(
      firebaseUser: firebaseUser,
      name: normalizedName,
      phoneNumber: normalizedPhone,
    );

    return UserRegistrationResult(user: user);
  }

  // Registers a property owner.
  Future<AppUser> _registerOwner({
    required User firebaseUser,
    required String name,
    required String phoneNumber,
  }) async {
    final publicId = await _grihoIdGenerator.generateAndReserve();
    final now = DateTime.now();

    final user = AppUserModel(
      uid: firebaseUser.uid,
      publicId: publicId,
      name: name,
      phoneNumber: phoneNumber,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
      defaultDashboard: 'owner',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _userProfileDataSource.createUser(user);
      return user;
    } catch (error) {
      try {
        await _grihoIdGenerator.releaseReservation(publicId);
      } catch (_) {
        // Preserve the original profile creation error.
      }

      rethrow;
    }
  }

  // Registers a tenant and checks for a pending invitation.
  Future<UserRegistrationResult> _registerTenant({
    required User firebaseUser,
    required String name,
    required String phoneNumber,
  }) async {
    final invitation = await _tenantInvitationDataSource
        .getPendingInvitationByPhone(phoneNumber);

    final user = await _registerTenantUser(
      firebaseUser: firebaseUser,
      name: name,
      phoneNumber: phoneNumber,
    );

    if (invitation == null) {
      return UserRegistrationResult(user: user);
    }

    return UserRegistrationResult(
      user: user,
      invitationId: invitation.id,
    );
  }

  // Creates the tenant profile document.
  Future<AppUser> _registerTenantUser({
    required User firebaseUser,
    required String name,
    required String phoneNumber,
  }) async {
    final publicId = await _grihoIdGenerator.generateAndReserve();
    final now = DateTime.now();

    final user = AppUserModel(
      uid: firebaseUser.uid,
      publicId: publicId,
      name: name,
      phoneNumber: phoneNumber,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
      defaultDashboard: 'tenant',
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _userProfileDataSource.createUser(user);
      return user;
    } catch (error) {
      try {
        await _grihoIdGenerator.releaseReservation(publicId);
      } catch (_) {
        // Preserve the original profile creation error.
      }

      rethrow;
    }
  }
}