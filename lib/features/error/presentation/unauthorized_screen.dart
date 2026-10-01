import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/widgets/widgets.dart';

/// Recovery screen for a signed-in staff account without workspace access.
class UnauthorizedScreen extends ConsumerStatefulWidget {
  const UnauthorizedScreen({super.key});

  @override
  ConsumerState<UnauthorizedScreen> createState() => _UnauthorizedScreenState();
}

class _UnauthorizedScreenState extends ConsumerState<UnauthorizedScreen> {
  bool _isSigningOut = false;
  String? _errorText;

  Future<void> _signOutAndReturnToLogin() async {
    if (_isSigningOut) return;

    setState(() {
      _isSigningOut = true;
      _errorText = null;
    });

    try {
      await ref.read(sessionProvider.notifier).signOut();
      if (mounted) context.go(AppRoutes.login);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _errorText = failure.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _errorText = 'We could not sign you out. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AppCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 36,
                        color: colors.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Access Denied',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your account does not have permission to open this '
                      'area. Sign out to return to the staff login and use '
                      'an authorized account.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    if (_errorText != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.md),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorText!,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      key: const Key('unauthorized_sign_out_button'),
                      label: 'Sign Out and Return to Login',
                      leadingIcon: Icons.logout_rounded,
                      isLoading: _isSigningOut,
                      isFullWidth: true,
                      onPressed:
                          _isSigningOut ? null : _signOutAndReturnToLogin,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
