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

  // uid -> (fetchedAt, active access roles). Avoids a Firestore round-trip
  // on every navigation; the real protection is always Firestore rules.
  static final Map<String, ({DateTime at, Set<String> roles})> _accessCache = {};
  static const Duration _accessTtl = Duration(seconds: 20);

  static void clearAccessCache() => _accessCache.clear();

  /// Roles for which the user currently has ACTIVE property access:
  /// 'manager' (managerAccess), 'caretaker' / 'electrician' (staffAccess).
  Future<Set<String>> _activeAccessRoles(String uid) async {
    final cached = _accessCache[uid];
    if (cached != null && DateTime.now().difference(cached.at) < _accessTtl) {
      return cached.roles;
    }

    final db = FirebaseFirestore.instance;
    final roles = <String>{};

    try {
      final results = await Future.wait([
        db
            .collection('managerAccess')
            .where('userId', isEqualTo: uid)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get(),
        db
            .collection('staffAccess')
            .where('userId', isEqualTo: uid)
            .where('status', isEqualTo: 'active')
            .get(),
      ]);

      if (results[0].docs.isNotEmpty) roles.add('manager');
      for (final doc in results[1].docs) {
        final role = (doc.data()['staffRole'] ?? '').toString();
        if (role == 'caretaker' || role == 'electrician') roles.add(role);
      }
    } catch (_) {
      // On error treat as "no active access" (fail closed).
    }

    _accessCache[uid] = (at: DateTime.now(), roles: roles);
    return roles;
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

    // Owner-only routes (a manager must NOT open these, even with active access)
    final isOwnerExclusiveRoute =
        path == RouteNames.addProperty ||
            path == RouteNames.addManager ||
            path == RouteNames.ownerTeam ||
            RegExp(r'^/owner/properties/[^/]+/edit$').hasMatch(path);

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

      // Roles with an ACTIVE assignment right now (suspended / revoked excluded).
      final activeAccess = await _activeAccessRoles(firebaseUser.uid);
      final hasActiveManager = activeAccess.contains('manager');

      final destination = AuthRoleResolver.resolve(profile);
      final defaultFallbackRoute = AuthDestinationMapper.routeFor(destination);

      // 1) Owner-only routes
      if (isOwnerExclusiveRoute) {
        if (roles.contains('owner')) return null;
        return hasActiveManager ? RouteNames.managerHome : defaultFallbackRoute;
      }

      // 2) /owner and /owner/*  -> owner, or a manager with ACTIVE access
      if (isOwnerSection) {
        if (path == RouteNames.ownerHome) {
          if (roles.contains('owner')) return null;
          return hasActiveManager
              ? RouteNames.managerHome
              : defaultFallbackRoute;
        }
        if (roles.contains('owner') || hasActiveManager) return null;
        return defaultFallbackRoute;
      }

      // 3) /manager  -> manager role (needed to accept invitations / see suspended state)
      if (isManagerSection) {
        return (roles.contains('manager') || hasActiveManager)
            ? null
            : defaultFallbackRoute;
      }

      // 4) /tenant
      if (isTenantSection) {
        return roles.contains('tenant') ? null : defaultFallbackRoute;
      }

      // 5) Staff dashboards (role needed to accept invitations; data is
      //    protected by Firestore rules, which require ACTIVE staffAccess)
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
