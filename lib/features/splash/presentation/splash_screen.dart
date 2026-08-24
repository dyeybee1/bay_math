import 'package:flutter/material.dart';

/// Placeholder-in-name-only now: this screen no longer drives navigation
/// itself (Phase 0's fixed-timer redirect is gone). It's purely what's
/// shown while `sessionProvider` resolves the restored session on startup —
/// the router's redirect (app_router.dart) moves away from here entirely
/// on its own once that resolution completes, via RouterRefreshListenable.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.calculate_outlined, size: 64, color: colors.primary),
            const SizedBox(height: 16),
            Text(
              'BAYMATH',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
