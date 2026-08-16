import 'package:firebase_auth/firebase_auth.dart';

import '../../data/datasources/firebase_auth_datasource.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuthDataSource _dataSource;

  FirebaseAuthRepository({FirebaseAuthDataSource? dataSource})
    : _dataSource = dataSource ?? FirebaseAuthDataSource();

  @override
  Stream<AppUser?> get authStateChanges {
    return _dataSource.authStateChanges.map(
      (user) => user == null ? null : _mapFirebaseUser(user),
    );
  }

  @override
  AppUser? get currentUser {
    final user = _dataSource.currentUser;

    if (user == null) {
      return null;
    }

    return _mapFirebaseUser(user);
  }

  @override
  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onVerificationFailed,
    required void Function() onAutoVerified,
  }) {
    return _dataSource.sendOtp(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onVerificationFailed: onVerificationFailed,
      onAutoVerified: onAutoVerified,
    );
  }

  @override
  Future<AppUser> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = await _dataSource.verifyOtp(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    return _mapFirebaseUser(credential.user!);
  }

  @override
  Future<void> signOut() {
    return _dataSource.signOut();
  }

  AppUser _mapFirebaseUser(User user) {
    return AppUser(
      uid: user.uid,
      publicId: '',
      role: UserRole.tenant,
      name: user.displayName ?? '',
      phoneNumber: user.phoneNumber,
      email: user.email,
      photoUrl: user.photoURL,
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
