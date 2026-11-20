// noinspection SpellCheckingInspection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/controllers/auth_role_resolver.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'auth_destination_mapper.dart';
import 'route_names.dart';

class AuthRouteGuard {
  final Ref ref;

  const AuthRouteGuard(this.ref);

  static final Map<String, ({DateTime at, Set<String> roles})> _accessCache =
      {};
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
      // Fail closed on error.
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

    // Owner-only routes (aligned with firestore.rules)
    final isOwnerExclusiveRoute =
        path == RouteNames.addProperty ||
        path == RouteNames.addManager ||
        path == RouteNames.ownerTeam ||
        RegExp(r'^/owner/properties/[^/]+/edit$').hasMatch(path) ||
        RegExp(r'^/owner/properties/[^/]+/units/add$').hasMatch(path);

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
      return RouteNames.login;
    }

    if (isLoginRoute || isLinkWaitingRoute) {
      return RouteNames.splash;
    }

    final userProfileRepository = ref.read(userProfileRepositoryProvider);
    final profile = await userProfileRepository.getUserByUid(firebaseUser.uid);

    if (isOnboardingRoute) {
      if (profile == null) {
        return null;
      }

      final phoneNumber = profile.phoneNumber?.trim() ?? '';
      if (phoneNumber.isEmpty) {
        return null;
      }

      final destination = AuthRoleResolver.resolve(profile);
      return AuthDestinationMapper.routeFor(destination);
    }

    // Enforce completed profile & phone number for ALL authenticated routes
    if (profile == null || (profile.phoneNumber?.trim() ?? '').isEmpty) {
      return RouteNames.onboarding;
    }

    if (isRoleSelectionRoute) {
      final destination = AuthRoleResolver.resolve(profile);
      if (destination == AuthUserDestination.roleSelection) {
        return null;
      }
      return AuthDestinationMapper.routeFor(destination);
    }

    final roles = profile.availableRoles
        .map((role) => role.trim().toLowerCase())
        .toSet();

    if (isOwnerWelcomeRoute) {
      if (!roles.contains('owner')) {
        final destination = AuthRoleResolver.resolve(profile);
        if (destination == AuthUserDestination.roleSelection) {
          return RouteNames.roleSelection;
        }
        return AuthDestinationMapper.routeFor(destination);
      }
      return null;
    }

    if (isProtectedSection) {
      final activeAccess = await _activeAccessRoles(firebaseUser.uid);
      final hasActiveManager = activeAccess.contains('manager');

      final destination = AuthRoleResolver.resolve(profile);
      final defaultFallbackRoute = AuthDestinationMapper.routeFor(destination);

      // 1) Owner-only routes
      if (isOwnerExclusiveRoute) {
        if (roles.contains('owner')) return null;
        return hasActiveManager ? RouteNames.managerHome : defaultFallbackRoute;
      }

      // 2) /owner and /owner/* -> owner, or a manager with ACTIVE access
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

      // 3) /manager
      if (isManagerSection) {
        return (roles.contains('manager') || hasActiveManager)
            ? null
            : defaultFallbackRoute;
      }

      // 4) /tenant
      if (isTenantSection) {
        return roles.contains('tenant') ? null : defaultFallbackRoute;
      }

      // 5) Caretaker & Electrician
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
