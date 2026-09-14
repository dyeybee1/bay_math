import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/session_provider.dart';
import '../../core/providers/password_recovery_provider.dart';

/// GoRouter is not Riverpod-aware natively. In the staff variant, this adapter
/// makes a [sessionProvider] change (login, logout, expiry, approval status
/// change) cause an immediate redirect re-evaluation.
class RouterRefreshListenable extends ChangeNotifier {
  RouterRefreshListenable(Ref ref) {
    _sessionSubscription = ref.listen<AsyncValue<SessionState>>(
      sessionProvider,
      (previous, next) => notifyListeners(),
    );
    _recoverySubscription = ref.listen<PasswordRecoveryStatus>(
      passwordRecoveryProvider,
      (previous, next) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AsyncValue<SessionState>>
  _sessionSubscription;
  late final ProviderSubscription<PasswordRecoveryStatus> _recoverySubscription;

  @override
  void dispose() {
    _sessionSubscription.close();
    _recoverySubscription.close();
    super.dispose();
  }
}

/// A stable, single instance for the whole app's lifetime — watching this
/// provider never causes [appRouterProvider] to rebuild, since the
/// [RouterRefreshListenable] object identity never changes after creation;
/// only its internal notifications do.
final Provider<RouterRefreshListenable> routerRefreshListenableProvider =
    Provider<RouterRefreshListenable>((ref) {
      final RouterRefreshListenable listenable = RouterRefreshListenable(ref);
      ref.onDispose(listenable.dispose);
      return listenable;
    });
