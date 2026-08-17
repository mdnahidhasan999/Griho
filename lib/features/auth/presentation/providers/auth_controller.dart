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

final userRegistrationServiceProvider =
Provider<UserRegistrationService>((ref) {
  return UserRegistrationService(
    userProfileDataSource: ref.watch(userProfileDataSourceProvider),
  );
});

final authControllerProvider =
NotifierProvider<AuthController, AuthControllerState>(
  AuthController.new,
);

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
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

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
          state = state.copyWith(
            isLoading: false,
            errorMessage: message,
          );
        },
        onAutoVerified: () {
          state = state.copyWith(
            isLoading: false,
          );
        },
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<AuthResult?> verifyOtp({
    required String smsCode,
  }) async {
    final verificationId = state.verificationId;

    if (verificationId == null || verificationId.isEmpty) {
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
      await _authDataSource.verifyOtp(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      ref.invalidate(currentUserProfileProvider);

      final profile = await ref.read(
        currentUserProfileProvider.future,
      );

      if (profile == null) {
        state = state.copyWith(
          isLoading: false,
        );

        return const AuthResult.newUser();
      }

      state = state.copyWith(
        isLoading: false,
        user: profile,
      );

      return AuthResult.existingUser(profile);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );

      return null;
    }
  }

  Future<AppUser?> register({
    required RegistrationIntent intent,
    required String name,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final user = await _registrationService.register(
        intent: intent,
        name: name,
      );

      state = state.copyWith(
        isLoading: false,
        user: user,
      );

      ref.invalidate(currentUserProfileProvider);

      return user;
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );

      return null;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      await _authDataSource.signOut();

      state = const AuthControllerState();

      ref.invalidate(currentUserProfileProvider);
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }
}