import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/app_routes.dart';

enum PasswordRecoveryStatus { none, valid, invalid, completed }

/// Captured before Supabase initialization clears auth parameters from a web
/// callback URL. The bootstrap override is the durable proof that this browser
/// session came from a recovery link rather than an ordinary staff sign-in.
final Provider<PasswordRecoveryStatus> passwordRecoveryBootstrapProvider =
    Provider<PasswordRecoveryStatus>((Ref ref) => PasswordRecoveryStatus.none);

class PasswordRecoveryNotifier extends Notifier<PasswordRecoveryStatus> {
  @override
  PasswordRecoveryStatus build() =>
      ref.watch(passwordRecoveryBootstrapProvider);

  void markCompleted() => state = PasswordRecoveryStatus.completed;
}

final NotifierProvider<PasswordRecoveryNotifier, PasswordRecoveryStatus>
passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, PasswordRecoveryStatus>(
      PasswordRecoveryNotifier.new,
    );

/// Parses only the minimum fields needed to classify the initial callback.
/// Token values are never stored, logged, or exposed to application widgets.
PasswordRecoveryStatus passwordRecoveryStatusFromInitialUri(
  Uri uri, {
  required bool hasSessionAfterSupabaseInitialization,
}) {
  if (uri.path != AppRoutes.resetPassword) {
    return PasswordRecoveryStatus.none;
  }

  final Map<String, String> parameters = <String, String>{
    ...uri.queryParameters,
    ..._fragmentParameters(uri.fragment),
  };
  if (parameters.containsKey('error') ||
      parameters.containsKey('error_code') ||
      parameters.containsKey('error_description')) {
    return PasswordRecoveryStatus.invalid;
  }

  final bool isRecovery = parameters['type'] == 'recovery';
  final bool hasImplicitTokens =
      parameters.containsKey('access_token') &&
      parameters.containsKey('refresh_token');
  return isRecovery &&
          hasImplicitTokens &&
          hasSessionAfterSupabaseInitialization
      ? PasswordRecoveryStatus.valid
      : PasswordRecoveryStatus.invalid;
}

Map<String, String> _fragmentParameters(String fragment) {
  if (fragment.isEmpty || fragment.startsWith('/')) {
    return const <String, String>{};
  }
  try {
    return Uri.splitQueryString(fragment);
  } on FormatException {
    return const <String, String>{};
  }
}
