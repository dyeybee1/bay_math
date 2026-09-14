import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/password_recovery_provider.dart';
import 'app.dart';
import 'app_variant.dart';
import 'config/env_config.dart';
import 'config/supabase_config.dart';

/// Performs the startup work shared by every BayMath native variant.
Future<void> bootstrapApp(AppVariant variant) async {
  WidgetsFlutterBinding.ensureInitialized();

  final Uri initialUri = Uri.base;
  usePathUrlStrategy();

  if (variant == AppVariant.student) {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  await EnvConfig.load();
  await SupabaseConfig.initialize();

  final PasswordRecoveryStatus passwordRecoveryStatus =
      passwordRecoveryStatusFromInitialUri(
        initialUri,
        hasSessionAfterSupabaseInitialization:
            Supabase.instance.client.auth.currentSession != null,
      );

  runApp(
    ProviderScope(
      overrides: [
        appVariantProvider.overrideWithValue(variant),
        passwordRecoveryBootstrapProvider.overrideWithValue(
          passwordRecoveryStatus,
        ),
      ],
      child: const App(),
    ),
  );
}
