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

  /// Public, hosted Flutter Web route used by Supabase Auth recovery emails.
  /// This is configuration, not a secret. It remains optional at bootstrap so
  /// Student builds and staff sign-in still start before deployment is wired;
  /// the Forgot Password screen fails safely when it is absent.
  static String? get staffPasswordResetRedirectUrl {
    final String? value =
        dotenv.env['STAFF_PASSWORD_RESET_REDIRECT_URL']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

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
