// noinspection SpellCheckingInspection
import 'package:flutter/material.dart';

// noinspection SpellCheckingInspection
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/design_system/design_system.dart';
import 'router/app_router_provider.dart';

typedef AppRouter = GoRouter;

class GrihoApp extends ConsumerWidget {
  const GrihoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppRouter router = ref.watch(appRouterProvider);
    final ThemeMode themeMode = ref.watch(grihoThemeModeProvider);

    return MaterialApp.router(
      title: 'Griho',
      debugShowCheckedModeBanner: false,
      theme: GrihoTheme.light(),
      darkTheme: GrihoTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
