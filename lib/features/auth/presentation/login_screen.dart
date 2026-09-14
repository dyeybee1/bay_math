import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import 'widgets/auth_presentation.dart';

/// Unified Teacher/Admin login. Both roles authenticate identically via
/// Supabase Auth. The signed-in role and Teacher approval status are resolved
/// by [sessionProvider], then the router redirects accordingly. This screen
/// deliberately remains presentation-only and never makes that decision.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorText;

  static const double _twoColumnBreakpoint = 860;
  static const double _maxShellWidth = 1180;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Enter your email and password.');
      if (email.isEmpty) {
        _emailFocusNode.requestFocus();
      } else {
        _passwordFocusNode.requestFocus();
      }
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
      // Keep the existing explicit refresh: the auth-state-change stream can
      // arrive late on Flutter Web, while routing needs the resolved profile.
      ref.read(sessionProvider.notifier).refresh();
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _errorText = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // After successful authentication the provider resolves the account role.
    // Keep the form disabled and visibly loading through that transition.
    final bool sessionResolving = ref.watch(sessionProvider).isLoading;
    final bool disabled = _isSubmitting || sessionResolving;

    return Scaffold(
      backgroundColor: AuthPalette.canvas,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool useTwoColumns =
                  constraints.maxWidth >= _twoColumnBreakpoint;
              final bool compactHeight = constraints.maxHeight < 780;
              final double horizontalInset = switch (constraints.maxWidth) {
                >= 1440 => AppSpacing.xxl,
                >= 1024 => AppSpacing.xl,
                _ => AppSpacing.md,
              };
              final double verticalInset =
                  compactHeight ? AppSpacing.md : AppSpacing.xl;
              final double minimumHeight = (constraints.maxHeight -
                      (verticalInset * 2))
                  .clamp(0, double.infinity);
              final double shellHeight =
                  compactHeight
                      ? minimumHeight.clamp(620, 680)
                      : minimumHeight.clamp(680, 720);

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalInset,
                  vertical: verticalInset,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minimumHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _maxShellWidth,
                      ),
                      child: _buildShell(
                        context,
                        disabled: disabled,
                        useTwoColumns: useTwoColumns,
                        compactHeight: compactHeight,
                        shellHeight: shellHeight,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildShell(
    BuildContext context, {
    required bool disabled,
    required bool useTwoColumns,
    required bool compactHeight,
    required double shellHeight,
  }) {
    final Widget accessPanel = _AccessPanel(
      emailController: _emailController,
      passwordController: _passwordController,
      emailFocusNode: _emailFocusNode,
      passwordFocusNode: _passwordFocusNode,
      disabled: disabled,
      isSubmitting: disabled,
      obscurePassword: _obscurePassword,
      errorText: _errorText,
      compactHeight: compactHeight,
      onSubmit: _submit,
      onTogglePassword: () {
        setState(() => _obscurePassword = !_obscurePassword);
      },
      onForgotPassword: () => context.push(AppRoutes.forgotPassword),
      onRegister: () => context.push(AppRoutes.register),
    );

    final Widget content =
        useTwoColumns
            ? SizedBox(
              height: shellHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(flex: 57, child: accessPanel),
                  const Expanded(flex: 43, child: _WorkspacePanel()),
                ],
              ),
            )
            : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[accessPanel, const _CompactWorkspacePanel()],
            );

    return AuthShellSurface(child: content);
  }
}

class _AccessPanel extends StatelessWidget {
  const _AccessPanel({
    required this.emailController,
    required this.passwordController,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.disabled,
    required this.isSubmitting,
    required this.obscurePassword,
    required this.errorText,
    required this.compactHeight,
    required this.onSubmit,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onRegister,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final bool disabled;
  final bool isSubmitting;
  final bool obscurePassword;
  final String? errorText;
  final bool compactHeight;
  final VoidCallback onSubmit;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final double verticalPadding = compactHeight ? AppSpacing.lg : 40;
    final double sectionGap = compactHeight ? 18 : AppSpacing.lg;

    final EdgeInsets panelPadding = EdgeInsets.symmetric(
      horizontal: compactHeight ? AppSpacing.xl : 52,
      vertical: verticalPadding,
    );
    final Widget formContent = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 470),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                AuthBrandLogo(width: compactHeight ? 174 : 190),
                SizedBox(height: compactHeight ? 20 : AppSpacing.xl),
                const Text(
                  'TEACHER & ADMINISTRATOR ACCESS',
                  style: TextStyle(
                    color: AuthPalette.primaryMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Welcome back',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: AuthPalette.ink,
                    fontSize: compactHeight ? 30 : 34,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Sign in to your BayMath workspace to support teaching, '
                  'learning, and school operations.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: sectionGap),
                const AuthFieldLabel(label: 'Email address'),
                const SizedBox(height: AppSpacing.sm),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: AuthTextField(
                    key: const Key('login_email_field'),
                    controller: emailController,
                    focusNode: emailFocusNode,
                    enabled: !disabled,
                    hintText: 'name@school.edu',
                    semanticLabel: 'Email address',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[
                      AutofillHints.username,
                      AutofillHints.email,
                    ],
                    onSubmitted: (_) => passwordFocusNode.requestFocus(),
                  ),
                ),
                SizedBox(height: compactHeight ? 14 : AppSpacing.md),
                const AuthFieldLabel(label: 'Password'),
                const SizedBox(height: AppSpacing.sm),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: AuthTextField(
                    key: const Key('login_password_field'),
                    controller: passwordController,
                    focusNode: passwordFocusNode,
                    enabled: !disabled,
                    hintText: 'Enter your password',
                    semanticLabel: 'Password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: obscurePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.password],
                    suffix: AuthPasswordVisibilityButton(
                      key: const Key('login_password_visibility'),
                      obscurePassword: obscurePassword,
                      enabled: !disabled,
                      onPressed: onTogglePassword,
                    ),
                    onSubmitted: (_) => onSubmit(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                AuthFormNotice(
                  key:
                      errorText == null
                          ? null
                          : const Key('login_error_message'),
                  guidance: 'Use your Teacher or Administrator account.',
                  errorText: errorText,
                ),
                SizedBox(height: compactHeight ? 14 : 18),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(3),
                  child: AuthPrimaryButton(
                    key: const Key('login_submit_button'),
                    label: 'Sign in to workspace',
                    loadingLabel: 'Signing in…',
                    isLoading: isSubmitting,
                    onPressed: disabled ? null : onSubmit,
                  ),
                ),
                SizedBox(height: compactHeight ? 14 : AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE3E9EE))),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _AccountActionRow(
                        prompt: 'Forgot password?',
                        actionLabel: 'Reset your password',
                        buttonKey: const Key('login_forgot_password_button'),
                        focusOrder: 4,
                        enabled: !disabled,
                        onPressed: onForgotPassword,
                      ),
                      SizedBox(
                        height: compactHeight ? AppSpacing.xs : AppSpacing.sm,
                      ),
                      _AccountActionRow(
                        prompt: 'New teacher?',
                        actionLabel: 'Create a teacher account',
                        buttonKey: const Key('login_registration_button'),
                        focusOrder: 5,
                        enabled: !disabled,
                        onPressed: onRegister,
                        actionIcon: Icons.north_east_rounded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedHeight) {
          return Padding(padding: panelPadding, child: formContent);
        }

        final double contentHeight = (constraints.maxHeight -
                panelPadding.vertical)
            .clamp(0, double.infinity);
        return SingleChildScrollView(
          padding: panelPadding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: contentHeight),
            child: formContent,
          ),
        );
      },
    );
  }
}

class _AccountActionRow extends StatelessWidget {
  const _AccountActionRow({
    required this.prompt,
    required this.actionLabel,
    required this.buttonKey,
    required this.focusOrder,
    required this.enabled,
    required this.onPressed,
    this.actionIcon,
  });

  final String prompt;
  final String actionLabel;
  final Key buttonKey;
  final double focusOrder;
  final bool enabled;
  final VoidCallback onPressed;
  final IconData? actionIcon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final IconData? icon = actionIcon;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        Text(
          prompt,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        FocusTraversalOrder(
          order: NumericFocusOrder(focusOrder),
          child: TextButton(
            key: buttonKey,
            onPressed: enabled ? onPressed : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              foregroundColor: AuthPalette.primary,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(actionLabel),
                if (icon != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.xs),
                  Icon(icon, size: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkspacePanel extends StatelessWidget {
  const _WorkspacePanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AuthPalette.softBlue),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compactHeight = constraints.maxHeight < 680;
          final double inset = compactHeight ? AppSpacing.xl : 44;
          final double contentHeight = (constraints.maxHeight - (inset * 2))
              .clamp(0, double.infinity);

          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const CustomPaint(painter: _AcademicPatternPainter()),
              SingleChildScrollView(
                padding: EdgeInsets.all(inset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contentHeight),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const _WorkspaceBadge(),
                      SizedBox(height: compactHeight ? 28 : 52),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'A clearer place to lead math learning.',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineMedium?.copyWith(
                              color: AuthPalette.ink,
                              fontSize: compactHeight ? 27 : 30,
                              fontWeight: FontWeight.w700,
                              height: 1.16,
                              letterSpacing: -0.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'One entry point for teachers and administrators '
                            'to plan, monitor, and support every class.',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF506779),
                              height: 1.55,
                            ),
                          ),
                          SizedBox(
                            height:
                                compactHeight ? AppSpacing.lg : AppSpacing.xl,
                          ),
                          const _LearningPathCard(),
                        ],
                      ),
                      SizedBox(height: compactHeight ? 28 : 48),
                      const _WorkspaceFooter(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CompactWorkspacePanel extends StatelessWidget {
  const _CompactWorkspacePanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AuthPalette.softBlue),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            const _WorkspaceBadge(compact: true),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'A shared workspace for BayMath teachers and administrators.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AuthPalette.ink,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceBadge extends StatelessWidget {
  const _WorkspaceBadge({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 7 : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD5E0E8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.school_outlined, size: 16, color: AuthPalette.navy),
          if (!compact) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'EDUCATOR WORKSPACE',
              style: TextStyle(
                color: AuthPalette.navy,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LearningPathCard extends StatelessWidget {
  const _LearningPathCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFC),
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: const Color(0xFFD4E0E7)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D203950),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: Color(0xFFDCE8F0),
                  borderRadius: AppRadius.mediumAll,
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: AuthPalette.navy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Mathematics learning',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AuthPalette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'From lesson to lasting progress',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF6B7D89),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const _LearningPath(),
        ],
      ),
    );
  }
}

class _LearningPath extends StatelessWidget {
  const _LearningPath();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const _PathNode(label: 'LEARN', isComplete: true),
        Expanded(child: Container(height: 2, color: const Color(0xFF8FAABD))),
        const _PathNode(label: 'PRACTICE', isComplete: true),
        Expanded(child: Container(height: 2, color: const Color(0xFFD5DFE5))),
        const _PathNode(label: 'MASTER', isComplete: false),
      ],
    );
  }
}

class _PathNode extends StatelessWidget {
  const _PathNode({required this.label, required this.isComplete});

  final String label;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isComplete ? AuthPalette.navy : AuthPalette.gold,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x1A203950), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF667B89),
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }
}

class _WorkspaceFooter extends StatelessWidget {
  const _WorkspaceFooter();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: <Widget>[
        SizedBox(
          width: 24,
          child: Divider(color: AuthPalette.gold, thickness: 2),
        ),
        SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Built for the people who guide learning.',
            style: TextStyle(
              color: Color(0xFF5A7080),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _AcademicPatternPainter extends CustomPainter {
  const _AcademicPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint =
        Paint()
          ..color = const Color(0x0F55758E)
          ..strokeWidth = 1;

    for (double x = 24; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 24; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final Paint curvePaint =
        Paint()
          ..color = const Color(0x2455758E)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final Path curve =
        Path()
          ..moveTo(size.width * 0.08, size.height * 0.28)
          ..cubicTo(
            size.width * 0.28,
            size.height * 0.08,
            size.width * 0.64,
            size.height * 0.44,
            size.width * 0.94,
            size.height * 0.18,
          );
    canvas.drawPath(curve, curvePaint);

    final Paint accentPaint = Paint()..color = const Color(0x80D49A32);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.2),
      5,
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
