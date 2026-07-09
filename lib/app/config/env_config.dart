import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed, fail-fast access to the values loaded from the `.env` file.
///
/// This class does not read files or perform any I/O itself — it only
/// reads from [dotenv.env] after [EnvConfig.load] has been awaited once
/// at app startup (see `main.dart`). Keeping this indirection means the
/// rest of the app never imports `flutter_dotenv` directly.
class EnvConfig {
  const EnvConfig._();

  static const String _envFileName = '.env';

  /// Loads the `.env` file into memory. Must be awaited before any other
  /// getter on this class is used (done once, in `main.dart`).
  static Future<void> load() async {
    await dotenv.load(fileName: _envFileName);
  }

  static String get supabaseUrl => _require('SUPABASE_URL');

  static String get supabaseAnonKey => _require('SUPABASE_ANON_KEY');

  static String _require(String key) {
    final String? value = dotenv.env[key];
    if (value == null || value.isEmpty) {
      throw StateError(
        'Missing required environment variable "$key". '
        'Copy .env.example to .env and fill in your Supabase project '
        'credentials before running the app.',
      );
    }
    return value;
  }
}
