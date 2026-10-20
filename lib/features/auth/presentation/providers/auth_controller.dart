import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ফায়ারবেস অথ
import 'package:shared_preferences/shared_preferences.dart';

import '../../../tenants/data/datasources/tenant_invitation_data_source.dart';
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
    tenantInvitationDataSource: TenantInvitationDataSource(),
  );
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthControllerState>(AuthController.new);

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
  late final FirebaseAuthDataSource _authDataSource;
  late final UserRegistrationService _registrationService;

  @override
  AuthControllerState build() {
    _authDataSource = ref.watch(firebaseAuthDataSourceProvider);
    _registrationService = ref.watch(userRegistrationServiceProvider);
    return const AuthControllerState();
  }

  // ============================================================
  // ১. SEND FIREBASE MAGIC LINK
  // ============================================================
  Future<void> sendEmailLink(String email) async {
    state = state.copyWith(isLoading: true, clearError: true, linkSent: false);

    try {
      final normalizedEmail = email.trim().toLowerCase();

      final acs = ActionCodeSettings(
        url: 'https://griho-crafttech.web.app/login',
        handleCodeInApp: true,
        androidPackageName: 'com.crafttech.griho',
        androidInstallApp: true,
        androidMinimumVersion: '1',
      );

      await FirebaseAuth.instance.sendSignInLinkToEmail(
        email: normalizedEmail,
        actionCodeSettings: acs,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('emailForSignIn', normalizedEmail);

      debugPrint('AUTH: Magic Link sent successfully.');

      state = state.copyWith(isLoading: false, linkSent: true);
    } catch (error, stackTrace) {
      debugPrint('MAGIC LINK ERROR: $error\n$stackTrace');

      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  // ============================================================
  // ২. VERIFY MAGIC LINK & LOGIN
  // ============================================================
  Future<bool> verifyEmailLink({
    required String email,
    required String emailLink,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final normalizedEmail = email.trim().toLowerCase();
      final link = emailLink.trim();

      if (!FirebaseAuth.instance.isSignInWithEmailLink(link)) {
        throw Exception(
          'Invalid or expired email link. Please request a new link.',
        );
      }

      await FirebaseAuth.instance.signInWithEmailLink(
        email: normalizedEmail,
        emailLink: link,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('emailForSignIn');

      state = state.copyWith(isLoading: false);

      debugPrint('AUTH: Email Link sign-in successful.');

      return true;
    } catch (error, stackTrace) {
      debugPrint('EMAIL LINK VERIFICATION ERROR: $error\n$stackTrace');

      state = state.copyWith(isLoading: false, errorMessage: error.toString());

      return false;
    }
  }

  // ============================================================
  // ৩. GOOGLE SIGN-IN
  // ============================================================
  Future<AuthResult?> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // গুগল সাইন ইন লজিক
      await Future.delayed(const Duration(seconds: 1));
      state = state.copyWith(isLoading: false);
      return const AuthResult.newUser();
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      return null;
    }
  }

  // ============================================================
  // ৪. REGISTER WITH EMAIL & PERMANENT PHONE
  // ============================================================
  Future<UserRegistrationResult?> registerWithEmailAndPhone({
    required RegistrationIntent intent,
    required String name,
    required String phoneNumber,
  }) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearInvitation: true,
    );

    try {
      final result = await _registrationService.register(
        intent: intent,
        name: name,
        phoneNumber: phoneNumber, // রিয়েল ফোন নম্বর
      );

      state = state.copyWith(
        isLoading: false,
        user: result.user,
        invitationId: result.invitationId,
      );
      ref.invalidate(currentUserProfileProvider);
      return result;
    } catch (error, stackTrace) {
      debugPrint('REGISTER ERROR: $error\n$stackTrace');
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
      return null;
    }
  }

  // ============================================================
  // ৫. SIGN OUT
  // ============================================================
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authDataSource.signOut();
      await FirebaseAuth.instance.signOut(); // Firebase থেকে সাইনআউট
      state = const AuthControllerState();
      ref.invalidate(currentUserProfileProvider);
    } catch (error) {
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }
}
