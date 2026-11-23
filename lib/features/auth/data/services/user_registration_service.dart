import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/utils/phone_number_utils.dart';
import '../../../tenants/data/datasources/tenant_invitation_data_source.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/registration_intent.dart';
import '../datasources/phone_lookup_data_source.dart';
import '../datasources/user_profile_datasource.dart';
import '../models/app_user_model.dart';
import 'griho_id_generator.dart';

class UserRegistrationResult {
  final AppUser user;
  final String? invitationId;

  const UserRegistrationResult({required this.user, this.invitationId});

  bool get hasPendingInvitation {
    return invitationId != null && invitationId!.trim().isNotEmpty;
  }
}

class UserRegistrationService {
  final FirebaseAuth _firebaseAuth;
  final GrihoIdGenerator _grihoIdGenerator;
  final UserProfileDataSource _userProfileDataSource;
  final PhoneLookupDataSource _phoneLookupDataSource;
  final TenantInvitationDataSource _tenantInvitationDataSource;

  UserRegistrationService({
    FirebaseAuth? firebaseAuth,
    GrihoIdGenerator? grihoIdGenerator,
    UserProfileDataSource? userProfileDataSource,
    PhoneLookupDataSource? phoneLookupDataSource,
    TenantInvitationDataSource? tenantInvitationDataSource,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _grihoIdGenerator = grihoIdGenerator ?? GrihoIdGenerator(),
       _userProfileDataSource =
           userProfileDataSource ?? UserProfileDataSource(),
       _phoneLookupDataSource =
           phoneLookupDataSource ?? PhoneLookupDataSource(),
       _tenantInvitationDataSource =
           tenantInvitationDataSource ?? TenantInvitationDataSource();

  /// Retrieves an existing Griho profile using the Firebase UID.
  Future<AppUserModel?> getUserProfileByFirebaseUid(String uid) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      return null;
    }
    return _userProfileDataSource.getUserByUid(normalizedUid);
  }

  /// Creates a new Griho profile or completes an existing incomplete profile.
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

    final normalizedName = _requireNonEmptyName(name);
    final normalizedPhone = PhoneNumberUtils.normalizeAndValidate(phoneNumber);

    final existingUser = await _userProfileDataSource.getUserByUid(
      firebaseUser.uid,
    );

    if (existingUser != null) {
      return _completeExistingUserProfile(
        existingUser: existingUser,
        firebaseUser: firebaseUser,
        normalizedName: normalizedName,
        normalizedPhone: normalizedPhone,
      );
    }

    await _ensurePhoneAvailable(
      phoneNumber: normalizedPhone,
      currentUid: firebaseUser.uid,
    );

    return _createNewUserWithReservedId(
      firebaseUser: firebaseUser,
      name: normalizedName,
      phoneNumber: normalizedPhone,
      defaultDashboard: null,
      availableRoles: const [],
    );
  }

  /// Registers a user using the existing registration intent flow.
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

    final normalizedName = _requireNonEmptyName(name);
    final normalizedPhone = PhoneNumberUtils.normalizeAndValidate(phoneNumber);

    final existingUser = await _userProfileDataSource.getUserByUid(
      firebaseUser.uid,
    );

    if (existingUser != null) {
      final user = await _completeExistingUserProfile(
        existingUser: existingUser,
        firebaseUser: firebaseUser,
        normalizedName: normalizedName,
        normalizedPhone: normalizedPhone,
      );
      return UserRegistrationResult(user: user);
    }

    await _ensurePhoneAvailable(
      phoneNumber: normalizedPhone,
      currentUid: firebaseUser.uid,
    );

    if (intent == RegistrationIntent.tenant) {
      final invitation = await _tenantInvitationDataSource
          .getPendingInvitationByPhone(normalizedPhone);
      final user = await _createNewUserWithReservedId(
        firebaseUser: firebaseUser,
        name: normalizedName,
        phoneNumber: normalizedPhone,
        defaultDashboard: null,
        availableRoles: const [],
      );
      return UserRegistrationResult(user: user, invitationId: invitation?.id);
    }

    final ownerUser = await _createNewUserWithReservedId(
      firebaseUser: firebaseUser,
      name: normalizedName,
      phoneNumber: normalizedPhone,
      defaultDashboard: 'owner',
      availableRoles: const ['owner'],
    );
    return UserRegistrationResult(user: ownerUser);
  }

  String _requireNonEmptyName(String name) {
    final normalized = name.trim();
    if (normalized.isEmpty) {
      throw ArgumentError('Name cannot be empty.');
    }
    return normalized;
  }

  Future<AppUser> _completeExistingUserProfile({
    required AppUserModel existingUser,
    required User firebaseUser,
    required String normalizedName,
    required String normalizedPhone,
  }) async {
    final existingPhone = existingUser.phoneNumber?.trim() ?? '';
    if (existingPhone.isNotEmpty) {
      final normalizedExistingPhone = PhoneNumberUtils.normalizeAndValidate(
        existingPhone,
      );
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
      defaultDashboard: existingUser.defaultDashboard,
      availableRoles: existingUser.availableRoles,
      isActive: existingUser.isActive,
      createdAt: existingUser.createdAt,
      updatedAt: DateTime.now(),
    );

    await _userProfileDataSource.updateUser(updatedUser);
    return updatedUser;
  }

  Future<AppUser> _createNewUserWithReservedId({
    required User firebaseUser,
    required String name,
    required String phoneNumber,
    required String? defaultDashboard,
    required List<String> availableRoles,
  }) async {
    final publicId = await _grihoIdGenerator.generateAndReserve();
    final now = DateTime.now();

    final newUser = AppUserModel(
      uid: firebaseUser.uid,
      publicId: publicId,
      name: name,
      phoneNumber: phoneNumber,
      email: firebaseUser.email,
      photoUrl: firebaseUser.photoURL,
      defaultDashboard: defaultDashboard,
      availableRoles: availableRoles,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await _userProfileDataSource.createUser(newUser);
      return newUser;
    } catch (_) {
      try {
        await _grihoIdGenerator.releaseReservation(publicId);
      } catch (_) {
        // Preserve the original profile creation error.
      }
      rethrow;
    }
  }

  /// Checks phone availability in 1 Firestore read via phone_lookups.
  Future<void> _ensurePhoneAvailable({
    required String phoneNumber,
    required String currentUid,
  }) async {
    final lookup = await _phoneLookupDataSource.getUserByPhone(phoneNumber);
    final existingUid = lookup?['uid'];

    if (existingUid is String &&
        existingUid.trim().isNotEmpty &&
        existingUid.trim() != currentUid) {
      throw StateError(
        'This phone number is already associated with another account.',
      );
    }
  }
}
