import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import 'route_names.dart';

class AuthRouteGuard {
  final Ref ref;

  const AuthRouteGuard(this.ref);

  Future<String?> redirect(String location) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    final isSplashRoute = location == RouteNames.splash;
    final isLoginRoute = location == RouteNames.login;
    final isOtpRoute = location == RouteNames.otpVerification;
    final isOnboardingRoute = location == RouteNames.onboarding;

    final isOwnerRoute = location == RouteNames.ownerHome;
    final isManagerRoute = location == RouteNames.managerHome;
    final isCaretakerRoute = location == RouteNames.caretakerHome;
    final isTenantRoute = location == RouteNames.tenantHome;

    final isProtectedRoute =
        isOwnerRoute ||
            isManagerRoute ||
            isCaretakerRoute ||
            isTenantRoute;

    // ------------------------------------------------------------
    // 1. Splash is always allowed.
    // SplashScreen itself decides where the user should go.
    // ------------------------------------------------------------

    if (isSplashRoute) {
      return null;
    }

    // ------------------------------------------------------------
    // 2. User is NOT authenticated.
    // ------------------------------------------------------------

    if (firebaseUser == null) {
      if (isLoginRoute || isOtpRoute) {
        return null;
      }

      return RouteNames.login;
    }

    // ------------------------------------------------------------
    // 3. User IS authenticated.
    // ------------------------------------------------------------

    // Authenticated users should not stay on login.
    if (isLoginRoute) {
      return RouteNames.splash;
    }

    // ------------------------------------------------------------
    // 4. Onboarding.
    // ------------------------------------------------------------

    if (isOnboardingRoute) {
      final profile = await ref.read(
        userProfileRepositoryProvider,
      ).getUserByUid(firebaseUser.uid);

      // Profile already exists → onboarding is no longer needed.
      if (profile != null) {
        return RouteNames.splash;
      }

      // Authenticated but no profile → allow onboarding.
      return null;
    }

    // ------------------------------------------------------------
    // 5. OTP route.
    //
    // If Firebase authentication is already completed,
    // OTP screen should no longer be accessible.
    // ------------------------------------------------------------

    if (isOtpRoute) {
      return RouteNames.splash;
    }

    // ------------------------------------------------------------
    // 6. Protected home routes.
    //
    // For now, allow them because the actual role validation
    // happens when OTP verification resolves the user.
    // ------------------------------------------------------------

    if (isProtectedRoute) {
      return null;
    }

    return null;
  }
}