import 'package:flutter/material.dart';

enum GrihoNavigationDestination { home, more }

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedDestination,
    required this.onHomeTap,
    required this.onMoreTap,
  });

  final GrihoNavigationDestination selectedDestination;
  final VoidCallback onHomeTap;
  final VoidCallback onMoreTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedDestination.index,
      onDestinationSelected: (index) {
        switch (GrihoNavigationDestination.values[index]) {
          case GrihoNavigationDestination.home:
            onHomeTap();
            break;
          case GrihoNavigationDestination.more:
            onMoreTap();
            break;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_vert_rounded),
          label: 'More',
        ),
      ],
    );
  }
}
