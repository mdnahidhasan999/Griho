import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Griho Hme'), centerTitle: false),
      body: const Center(child: Text('Manager Home')),
      bottomNavigationBar: AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
        onHomeTap: () {
          context.go(RouteNames.managerHome);
        },
        onMoreTap: () {
          context.go(RouteNames.more);
        },
      ),
    );
  }
}
