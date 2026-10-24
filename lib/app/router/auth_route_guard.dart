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
    final firebaseUser = FirebaseAuth.instance.currentUser;

    final uri = Uri.tryParse(location);
    final path = uri?.path ?? location;

    final isSplashRoute = path == RouteNames.splash;
    final isLoginRoute = path == RouteNames.login;
    final isCreateAccountRoute = path == RouteNames.createAccount;
    final isForgotPasswordRoute = path == RouteNames.forgotPassword;
    final isLinkWaitingRoute = path == RouteNames.linkWaiting;
    final isOnboardingRoute = path == RouteNames.onboarding;
    final isRoleSelectionRoute = path == RouteNames.roleSelection;
    final isOwnerWelcomeRoute = path == RouteNames.ownerWelcome;
    final isTenantInvitationRoute = path.startsWith('/i/');
    final isTenantAccountLinkRoute =
        path == RouteNames.tenantAccountLink;

    final isOwnerRoute = path == RouteNames.ownerHome;
    final isManagerRoute = path == RouteNames.managerHome;
    final isCaretakerRoute = path == RouteNames.caretakerHome;
    final isElectricianRoute = path == RouteNames.electricianHome;
    final isTenantRoute = path == RouteNames.tenantHome;

    final isProtectedRoute =
        isOwnerRoute ||
            isManagerRoute ||
            isCaretakerRoute ||
            isElectricianRoute ||
            isTenantRoute;

    if (isSplashRoute) {
      return null;
    }

    if (isTenantInvitationRoute) {
      if (firebaseUser == null) {
        final segments = uri?.pathSegments ?? const <String>[];
        final token = segments.length > 1 ? segments[1] : '';
        return Uri(
          path: RouteNames.login,
          queryParameters: token.isEmpty ? null : {'invitationId': token},
        ).toString();
      }
      return null;
    }

    if (firebaseUser == null) {
      if (isLoginRoute ||
          isCreateAccountRoute ||
          isForgotPasswordRoute ||
          isLinkWaitingRoute) {
        return null;
      }

      if (isTenantAccountLinkRoute) {
        return RouteNames.login;
      }

      return RouteNames.login;
    }

    if (isLoginRoute || isLinkWaitingRoute) {
      return RouteNames.splash;
    }

    final userProfileRepository =
    ref.read(userProfileRepositoryProvider);

    if (isOnboardingRoute) {
      final profile = await userProfileRepository.getUserByUid(
        firebaseUser.uid,
      );

      if (profile == null) {
        return null;
      }

      final destination = AuthRoleResolver.resolve(profile);

      return AuthDestinationMapper.routeFor(destination);
    }

    if (isRoleSelectionRoute) {
      final profile = await userProfileRepository.getUserByUid(
        firebaseUser.uid,
      );

      if (profile == null) {
        return RouteNames.onboarding;
      }

      final phoneNumber = profile.phoneNumber?.trim() ?? '';

      if (phoneNumber.isEmpty) {
        return RouteNames.onboarding;
      }

      final destination = AuthRoleResolver.resolve(profile);

      if (destination == AuthUserDestination.roleSelection) {
        return null;
      }

      return AuthDestinationMapper.routeFor(destination);
    }

    if (isOwnerWelcomeRoute) {
      final profile = await userProfileRepository.getUserByUid(
        firebaseUser.uid,
      );

      if (profile == null) {
        return RouteNames.onboarding;
      }

      final phoneNumber = profile.phoneNumber?.trim() ?? '';

      if (phoneNumber.isEmpty) {
        return RouteNames.onboarding;
      }

      final availableRoles = profile.availableRoles
          .map((role) => role.trim().toLowerCase())
          .toSet();

      if (!availableRoles.contains('owner')) {
        final destination = AuthRoleResolver.resolve(profile);

        if (destination == AuthUserDestination.roleSelection) {
          return RouteNames.roleSelection;
        }

        return AuthDestinationMapper.routeFor(destination);
      }

      return null;
    }

    if (isProtectedRoute) {
      final profile = await userProfileRepository.getUserByUid(
        firebaseUser.uid,
      );

      if (profile == null) {
        return RouteNames.onboarding;
      }

      final phoneNumber = profile.phoneNumber?.trim() ?? '';

      if (phoneNumber.isEmpty) {
        return RouteNames.onboarding;
      }

      final destination = AuthRoleResolver.resolve(profile);
      final correctRoute = AuthDestinationMapper.routeFor(destination);

      if (path == correctRoute) {
        return null;
      }

      return correctRoute;
    }

    return null;
  }
}