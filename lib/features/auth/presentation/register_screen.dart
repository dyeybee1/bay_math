import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/widgets/widgets.dart';

/// Teacher self-registration. Always produces `role='teacher',
/// status='pending'` — never anything else, enforced at the database layer
/// (0019), not just by this form. A successful registration lands the new
/// account on the pending-approval screen via the router's normal redirect,
/// since the new session's profile will resolve to `SessionTeacher` with
/// `status: pending`.
///
/// Visually this mirrors [LoginScreen]'s two-column brand layout —
/// same `baymath_login_bg_left`/`baymath_login_bg_right` background
/// assets, same brand panel content/proportions — so registration reads
/// as one continuous experience with login rather than a different screen.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
  String? _errorText;

  // --- Brand palette used only on this screen -----------------------------
  // Kept identical to LoginScreen's — this is the same brand/marketing
  // moment, just the registration half of it.
  static const Color _brandBlue = Color(0xFF1B4FE0);
  static const Color _brandGold = Color(0xFFFFC93C);
  static const Color _navyText = Color(0xFF13214A);

  /// Below this width the brand panel no longer has room to breathe next
  /// to a usable form — same breakpoint as [LoginScreen].
  static const double _wideBreakpoint = 900;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String fullName = _fullNameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Fill in every field.');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorText = 'Password must be at least 8 characters.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorText = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(authRepositoryProvider)
          .signUpTeacher(email: email, password: password, fullName: fullName);
      // signUp() already establishes a session, but that happens before the
      // profiles row exists — force sessionProvider to re-resolve now that
      // both exist, rather than relying only on the auth-state-change event
      // (which fired before the insert completed).
      ref.read(sessionProvider.notifier).refresh();
    } on AppFailure catch (failure) {
      setState(() => _errorText = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------
  // Shared registration card content (icon, heading, fields, submit,
  // login link). Identical on both the wide and compact layouts — only
  // the surrounding chrome (brand panel, background) differs.
  // ---------------------------------------------------------------------
  Widget _buildCard(BuildContext context, bool sessionResolving) {
    final bool disabled = _isSubmitting || sessionResolving;
    final bool passwordTooShort =
        _passwordController.text.isNotEmpty &&
        _passwordController.text.length < 8;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xFFE3EEFF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_ind_rounded,
                color: _brandBlue,
                size: 24,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Create your teacher account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _navyText,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                'Your account will need Admin approval before you can sign in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          AppTextField(
            controller: _fullNameController,
            label: 'Full name',
            prefixIcon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
            enabled: !disabled,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _emailController,
            label: 'Email',
            prefixIcon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !disabled,
          ),
          const SizedBox(height: 10),
          AppTextField(
            controller: _passwordController,
            type: AppTextFieldType.password,
            label: 'Password',
            prefixIcon: Icons.lock_outline_rounded,
            textInputAction: TextInputAction.next,
            enabled: !disabled,
            onChanged: (_) => setState(() {}),
          ),
          // Only takes up space once the requirement is actually
          // unmet — stays out of the way otherwise, per your last ask,
          // but sits tight against the field (like the reference) when
          // it does show.
          if (passwordTooShort) ...<Widget>[
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'At least 8 characters.',
                style: TextStyle(fontSize: 12, color: Color(0xFF8A93A6)),
              ),
            ),
          ],
          const SizedBox(height: 10),
          AppTextField(
            controller: _confirmPasswordController,
            type: AppTextFieldType.password,
            label: 'Confirm password',
            prefixIcon: Icons.lock_outline_rounded,
            textInputAction: TextInputAction.done,
            enabled: !disabled,
            onSubmitted: (_) => _submit(),
            errorText: _errorText,
          ),
          const SizedBox(height: 18),
          AppButton(
            label: 'Create Account',
            trailingIcon: Icons.arrow_forward_rounded,
            isFullWidth: true,
            isLoading: disabled,
            onPressed: disabled ? null : _submit,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                children: <InlineSpan>[
                  const TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Log in',
                    style: const TextStyle(
                      color: _brandBlue,
                      fontWeight: FontWeight.w700,
                    ),
                    recognizer:
                        TapGestureRecognizer()
                          ..onTap = disabled ? null : () => context.pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Rounded-square icon + caption used in the three feature callouts on
  /// the wide layout's brand panel — same visual treatment as
  /// [LoginScreen]'s feature badges.
  Widget _buildFeatureBadge({required IconData icon, required String label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 88,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  /// Left-hand brand panel. Background is the app's own
  /// `baymath_login_bg_left.png` asset — the exact same file
  /// [LoginScreen] uses, so both screens share one background.
  Widget _buildBrandPanel(BuildContext context) {
    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        FractionallySizedBox(
          widthFactor: 0.58,
          child: Image.asset('assets/images/baymath_logo_for_login.png'),
        ),
        const SizedBox(height: 10),
        const Text.rich(
          TextSpan(
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
            children: <InlineSpan>[
              TextSpan(text: 'Teach. Inspire. '),
              TextSpan(text: 'Empower.', style: TextStyle(color: _brandGold)),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            'Join BAYMATH and be part of a community dedicated to '
            'making mathematics learning exciting and effective.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            _buildFeatureBadge(
              icon: Icons.people_alt_rounded,
              label: 'Connect\nwith Students',
            ),
            _buildFeatureBadge(
              icon: Icons.show_chart_rounded,
              label: 'Track\nProgress',
            ),
            _buildFeatureBadge(
              icon: Icons.lightbulb_rounded,
              label: 'Make an\nImpact',
            ),
          ],
        ),
      ],
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          'assets/images/baymath_login_bg_left.png',
          fit: BoxFit.cover,
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Center(child: content),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Right-hand registration panel. Background is the app's own
  /// `baymath_login_bg_right.png` asset — again, the same file
  /// [LoginScreen] uses (dot-grids, wave, books/pencil-cup illustration).
  Widget _buildRegisterPanel(BuildContext context, bool sessionResolving) {
    final Widget content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: _buildCard(context, sessionResolving),
    );

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          'assets/images/baymath_login_bg_right.png',
          fit: BoxFit.cover,
        ),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Center(child: content),
              ),
            );
          },
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
          child: _buildCard(context, sessionResolving),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool sessionResolving = ref.watch(sessionProvider).isLoading;
    final bool disabled = _isSubmitting || sessionResolving;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Teacher Registration',
          style: TextStyle(color: _navyText, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _navyText),
          onPressed: disabled ? null : () => context.pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool isWide = constraints.maxWidth >= _wideBreakpoint;
          if (!isWide) {
            return _buildCompactLayout(context, sessionResolving);
          }

          // Same 45/55 brand/form split as LoginScreen, so the two
          // screens' backgrounds line up when a user goes back and forth.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Expanded(flex: 45, child: _buildBrandPanel(context)),
              Expanded(
                flex: 55,
                child: _buildRegisterPanel(context, sessionResolving),
              ),
            ],
          );
        },
      ),
    );
  }
}
