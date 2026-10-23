import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/navigation/app_bottom_navigation.dart';

class CaretakerHomeScreen extends StatelessWidget {
  const CaretakerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Griho Caretaker'),
        centerTitle: false,
      ),
      body: const Center(
        child: Text('Caretaker Home'),
      ),
      bottomNavigationBar: AppBottomNavigation(
        selectedDestination: GrihoNavigationDestination.home,
        onHomeTap: () {
          context.go(RouteNames.caretakerHome);
        },
        onMoreTap: () {
          context.go(RouteNames.more);
        },
      ),
    );
  }
}