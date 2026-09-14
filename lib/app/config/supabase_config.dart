import 'package:supabase_flutter/supabase_flutter.dart';

import 'env_config.dart';

/// Bootstraps the Supabase client for the app.
///
/// Phase 0 scope: initialization only.
/// Deliberately excluded (left for later phases): auth flows, database
/// queries, realtime subscriptions, storage, and RLS-dependent logic.
class SupabaseConfig {
  const SupabaseConfig._();

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      publishableKey: EnvConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        // The password-reset request starts in a portable Windows process but
        // completes in a separate browser storage context. PKCE's verifier is
        // intentionally device-local, so it cannot cross that boundary. The
        // supported implicit recovery flow places short-lived credentials in
        // the URL fragment, which Supabase Flutter consumes and clears.
        authFlowType: AuthFlowType.implicit,
      ),
    );
  }
}
