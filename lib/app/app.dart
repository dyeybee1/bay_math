import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_variant.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Root application widget. Purely a shell: theme + router.
/// Routing/redirect logic lives entirely in app_router.dart — this widget
/// only wires the resolved GoRouter instance into MaterialApp.router.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppVariant variant = ref.watch(appVariantProvider);
    final GoRouter router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: switch (variant) {
        AppVariant.student => 'BayMath Student',
        AppVariant.staff => 'BayMath Teacher/Admin',
      },
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
