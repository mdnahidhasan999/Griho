import '../entities/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> get authStateChanges;

  AppUser? get currentUser;

  Future<void> sendOtp({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onVerificationFailed,
    required void Function() onAutoVerified,
  });

  Future<AppUser> verifyOtp({
    required String verificationId,
    required String smsCode,
  });

  Future<void> signOut();
}