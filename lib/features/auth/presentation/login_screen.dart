import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../../app/constants/app_spacing.dart';

/// Unified Teacher/Admin login. Both roles authenticate identically via
/// Supabase Auth — which one signed in (and, for a Teacher, whether they're
/// approved yet) is resolved from `profiles` by [sessionProvider] after
/// sign-in, then the router redirects accordingly. This screen never makes
/// that decision itself.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

  // --- Brand palette used only on this screen -----------------------------
  // The rest of the app deliberately uses a muted blue (see AppColors'
  // doc comment). This screen is a brand/marketing moment though — it's
  // built to match the BAYMATH reference design pixel-for-pixel, which
  // uses a vivid royal blue + gold, not the muted in-app palette.
  static const Color _brandBlue = Color(0xFF1B4FE0);
  static const Color _brandGold = Color(0xFFFFC93C);

  /// Below this width the two-column brand panel no longer has room to
  /// breathe next to a usable form, so we fall back to a single column.
  static const double _wideBreakpoint = 900;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Enter your email and password.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signInWithPassword(email: email, password: password);
      // Don't rely solely on the auth-state-change stream event to update
      // sessionProvider — on Flutter Web that event has proven unreliable
      // to arrive promptly (the same class of issue register_screen.dart
      // already works around). Force an explicit re-resolve so the router's
      // reactive redirect actually has a resolved session to react to.
      ref.read(sessionProvider.notifier).refresh();
    } on AppFailure catch (failure) {
      setState(() => _errorText = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------
  // Shared form (email, password, log in, or-divider, register link).
  // Identical widget tree/behavior on both the wide and compact layouts —
  // only the surrounding chrome differs.
  // ---------------------------------------------------------------------
  Widget _buildForm(BuildContext context, bool sessionResolving) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool disabled = _isSubmitting || sessionResolving;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppTextField(
          controller: _emailController,
          label: 'Email',
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          enabled: !disabled,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: _passwordController,
          type: AppTextFieldType.password,
          label: 'Password',
          prefixIcon: Icons.lock_outline_rounded,
          textInputAction: TextInputAction.done,
          enabled: !disabled,
          onSubmitted: (_) => _submit(),
          errorText: _errorText,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Log In',
          trailingIcon: Icons.arrow_forward_rounded,
          isFullWidth: true,
          isLoading: disabled,
          onPressed: disabled ? null : _submit,
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: <Widget>[
            Expanded(child: Divider(color: colorScheme.outlineVariant)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Text(
                'or',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(child: Divider(color: colorScheme.outlineVariant)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          "Don't have an account?",
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        Center(
          child: AppButton(
            label: 'Register as a Teacher',
            trailingIcon: Icons.arrow_forward_rounded,
            variant: AppButtonVariant.text,
            onPressed: disabled ? null : () => context.push(AppRoutes.register),
          ),
        ),
      ],
    );
  }

  /// Rounded-square icon + caption used in the three feature callouts on
  /// the wide layout's brand panel ("Interactive Lessons", etc).
  Widget _buildFeatureBadge({required IconData icon, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 92,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }

  /// Left-hand brand panel. Background is the app's own
  /// `baymath_login_bg_left.png` asset (a straight crop of the blue half
  /// of the original combined reference background — same math-symbol
  /// pattern, not a redrawn one), with the BAYMATH lockup, headline,
  /// supporting copy, and the three feature callouts on top.
  Widget _buildBrandPanel(BuildContext context) {
    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 640),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          FractionallySizedBox(
            widthFactor: 0.72,
            child: Image.asset('assets/images/baymath_logo_for_login.png'),
          ),
          const SizedBox(height: 28),
          const Text.rich(
            TextSpan(
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.15,
              ),
              children: <InlineSpan>[
                TextSpan(text: 'Learn. Practice. '),
                TextSpan(text: 'Master.', style: TextStyle(color: _brandGold)),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(
              'Empowering teachers and students to achieve more '
              'in mathematics through e-learning.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 15,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              _buildFeatureBadge(
                icon: Icons.menu_book_rounded,
                label: 'Explore\nLessons',
              ),
              _buildFeatureBadge(
                icon: Icons.show_chart_rounded,
                label: 'Track\nProgress',
              ),
              _buildFeatureBadge(
                icon: Icons.emoji_events_rounded,
                label: 'Achieve\nExcellence',
              ),
            ],
          ),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          'assets/images/baymath_login_bg_left.png',
          fit: BoxFit.cover,
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 32),
          child: content,
        ),
      ],
    );
  }

  /// Right-hand sign-in panel. Background is the app's own
  /// `baymath_login_bg_right.png` asset (a straight crop of the white
  /// half of the original combined reference background — the same
  /// corner dot-grids, wave, and books/pencil-cup illustration, not
  /// redrawn), with the heading, subtitle, and [AppCard] on top.
  Widget _buildSignInPanel(BuildContext context, bool sessionResolving) {
    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'Welcome back!',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF13214A),
                  height: 1.1,
                ),
              ),
              const SizedBox(width: 6),
              Transform.rotate(
                angle: -0.35,
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: _brandGold,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text.rich(
            TextSpan(
              style: TextStyle(fontSize: 15, color: Color(0xFF5B6270)),
              children: <InlineSpan>[
                TextSpan(text: 'Log in to your '),
                TextSpan(
                  text: 'BAYMATH',
                  style: TextStyle(
                    color: _brandBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(text: ' account'),
              ],
            ),
          ),
          const SizedBox(height: 40),
          AppCard(
            padding: const EdgeInsets.all(32),
            child: _buildForm(context, sessionResolving),
          ),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          'assets/images/baymath_login_bg_right.png',
          fit: BoxFit.cover,
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
          child: Center(child: content),
        ),
      ],
    );
  }

  /// Narrow-viewport fallback: a single centered card, no room for the
  /// brand panel — used below [_wideBreakpoint].
  Widget _buildCompactLayout(BuildContext context, bool sessionResolving) {
    return AppPageContainer(
      scrollable: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Image.asset(
                  'assets/images/baymath_logo.png',
                  height: 56,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                size: AppComponentSize.large,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Welcome back!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Log in to your BAYMATH account',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildForm(context, sessionResolving),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Once sign-in succeeds, sessionProvider goes back into a loading state
    // while it resolves the profile — keep the screen showing a spinner
    // through that window instead of flickering back to the idle form.
    final bool sessionResolving = ref.watch(sessionProvider).isLoading;

    return Scaffold(
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isWide = constraints.maxWidth >= _wideBreakpoint;
          if (!isWide) {
            return _buildCompactLayout(context, sessionResolving);
          }

          // Straight vertical split, 45% brand panel / 55% sign-in panel —
          // matches the reference exactly, no wavy/curved divider between
          // the two halves.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: 45, child: _buildBrandPanel(context)),
              Expanded(
                flex: 55,
                child: _buildSignInPanel(context, sessionResolving),
              ),
            ],
          );
        },
      ),
    );
  }
}
