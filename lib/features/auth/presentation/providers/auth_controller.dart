import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../tenants/data/datasources/tenant_invitation_data_source.dart';

import '../../data/datasources/firebase_auth_datasource.dart';
import '../../data/services/user_registration_service.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/entities/registration_intent.dart';

import 'auth_provider.dart';

// ================================================================
// FIREBASE AUTH DATA SOURCE
// ================================================================

final firebaseAuthDataSourceProvider =
Provider<FirebaseAuthDataSource>((ref) {
  return FirebaseAuthDataSource();
});

// ================================================================
// USER REGISTRATION SERVICE
// ================================================================

final userRegistrationServiceProvider =
Provider<UserRegistrationService>((ref) {
  return UserRegistrationService(
    userProfileDataSource:
    ref.watch(userProfileDataSourceProvider),
    tenantInvitationDataSource:
    TenantInvitationDataSource(),
  );
});

// ================================================================
// AUTH CONTROLLER PROVIDER
// ================================================================

final authControllerProvider =
NotifierProvider<
    AuthController,
    AuthControllerState>(
  AuthController.new,
);

// ================================================================
// AUTH CONTROLLER STATE
// ================================================================

class AuthControllerState {
  final bool isLoading;

  final String? verificationId;

  final String? errorMessage;

  final bool otpSent;

  final AppUser? user;

  // Pending tenant invitation
  final String? invitationId;

  const AuthControllerState({
    this.isLoading = false,
    this.verificationId,
    this.errorMessage,
    this.otpSent = false,
    this.user,
    this.invitationId,
  });

  AuthControllerState copyWith({
    bool? isLoading,
    String? verificationId,
    String? errorMessage,
    bool? otpSent,
    AppUser? user,
    String? invitationId,
    bool clearError = false,
    bool clearInvitation = false,
  }) {
    return AuthControllerState(
      isLoading:
      isLoading ?? this.isLoading,

      verificationId:
      verificationId ?? this.verificationId,

      errorMessage:
      clearError
          ? null
          : errorMessage ?? this.errorMessage,

      otpSent:
      otpSent ?? this.otpSent,

      user:
      user ?? this.user,

      invitationId:
      clearInvitation
          ? null
          : invitationId ?? this.invitationId,
    );
  }
}

// ================================================================
// AUTH CONTROLLER
// ================================================================

class AuthController extends Notifier<AuthControllerState> {
  late final FirebaseAuthDataSource
  _authDataSource;

  late final UserRegistrationService
  _registrationService;

  @override
  AuthControllerState build() {
    _authDataSource =
        ref.watch(
          firebaseAuthDataSourceProvider,
        );

    _registrationService =
        ref.watch(
          userRegistrationServiceProvider,
        );

    return const AuthControllerState();
  }

  // ============================================================
  // SEND OTP
  // ============================================================

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      otpSent: false,
      verificationId: null,
    );

    try {
      await _authDataSource
          .sendOtp(
        phoneNumber: phoneNumber,

        // ------------------------------------------------------
        // CODE SENT
        // ------------------------------------------------------

        onCodeSent: (verificationId) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            otpSent: true,
          );

          debugPrint(
            'AUTH: OTP code sent successfully.',
          );
        },

        // ------------------------------------------------------
        // VERIFICATION FAILED
        // ------------------------------------------------------

        onVerificationFailed: (message) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: message,
          );

          debugPrint(
            'AUTH: Phone verification failed: $message',
          );
        },

        // ------------------------------------------------------
        // AUTO VERIFIED
        // ------------------------------------------------------

        onAutoVerified: () {
          state = state.copyWith(
            isLoading: false,
          );

          debugPrint(
            'AUTH: Phone automatically verified.',
          );
        },
      )
          .timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw StateError(
            'Phone verification timed out. '
                'Please check your internet connection and try again.',
          );
        },
      );
    } catch (error) {
      debugPrint(
        'AUTH: sendOtp failed: $error',
      );

      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<AuthResult?> verifyOtp({
    required String smsCode,
  }) async {
    final verificationId =
        state.verificationId;

    if (verificationId == null ||
        verificationId.isEmpty) {
      state = state.copyWith(
        errorMessage:
        'Verification session has expired. Please request a new OTP.',
      );

      return null;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final credential =
      await _authDataSource.verifyOtp(
        verificationId:
        verificationId,
        smsCode: smsCode,
      );

      final firebaseUser =
          credential.user;

      if (firebaseUser == null) {
        throw Exception(
          'Authentication succeeded, but no Firebase user was returned.',
        );
      }

      debugPrint(
        'OTP verification successful. '
            'UID: ${firebaseUser.uid}',
      );

      // ========================================================
      // CHECK PROFILE
      // ========================================================

      final profile =
      await ref
          .read(
        userProfileRepositoryProvider,
      )
          .getUserByUid(
        firebaseUser.uid,
      )
          .timeout(
        const Duration(
          seconds: 10,
        ),
      );

      debugPrint(
        'User profile lookup completed. '
            'Profile exists: ${profile != null}',
      );

      // ========================================================
      // NEW USER
      // ========================================================

      if (profile == null) {
        state = state.copyWith(
          isLoading: false,
        );

        debugPrint(
          'New user detected. Going to onboarding.',
        );

        return const AuthResult.newUser();
      }

      // ========================================================
      // EXISTING USER
      // ========================================================

      state = state.copyWith(
        isLoading: false,
        user: profile,
      );

      ref.invalidate(
        currentUserProfileProvider,
      );

      debugPrint(
        'Existing user detected.',
      );

      return AuthResult.existingUser(
        profile,
      );
    } catch (error) {
      debugPrint(
        'OTP verification failed: $error',
      );

      state = state.copyWith(
        isLoading: false,
        errorMessage:
        error.toString(),
      );

      return null;
    }
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<UserRegistrationResult?>
  register({
    required RegistrationIntent intent,
    required String name,
  }) async {
    debugPrint(
      'REGISTER: started',
    );

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearInvitation: true,
    );

    try {
      debugPrint(
        'REGISTER: calling UserRegistrationService',
      );

      final result =
      await _registrationService.register(
        intent: intent,
        name: name,
      );

      debugPrint(
        'REGISTER: service completed. '
            'Griho ID = ${result.user.publicId}',
      );

      debugPrint(
        'REGISTER: invitationId = '
            '${result.invitationId}',
      );

      state = state.copyWith(
        isLoading: false,
        user: result.user,
        invitationId:
        result.invitationId,
      );

      ref.invalidate(
        currentUserProfileProvider,
      );

      debugPrint(
        'REGISTER: completed successfully',
      );

      return result;
    } catch (
    error,
    stackTrace
    ) {
      debugPrint(
        'REGISTER ERROR: $error',
      );

      debugPrint(
        'REGISTER STACK: $stackTrace',
      );

      state = state.copyWith(
        isLoading: false,
        errorMessage:
        error.toString(),
      );

      return null;
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

      state =
      const AuthControllerState();

      ref.invalidate(
        currentUserProfileProvider,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage:
        error.toString(),
      );
    }
  }
}