import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/registration_intent.dart';
import '../datasources/user_profile_datasource.dart';
import '../models/app_user_model.dart';
import 'griho_id_generator.dart';

class UserRegistrationService {
  final FirebaseAuth _firebaseAuth;
  final GrihoIdGenerator _grihoIdGenerator;
  final UserProfileDataSource _userProfileDataSource;

  UserRegistrationService({
    FirebaseAuth? firebaseAuth,
    GrihoIdGenerator? grihoIdGenerator,
    UserProfileDataSource? userProfileDataSource,
  })
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _grihoIdGenerator = grihoIdGenerator ?? GrihoIdGenerator(),
        _userProfileDataSource =
            userProfileDataSource ?? UserProfileDataSource();

  Future<AppUser> register({
    required RegistrationIntent intent,
    required String name,
  }) async {
    final firebaseUser = _firebaseAuth.currentUser;

    if (firebaseUser == null) {
      throw StateError(
        'A Firebase authenticated user is required for registration.',
      );
    }

    final existingUser = await _userProfileDataSource.getUserByUid(
      firebaseUser.uid,
    );

    if (existingUser != null) {
      return existingUser;
    }

    final publicId = await _grihoIdGenerator.generateAndReserve();
    final now = DateTime.now();

    final user = AppUser(
      uid: firebaseUser.uid,
      publicId: publicId,
      role: _roleFromRegistrationIntent(intent),
      name: name.trim(),
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
      await _grihoIdGenerator.releaseReservation(publicId);
      rethrow;
    }
  }

  UserRole _roleFromRegistrationIntent(RegistrationIntent intent,) {
    switch (intent) {
      case RegistrationIntent.owner:
        return UserRole.owner;

      case RegistrationIntent.tenant:
        return UserRole.tenant;
    }
  }
}