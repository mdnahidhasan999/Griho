import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_role_resolver.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'auth_destination_mapper.dart';
import 'route_names.dart';

class AuthRouteGuard {
  final Ref ref;

  const AuthRouteGuard(this.ref);

  Future<String?> redirect(String location) async {
    final firebaseUser =
        FirebaseAuth.instance.currentUser;

    // ============================================================
    // NORMALIZE LOCATION
    // ============================================================

    final uri = Uri.tryParse(location);

    final path = uri?.path ?? location;

    // ============================================================
    // ROUTE FLAGS
    // ============================================================

    final isSplashRoute =
        path == RouteNames.splash;

    final isLoginRoute =
        path == RouteNames.login;

    final isOtpRoute =
        path == RouteNames.otpVerification;

    final isOnboardingRoute =
        path == RouteNames.onboarding;

    final isTenantInvitationRoute =
    path.startsWith('/i/');

    final isTenantAccountLinkRoute =
        path == RouteNames.tenantAccountLink;

    final isOwnerRoute =
        path == RouteNames.ownerHome;

    final isManagerRoute =
        path == RouteNames.managerHome;

    final isCaretakerRoute =
        path == RouteNames.caretakerHome;

    final isTenantRoute =
        path == RouteNames.tenantHome;

    final isProtectedRoute =
        isOwnerRoute ||
            isManagerRoute ||
            isCaretakerRoute ||
            isTenantRoute;

    // ============================================================
    // 1. SPLASH
    // ============================================================

    if (isSplashRoute) {
      return null;
    }

    // ============================================================
    // 2. TENANT INVITATION
    //
    // PUBLIC ROUTE
    //
    // Must be accessible:
    //
    // 1. Not authenticated
    // 2. Authenticated
    //
    // Example:
    //
    // /i/ABC123
    //
    // Do NOT redirect this route to login or tenant home.
    // ============================================================

    if (isTenantInvitationRoute) {
      return null;
    }

    // ============================================================
    // 3. USER NOT AUTHENTICATED
    // ============================================================

    if (firebaseUser == null) {
      // ----------------------------------------------------------
      // LOGIN
      // ----------------------------------------------------------

      if (isLoginRoute) {
        return null;
      }

      // ----------------------------------------------------------
      // OTP
      // ----------------------------------------------------------

      if (isOtpRoute) {
        return null;
      }

      // ----------------------------------------------------------
      // ACCOUNT LINK
      // ----------------------------------------------------------

      if (isTenantAccountLinkRoute) {
        return RouteNames.login;
      }

      // ----------------------------------------------------------
      // ONBOARDING
      // ----------------------------------------------------------

      if (isOnboardingRoute) {
        return RouteNames.login;
      }

      // ----------------------------------------------------------
      // ALL OTHER ROUTES
      // ----------------------------------------------------------

      return RouteNames.login;
    }

    // ============================================================
    // 4. USER IS AUTHENTICATED
    // ============================================================

    // ------------------------------------------------------------
    // LOGIN
    // ------------------------------------------------------------

    if (isLoginRoute) {
      return RouteNames.splash;
    }

    // ------------------------------------------------------------
    // OTP
    // ------------------------------------------------------------

    if (isOtpRoute) {
      return RouteNames.splash;
    }

    // ============================================================
    // 5. ONBOARDING
    // ============================================================

    if (isOnboardingRoute) {
      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getUserByUid(
        firebaseUser.uid,
      );

      // ----------------------------------------------------------
      // Profile already exists.
      // ----------------------------------------------------------

      if (profile != null) {
        final destination =
        AuthRoleResolver.resolve(
          profile.role,
        );

        return AuthDestinationMapper.routeFor(
          destination,
        );
      }

      // ----------------------------------------------------------
      // No profile.
      //
      // Allow onboarding.
      // ----------------------------------------------------------

      return null;
    }

    // ============================================================
    // 6. TENANT ACCOUNT LINK
    // ============================================================

    if (isTenantAccountLinkRoute) {
      return null;
    }

    // ============================================================
    // 7. PROTECTED ROLE ROUTES
    // ============================================================

    if (isProtectedRoute) {
      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getUserByUid(
        firebaseUser.uid,
      );

      // ----------------------------------------------------------
      // Authenticated but profile doesn't exist.
      // ----------------------------------------------------------

      if (profile == null) {
        return RouteNames.onboarding;
      }

      // ----------------------------------------------------------
      // Resolve actual role.
      // ----------------------------------------------------------

      final destination =
      AuthRoleResolver.resolve(
        profile.role,
      );

      final correctRoute =
      AuthDestinationMapper.routeFor(
        destination,
      );

      // ----------------------------------------------------------
      // Already on correct dashboard.
      // ----------------------------------------------------------

      if (path == correctRoute) {
        return null;
      }

      // ----------------------------------------------------------
      // Wrong dashboard.
      // ----------------------------------------------------------

      return correctRoute;
    }

    // ============================================================
    // 8. PUBLIC / UNKNOWN ROUTES
    // ============================================================

    return null;
  }
}