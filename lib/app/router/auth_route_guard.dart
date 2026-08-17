import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import 'route_names.dart';

class AuthRouteGuard {
  final Ref ref;

  const AuthRouteGuard(this.ref);

  Future<String?> redirect(String location) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    final isLoginRoute = location == RouteNames.login;
    final isOtpRoute = location == RouteNames.otpVerification;
    final isOnboardingRoute = location == RouteNames.onboarding;
    final isSplashRoute = location == RouteNames.splash;

    if (isSplashRoute) {
      return null;
    }

    if (firebaseUser == null) {
      if (isLoginRoute || isOtpRoute) {
        return null;
      }

      return RouteNames.login;
    }

    if (isLoginRoute) {
      return RouteNames.splash;
    }

    if (isOnboardingRoute) {
      final profile = await ref.read(
        currentUserProfileProvider.future,
      );

      if (profile != null) {
        return RouteNames.splash;
      }

      return null;
    }

    return null;
  }
}