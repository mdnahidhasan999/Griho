// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_role_resolver.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'auth_destination_mapper.dart';
import 'route_names.dart';

class AuthRouteGuard {
  final Ref ref;

  const AuthRouteGuard(this.ref);

  Future<bool> _hasActiveManagerAccess(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('managerAccess')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

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
    final isTenantAccountLinkRoute = path == RouteNames.tenantAccountLink;

    // ড্যাশবোর্ড এবং সব সাব-রুট শনাক্তকরণ
    final isOwnerSection =
        path == RouteNames.ownerHome || path.startsWith('/owner/');
    final isManagerSection =
        path == RouteNames.managerHome || path.startsWith('/manager/');
    final isTenantSection =
        path == RouteNames.tenantHome || path.startsWith('/tenant/');
    final isCaretakerSection =
        path == RouteNames.caretakerHome || path.startsWith('/caretaker/');
    final isElectricianSection =
        path == RouteNames.electricianHome || path.startsWith('/electrician/');

    // শুধুমাত্র মালিকের একক রুট (ম্যানেজার এখানে ঢুকতে পারবে না)
    final isOwnerExclusiveRoute =
        path == RouteNames.addProperty ||
        path == RouteNames.addManager ||
        path == RouteNames.editProperty;

    final isProtectedSection =
        isOwnerSection ||
        isManagerSection ||
        isTenantSection ||
        isCaretakerSection ||
        isElectricianSection;

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

    final userProfileRepository = ref.read(userProfileRepositoryProvider);

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

    if (isProtectedSection) {
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

      final roles = profile.availableRoles
          .map((role) => role.trim().toLowerCase())
          .toSet();

      final hasActiveManager =
          roles.contains('manager') ||
          await _hasActiveManagerAccess(firebaseUser.uid);

      if (hasActiveManager) {
        roles.add('manager');
      }

      final destination = AuthRoleResolver.resolve(profile);
      final defaultFallbackRoute = AuthDestinationMapper.routeFor(destination);

      // ১. শুধুমাত্র মালিকের একক রুট (Add Property, Add Manager, Edit Property)
      if (isOwnerExclusiveRoute) {
        if (roles.contains('owner')) return null;
        return hasActiveManager ? RouteNames.managerHome : defaultFallbackRoute;
      }

      // ২. /owner এবং /owner/* সাব-রুট (Owner এবং Active Manager উভয়ের জন্য অনুমোদিত)
      if (isOwnerSection) {
        if (path == RouteNames.ownerHome) {
          if (roles.contains('owner')) return null;
          return hasActiveManager
              ? RouteNames.managerHome
              : defaultFallbackRoute;
        }
        if (roles.contains('owner') || hasActiveManager) {
          return null;
        }
        return defaultFallbackRoute;
      }

      // ৩. /manager এবং /manager/* সাব-রুট
      if (isManagerSection) {
        if (roles.contains('manager') || hasActiveManager) {
          return null;
        }
        return defaultFallbackRoute;
      }

      // ৪. /tenant এবং /tenant/* সাব-রুট
      if (isTenantSection) {
        if (roles.contains('tenant')) {
          return null;
        }
        return defaultFallbackRoute;
      }

      // ৫. Caretaker / Electrician সেকশন
      if (isCaretakerSection) {
        return roles.contains('caretaker') ? null : defaultFallbackRoute;
      }
      if (isElectricianSection) {
        return roles.contains('electrician') ? null : defaultFallbackRoute;
      }
    }

    return null;
  }
}
