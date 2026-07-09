import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/config/env_config.dart';
import 'app/config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (SUPABASE_URL / SUPABASE_ANON_KEY) before
  // anything else needs them.
  await EnvConfig.load();

  // Initialize Supabase only — no queries, no auth calls, no schema.
  await SupabaseConfig.initialize();

  runApp(const ProviderScope(child: App()));
}
