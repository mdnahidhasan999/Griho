import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/auth_destination_mapper.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../auth/presentation/controllers/auth_role_resolver.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  Future<void> _checkAuthentication() async {
    if (_checking) {
      return;
    }

    _checking = true;

    try {
      debugPrint('SPLASH: Checking authentication...');

      final repository = ref.read(authRepositoryProvider);
      final firebaseUser = repository.currentUser;

      if (!mounted) {
        return;
      }

      if (firebaseUser == null) {
        debugPrint('SPLASH: No authenticated user');

        context.go(RouteNames.login);
        return;
      }

      debugPrint(
        'SPLASH: Firebase user found: ${firebaseUser.uid}',
      );

      final profile = await ref
          .read(userProfileRepositoryProvider)
          .getUserByUid(firebaseUser.uid);

      if (!mounted) {
        return;
      }

      if (profile == null) {
        debugPrint(
          'SPLASH: User profile not found. Going to onboarding.',
        );

        context.go(RouteNames.onboarding);
        return;
      }

      debugPrint(
        'SPLASH: Profile found: ${profile.publicId}',
      );

      debugPrint(
        'SPLASH: User role: ${profile.role}',
      );

      final destination = AuthRoleResolver.resolve(
        profile.role,
      );

      final route = AuthDestinationMapper.routeFor(
        destination,
      );

      debugPrint(
        'SPLASH: Destination = $destination',
      );

      debugPrint(
        'SPLASH: Navigating to $route',
      );

      context.go(route);
    } catch (error, stackTrace) {
      debugPrint(
        'SPLASH ERROR: $error',
      );

      debugPrint(
        'SPLASH STACK: $stackTrace',
      );

      if (!mounted) {
        return;
      }

      context.go(RouteNames.login);
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.home_rounded,
                size: 42,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'GriHo',
              style: AppTextStyles.headlineLarge,
            ),

            const SizedBox(height: 6),

            const Text(
              'Manage Every Home',
              style: AppTextStyles.bodyMedium,
            ),

            const SizedBox(height: 24),

            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}