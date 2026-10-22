import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../tenants/data/datasources/tenant_invitation_data_source.dart';
import '../../data/datasources/firebase_auth_datasource.dart';
import '../../data/services/user_registration_service.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_result.dart';
import 'auth_provider.dart';

final firebaseAuthDataSourceProvider =
Provider<FirebaseAuthDataSource>((ref) {
  return FirebaseAuthDataSource();
});

final userRegistrationServiceProvider =
Provider<UserRegistrationService>((ref) {
  return UserRegistrationService(
    userProfileDataSource: ref.watch(userProfileDataSourceProvider),
    tenantInvitationDataSource: TenantInvitationDataSource(),
  );
});

final authControllerProvider =
NotifierProvider<AuthController, AuthControllerState>(
  AuthController.new,
);

class AuthControllerState {
  final bool isLoading;
  final String? errorMessage;
  final bool linkSent;
  final AppUser? user;
  final String? invitationId;

  const AuthControllerState({
    this.isLoading = false,
    this.errorMessage,
    this.linkSent = false,
    this.user,
    this.invitationId,
  });

  AuthControllerState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? linkSent,
    AppUser? user,
    String? invitationId,
    bool clearError = false,
    bool clearInvitation = false,
  }) {
    return AuthControllerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      linkSent: linkSent ?? this.linkSent,
      user: user ?? this.user,
      invitationId: clearInvitation ? null : invitationId ?? this.invitationId,
    );
  }
}

class AuthController extends Notifier<AuthControllerState> {
  late FirebaseAuth _firebaseAuth;
  late FirebaseAuthDataSource _authDataSource;
  late UserRegistrationService _registrationService;

  bool _googleInitialized = false;

  @override
  AuthControllerState build() {
    _firebaseAuth = FirebaseAuth.instance;
    _authDataSource = ref.watch(firebaseAuthDataSourceProvider);
    _registrationService = ref.watch(userRegistrationServiceProvider);

    return const AuthControllerState();
  }

  void resetStatus() {
    state = state.copyWith(
      isLoading: false,
      clearError: true,
      linkSent: false,
    );
  }

  // ============================================================
  // CREATE ACCOUNT WITH EMAIL AND PASSWORD
  // ============================================================

  Future<bool> createAccountWithEmailAndPassword({
    required String name,
    required String phoneNumber,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      linkSent: false,
    );

    User? createdFirebaseUser;
    bool profileCreated = false;

    try {
      final normalizedName = name.trim();
      final normalizedEmail = email.trim().toLowerCase();

      if (normalizedName.length < 2) {
        throw ArgumentError('Please enter your full name.');
      }

      if (normalizedEmail.isEmpty) {
        throw ArgumentError('Please enter your email address.');
      }

      if (password.length < 6) {
        throw ArgumentError(
          'Password must contain at least 6 characters.',
        );
      }

      final credential =
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw StateError('Account creation failed. Please try again.');
      }

      createdFirebaseUser = firebaseUser;

      await firebaseUser.updateDisplayName(normalizedName);
      await firebaseUser.reload();

      final currentFirebaseUser = _firebaseAuth.currentUser;

      if (currentFirebaseUser == null) {
        throw StateError(
          'Your account was created, but the session could not be restored.',
        );
      }

      final profile = await _registrationService.createOrUpdateUserProfile(
        firebaseUser: currentFirebaseUser,
        name: normalizedName,
        phoneNumber: phoneNumber,
      );

      profileCreated = true;

      final actionCodeSettings = ActionCodeSettings(
        url: 'https://griho-crafttech.web.app/verify-email',
        handleCodeInApp: true,
        androidPackageName: 'com.crafttech.griho',
        androidInstallApp: true,
        androidMinimumVersion: '1',
      );

      await currentFirebaseUser.sendEmailVerification(
        actionCodeSettings,
      );

      await _firebaseAuth.signOut();

      ref.invalidate(currentUserProfileProvider);

      state = state.copyWith(
        isLoading: false,
        linkSent: true,
        user: profile,
        clearError: true,
      );

      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'CREATE ACCOUNT ERROR: $error\n$stackTrace',
      );

      // Delete a newly created Firebase account only if its profile
      // was not successfully created.
      if (createdFirebaseUser != null && !profileCreated) {
        try {
          await createdFirebaseUser.delete();
        } catch (cleanupError) {
          debugPrint(
            'ACCOUNT CLEANUP ERROR: $cleanupError',
          );
        }
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(error),
      );

      return false;
    }
  }

  // ============================================================
  // VERIFY EMAIL ADDRESS
  // ============================================================

  Future<bool> handleEmailVerificationCode(String oobCode) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final code = oobCode.trim();

      if (code.isEmpty) {
        throw ArgumentError('The email verification code is missing.');
      }

      final actionCodeInfo =
      await _firebaseAuth.checkActionCode(code);

      if (actionCodeInfo.operation != ActionCodeInfoOperation.verifyEmail) {
        throw StateError(
          'This link is not an email verification link.',
        );
      }

      await _firebaseAuth.applyActionCode(code);

      state = state.copyWith(
        isLoading: false,
        clearError: true,
      );

      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'EMAIL VERIFICATION ERROR: $error\n$stackTrace',
      );

      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(error),
      );

      return false;
    }
  }

  // ============================================================
  // SIGN IN WITH EMAIL AND PASSWORD
  // ============================================================

  Future<AuthResult?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearInvitation: true,
    );

    try {
      final credential =
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw StateError('Sign-in failed. Please try again.');
      }

      if (!firebaseUser.emailVerified) {
        await _firebaseAuth.signOut();

        throw StateError(
          'Please verify your email address before signing in.',
        );
      }

      final profile =
      await _registrationService.getUserProfileByFirebaseUid(
        firebaseUser.uid,
      );

      if (profile == null ||
          profile.phoneNumber == null ||
          profile.phoneNumber!.trim().isEmpty) {
        state = state.copyWith(
          isLoading: false,
          user: profile,
          clearError: true,
        );

        ref.invalidate(currentUserProfileProvider);

        return const AuthResult.newUser();
      }

      state = state.copyWith(
        isLoading: false,
        user: profile,
        clearError: true,
      );

      ref.invalidate(currentUserProfileProvider);

      return AuthResult.existingUser(profile);
    } catch (error, stackTrace) {
      debugPrint('EMAIL SIGN-IN ERROR: $error\n$stackTrace');

      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(error),
      );

      return null;
    }
  }

  // ============================================================
  // GOOGLE SIGN-IN
  // ============================================================

  Future<AuthResult?> signInWithGoogle() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearInvitation: true,
    );

    try {
      if (!_googleInitialized) {
        await GoogleSignIn.instance.initialize();
        _googleInitialized = true;
      }

      final GoogleSignInAccount googleUser =
      await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'Google Sign-In did not return an ID token. '
              'Check your Firebase and Google Sign-In configuration.',
        );
      }

      final OAuthCredential credential =
      GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final UserCredential userCredential =
      await _firebaseAuth.signInWithCredential(credential);

      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw StateError('Google Sign-In failed. Please try again.');
      }

      final profile =
      await _registrationService.getUserProfileByFirebaseUid(
        firebaseUser.uid,
      );

      if (profile == null ||
          profile.phoneNumber == null ||
          profile.phoneNumber!.trim().isEmpty) {
        state = state.copyWith(
          isLoading: false,
          user: profile,
          clearError: true,
        );

        ref.invalidate(currentUserProfileProvider);

        return const AuthResult.newUser();
      }

      state = state.copyWith(
        isLoading: false,
        user: profile,
        clearError: true,
      );

      ref.invalidate(currentUserProfileProvider);

      return AuthResult.existingUser(profile);
    } catch (error, stackTrace) {
      debugPrint('GOOGLE SIGN-IN ERROR: $error\n$stackTrace');

      try {
        if (_firebaseAuth.currentUser != null) {
          await _firebaseAuth.signOut();
        }
      } catch (signOutError) {
        debugPrint('GOOGLE SIGN-OUT ERROR: $signOutError');
      }

      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(error),
      );

      return null;
    }
  }

  // ============================================================
  // COMPLETE USER PROFILE
  // ============================================================

  Future<AppUser?> completeUserProfile({
    required String name,
    required String phoneNumber,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final firebaseUser = _firebaseAuth.currentUser;

      if (firebaseUser == null) {
        throw StateError(
          'Your session has expired. Please sign in again.',
        );
      }

      final profile = await _registrationService.createOrUpdateUserProfile(
        firebaseUser: firebaseUser,
        name: name.trim(),
        phoneNumber: phoneNumber,
      );

      state = state.copyWith(
        isLoading: false,
        user: profile,
        clearError: true,
      );

      ref.invalidate(currentUserProfileProvider);

      return profile;
    } catch (error, stackTrace) {
      debugPrint(
        'COMPLETE PROFILE ERROR: $error\n$stackTrace',
      );

      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(error),
      );

      return null;
    }
  }

  // ============================================================
  // SEND PASSWORD RESET EMAIL
  // ============================================================

  Future<bool> sendPasswordResetEmail(String email) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      linkSent: false,
    );

    try {
      final normalizedEmail = email.trim().toLowerCase();

      if (normalizedEmail.isEmpty) {
        throw ArgumentError('Please enter your email address.');
      }

      await _firebaseAuth.sendPasswordResetEmail(
        email: normalizedEmail,
      );

      state = state.copyWith(
        isLoading: false,
        linkSent: true,
        clearError: true,
      );

      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'PASSWORD RESET ERROR: $error\n$stackTrace',
      );

      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(error),
      );

      return false;
    }
  }

  // ============================================================
  // RESEND EMAIL VERIFICATION
  // ============================================================

  Future<bool> resendEmailVerification() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final user = _firebaseAuth.currentUser;

      if (user == null) {
        throw StateError(
          'Please sign in before requesting email verification.',
        );
      }

      if (user.emailVerified) {
        state = state.copyWith(isLoading: false);
        return true;
      }

      await user.sendEmailVerification();

      state = state.copyWith(
        isLoading: false,
        linkSent: true,
        clearError: true,
      );

      return true;
    } catch (error, stackTrace) {
      debugPrint(
        'RESEND VERIFICATION ERROR: $error\n$stackTrace',
      );

      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(error),
      );

      return false;
    }
  }

  // ============================================================
  // RELOAD EMAIL VERIFICATION STATUS
  // ============================================================

  Future<bool> reloadEmailVerificationStatus() async {
    try {
      final user = _firebaseAuth.currentUser;

      if (user == null) return false;

      await user.reload();

      return _firebaseAuth.currentUser?.emailVerified ?? false;
    } catch (error, stackTrace) {
      debugPrint(
        'RELOAD EMAIL VERIFICATION ERROR: $error\n$stackTrace',
      );

      state = state.copyWith(
        errorMessage: _friendlyAuthError(error),
      );

      return false;
    }
  }

  // ============================================================
  // SIGN OUT
  // ============================================================

  Future<void> signOut() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      await _authDataSource.signOut();

      ref.invalidate(currentUserProfileProvider);

      state = const AuthControllerState();
    } catch (error, stackTrace) {
      debugPrint('SIGN-OUT ERROR: $error\n$stackTrace');

      state = state.copyWith(
        isLoading: false,
        errorMessage: _friendlyAuthError(error),
      );
    }
  }

  // ============================================================
  // FRIENDLY AUTHENTICATION ERRORS
  // ============================================================

  String _friendlyAuthError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'An account already exists for this email address.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Please choose a stronger password.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'The email address or password is incorrect.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Check your internet connection.';
        case 'operation-not-allowed':
          return 'This sign-in method is not enabled in Firebase.';
        case 'expired-action-code':
          return 'This link has expired. Please request a new one.';
        case 'invalid-action-code':
          return 'This link is invalid or has already been used.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with this email. '
              'Sign in using your original sign-in method.';
        default:
          return error.message ?? 'Authentication failed. Please try again.';
      }
    }

    if (error is ArgumentError || error is StateError) {
      return error.toString().replaceFirst(
        RegExp(r'^(Bad state: |Invalid argument\(s\): )'),
        '',
      );
    }

    return 'Something went wrong. Please try again.';
  }
}