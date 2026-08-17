import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/firebase_auth_datasource.dart';
import '../../data/services/user_registration_service.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/auth_result.dart';
import '../../domain/entities/registration_intent.dart';
import 'auth_provider.dart';

final firebaseAuthDataSourceProvider = Provider<FirebaseAuthDataSource>((ref) {
  return FirebaseAuthDataSource();
});

final userRegistrationServiceProvider = Provider<UserRegistrationService>((
  ref,
) {
  return UserRegistrationService(
    userProfileDataSource: ref.watch(userProfileDataSourceProvider),
  );
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthControllerState>(AuthController.new);

class AuthControllerState {
  final bool isLoading;
  final String? verificationId;
  final String? errorMessage;
  final bool otpSent;
  final AppUser? user;

  const AuthControllerState({
    this.isLoading = false,
    this.verificationId,
    this.errorMessage,
    this.otpSent = false,
    this.user,
  });

  AuthControllerState copyWith({
    bool? isLoading,
    String? verificationId,
    String? errorMessage,
    bool? otpSent,
    AppUser? user,
    bool clearError = false,
  }) {
    return AuthControllerState(
      isLoading: isLoading ?? this.isLoading,
      verificationId: verificationId ?? this.verificationId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      otpSent: otpSent ?? this.otpSent,
      user: user ?? this.user,
    );
  }
}

class AuthController extends Notifier<AuthControllerState> {
  late final FirebaseAuthDataSource _authDataSource;
  late final UserRegistrationService _registrationService;

  @override
  AuthControllerState build() {
    _authDataSource = ref.watch(firebaseAuthDataSourceProvider);
    _registrationService = ref.watch(userRegistrationServiceProvider);

    ref.onDispose(() {});

    return const AuthControllerState();
  }

  Future<void> sendOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authDataSource.sendOtp(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          state = state.copyWith(
            isLoading: false,
            verificationId: verificationId,
            otpSent: true,
          );
        },
        onVerificationFailed: (message) {
          state = state.copyWith(isLoading: false, errorMessage: message);
        },
        onAutoVerified: () {
          state = state.copyWith(isLoading: false);
        },
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<AuthResult?> verifyOtp({required String smsCode}) async {
    final verificationId = state.verificationId;

    if (verificationId == null || verificationId.isEmpty) {
      state = state.copyWith(
        errorMessage:
            'Verification session has expired. Please request a new OTP.',
      );
      return null;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final credential = await _authDataSource.verifyOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final firebaseUser = credential.user;

      if (firebaseUser == null) {
        throw Exception(
          'Authentication succeeded, but no Firebase user was returned.',
        );
      }

      debugPrint('OTP verification successful. UID: ${firebaseUser.uid}');

      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getUserByUid(firebaseUser.uid)
          .timeout(const Duration(seconds: 10));

      debugPrint(
        'User profile lookup completed. Profile exists: ${profile != null}',
      );

      if (profile == null) {
        state = state.copyWith(isLoading: false);

        debugPrint('New user detected. Going to onboarding.');

        return const AuthResult.newUser();
      }

      state = state.copyWith(isLoading: false, user: profile);

      ref.invalidate(currentUserProfileProvider);

      debugPrint('Existing user detected.');

      return AuthResult.existingUser(profile);
    } catch (error) {
      debugPrint('OTP verification failed: $error');

      state = state.copyWith(isLoading: false, errorMessage: error.toString());

      return null;
    }
  }

  Future<AppUser?> register({
    required RegistrationIntent intent,
    required String name,
  }) async {
    debugPrint('REGISTER: started');

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      debugPrint('REGISTER: calling UserRegistrationService');

      final user = await _registrationService.register(
        intent: intent,
        name: name,
      );

      debugPrint('REGISTER: service completed. Griho ID = ${user.publicId}');

      state = state.copyWith(isLoading: false, user: user);

      ref.invalidate(currentUserProfileProvider);

      debugPrint('REGISTER: completed successfully');

      return user;
    } catch (error, stackTrace) {
      debugPrint('REGISTER ERROR: $error');
      debugPrint('REGISTER STACK: $stackTrace');

      state = state.copyWith(isLoading: false, errorMessage: error.toString());

      return null;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      await _authDataSource.signOut();

      state = const AuthControllerState();

      ref.invalidate(currentUserProfileProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }
}
