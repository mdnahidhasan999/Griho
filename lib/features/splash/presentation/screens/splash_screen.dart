import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

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
          ],
        ),
      ),
    );
  }
}