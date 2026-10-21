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
        _userProfileDataSource = userProfileDataSource ??
            UserProfileDataSource(),
        _tenantInvitationDataSource = tenantInvitationDataSource ??
            TenantInvitationDataSource();

  Future<UserRegistrationResult> register({
    required RegistrationIntent intent,
    required String name,
    required String phoneNumber,
  }) async {
    final firebaseUser = _firebaseAuth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
          'A Firebase authenticated user is required for registration.');
    }

    final normalizedName = name.trim();
    if (normalizedName.isEmpty) {
      throw ArgumentError('Name cannot be empty.');
    }

    final phone = phoneNumber.trim();

    final existingUser = await _userProfileDataSource.getUserByUid(
        firebaseUser.uid);

    if (existingUser != null) {
      // যদি ইউজার আগে থেকেই থাকে, কিন্তু ফোন নাম্বার অ্যাড করতে চায় (যেমন গুগল সাইন ইন এর পর)
      if (existingUser.phoneNumber == null ||
          existingUser.phoneNumber!.isEmpty) {
        // Unnecessary cast রিমুভ করা হয়েছে এবং ফিক্স করা হয়েছে
        final updatedAppUser = existingUser.copyWith(
          phoneNumber: phone,
          defaultDashboard: intent == RegistrationIntent.tenant
              ? 'tenant'
              : 'owner',
        );

        final updatedUserModel = AppUserModel.fromEntity(updatedAppUser);

        await _userProfileDataSource.updateUser(updatedUserModel);
        return UserRegistrationResult(user: updatedUserModel);
      }
      return UserRegistrationResult(user: existingUser);
    }

    if (intent == RegistrationIntent.tenant) {
      return _registerTenant(
        firebaseUser: firebaseUser,
        name: normalizedName,
        phoneNumber: phone,
      );
    }

    final user = await _registerOwner(
      firebaseUser: firebaseUser,
      name: normalizedName,
      phoneNumber: phone,
    );

    return UserRegistrationResult(user: user);
  }

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
      await _grihoIdGenerator.releaseReservation(publicId);
      rethrow;
    }
  }

  Future<UserRegistrationResult> _registerTenant({
    required User firebaseUser,
    required String name,
    required String phoneNumber,
  }) async {
    if (!PhoneNumberUtils.isValid(phoneNumber)) {
      throw StateError('Invalid phone number format.');
    }

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
      await _grihoIdGenerator.releaseReservation(publicId);
      rethrow;
    }
  }
}
