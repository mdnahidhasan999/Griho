import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/controllers/auth_role_resolver.dart';
import 'auth_destination_mapper.dart';
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
        isOwnerRoute || isManagerRoute || isCaretakerRoute || isTenantRoute;

    // ------------------------------------------------------------
    // 1. Splash
    // ------------------------------------------------------------

    if (isSplashRoute) {
      return null;
    }

    // ------------------------------------------------------------
    // 2. User is NOT authenticated
    // ------------------------------------------------------------

    if (firebaseUser == null) {
      if (isLoginRoute || isOtpRoute) {
        return null;
      }

      return RouteNames.login;
    }

    // ------------------------------------------------------------
    // 3. User IS authenticated
    // ------------------------------------------------------------

    if (isLoginRoute) {
      return RouteNames.splash;
    }

    // ------------------------------------------------------------
    // 4. OTP
    //
    // Once Firebase authentication is completed,
    // OTP screen should no longer be accessible.
    // ------------------------------------------------------------

    if (isOtpRoute) {
      return RouteNames.splash;
    }

    // ------------------------------------------------------------
    // 5. Onboarding
    // ------------------------------------------------------------

    if (isOnboardingRoute) {
      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getUserByUid(firebaseUser.uid);

      if (profile != null) {
        return AuthDestinationMapper.routeFor(
          AuthRoleResolver.resolve(profile.role),
        );
      }

      return null;
    }

    // ------------------------------------------------------------
    // 6. Protected routes
    // ------------------------------------------------------------

    if (isProtectedRoute) {
      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getUserByUid(firebaseUser.uid);

      // Authenticated but profile doesn't exist.
      // User must complete onboarding.
      if (profile == null) {
        return RouteNames.onboarding;
      }

      final destination = AuthRoleResolver.resolve(profile.role);

      final correctRoute = AuthDestinationMapper.routeFor(destination);

      // User is already on the correct route.
      if (location == correctRoute) {
        return null;
      }

      // User tried to access another role's dashboard.
      return correctRoute;
    }

    return null;
  }
}
