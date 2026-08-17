import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  Future<void> _checkAuthentication() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = repository.currentUser;

      if (!mounted) {
        return;
      }

      if (user == null) {
        context.go(RouteNames.login);
        return;
      }

      final profile = await ref.read(
        userProfileRepositoryProvider,
      ).getUserByUid(user.uid);

      if (!mounted) {
        return;
      }

      if (profile == null) {
        context.go(RouteNames.onboarding);
        return;
      }

      // Existing-user destination will be connected
      // after role-based dashboard and membership flow.
    } catch (error) {
      debugPrint('Splash authentication check failed: $error');

      if (!mounted) {
        return;
      }

      context.go(RouteNames.login);
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