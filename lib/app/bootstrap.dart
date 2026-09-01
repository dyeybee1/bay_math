import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'app_variant.dart';
import 'config/env_config.dart';
import 'config/supabase_config.dart';

/// Performs the startup work shared by every BayMath native variant.
Future<void> bootstrapApp(AppVariant variant) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (variant == AppVariant.student) {
    await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  await EnvConfig.load();
  await SupabaseConfig.initialize();

  runApp(
    ProviderScope(
      overrides: [appVariantProvider.overrideWithValue(variant)],
      child: const App(),
    ),
  );
}
