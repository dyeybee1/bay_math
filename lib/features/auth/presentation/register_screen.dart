import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import 'widgets/auth_presentation.dart';

/// Teacher self-registration. The existing repository and router continue to
/// own role assignment, approval status, session resolution, and redirects.
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
  final FocusNode _fullNameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _errorText;

  static const double _twoColumnBreakpoint = 860;
  static const double _maxShellWidth = 1180;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || ref.read(sessionProvider).isLoading) return;

    final String fullName = _fullNameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Fill in every field.');
      if (fullName.isEmpty) {
        _fullNameFocusNode.requestFocus();
      } else if (email.isEmpty) {
        _emailFocusNode.requestFocus();
      } else {
        _passwordFocusNode.requestFocus();
      }
      return;
    }
    if (password.length < 8) {
      setState(() => _errorText = 'Password must be at least 8 characters.');
      _passwordFocusNode.requestFocus();
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorText = 'Passwords do not match.');
      _confirmPasswordFocusNode.requestFocus();
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
      // Keep the existing explicit refresh so the pending Teacher profile is
      // resolved immediately after account creation.
      ref.read(sessionProvider.notifier).refresh();
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _errorText = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              final bool shortViewport = constraints.maxHeight < 820;
              final bool compactContent = constraints.maxHeight < 950;
              final double horizontalInset = switch (constraints.maxWidth) {
                >= 1440 => AppSpacing.xxl,
                >= 1024 => AppSpacing.xl,
                _ => AppSpacing.md,
              };
              final double verticalInset =
                  shortViewport ? AppSpacing.md : AppSpacing.xl;
              final double minimumHeight = (constraints.maxHeight -
                      (verticalInset * 2))
                  .clamp(0, double.infinity);
              final double shellHeight =
                  shortViewport
                      ? minimumHeight.clamp(660, 760)
                      : minimumHeight.clamp(720, 800);

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
                        disabled: disabled,
                        useTwoColumns: useTwoColumns,
                        compactHeight: compactContent,
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

  Widget _buildShell({
    required bool disabled,
    required bool useTwoColumns,
    required bool compactHeight,
    required double shellHeight,
  }) {
    final Widget formPanel = _RegistrationPanel(
      fullNameController: _fullNameController,
      emailController: _emailController,
      passwordController: _passwordController,
      confirmPasswordController: _confirmPasswordController,
      fullNameFocusNode: _fullNameFocusNode,
      emailFocusNode: _emailFocusNode,
      passwordFocusNode: _passwordFocusNode,
      confirmPasswordFocusNode: _confirmPasswordFocusNode,
      disabled: disabled,
      isSubmitting: disabled,
      obscurePassword: _obscurePassword,
      obscureConfirmation: _obscureConfirmation,
      errorText: _errorText,
      compactHeight: compactHeight,
      onSubmit: _submit,
      onBack: () => context.pop(),
      onTogglePassword: () {
        setState(() => _obscurePassword = !_obscurePassword);
      },
      onToggleConfirmation: () {
        setState(() => _obscureConfirmation = !_obscureConfirmation);
      },
    );

    final Widget content =
        useTwoColumns
            ? SizedBox(
              height: shellHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(flex: 57, child: formPanel),
                  const Expanded(
                    flex: 43,
                    child: _RegistrationWorkspacePanel(),
                  ),
                ],
              ),
            )
            : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                formPanel,
                const _CompactRegistrationWorkspacePanel(),
              ],
            );

    return AuthShellSurface(child: content);
  }
}

class _RegistrationPanel extends StatelessWidget {
  const _RegistrationPanel({
    required this.fullNameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.fullNameFocusNode,
    required this.emailFocusNode,
    required this.passwordFocusNode,
    required this.confirmPasswordFocusNode,
    required this.disabled,
    required this.isSubmitting,
    required this.obscurePassword,
    required this.obscureConfirmation,
    required this.errorText,
    required this.compactHeight,
    required this.onSubmit,
    required this.onBack,
    required this.onTogglePassword,
    required this.onToggleConfirmation,
  });

  final TextEditingController fullNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final FocusNode fullNameFocusNode;
  final FocusNode emailFocusNode;
  final FocusNode passwordFocusNode;
  final FocusNode confirmPasswordFocusNode;
  final bool disabled;
  final bool isSubmitting;
  final bool obscurePassword;
  final bool obscureConfirmation;
  final String? errorText;
  final bool compactHeight;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmation;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final double verticalPadding = compactHeight ? 18 : AppSpacing.xl;
    final double fieldGap = compactHeight ? 10 : 13;
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
                Row(
                  children: <Widget>[
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(1),
                      child: TextButton.icon(
                        key: const Key('register_back_button'),
                        onPressed: disabled ? null : onBack,
                        style: TextButton.styleFrom(
                          foregroundColor: AuthPalette.navy,
                          minimumSize: const Size(0, 40),
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, size: 18),
                        label: const Text('Back to sign in'),
                      ),
                    ),
                    const Spacer(),
                    AuthBrandLogo(width: compactHeight ? 174 : 190),
                  ],
                ),
                SizedBox(height: compactHeight ? 14 : 20),
                const Text(
                  'TEACHER REGISTRATION',
                  style: TextStyle(
                    color: AuthPalette.primaryMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.25,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Create your teacher account',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AuthPalette.ink,
                    fontSize: compactHeight ? 27 : 30,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Set up your profile for access to the BayMath educator '
                  'workspace.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: compactHeight ? 14 : 20),
                const AuthFieldLabel(label: 'Full name'),
                const SizedBox(height: 6),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: AuthTextField(
                    key: const Key('register_full_name_field'),
                    controller: fullNameController,
                    focusNode: fullNameFocusNode,
                    enabled: !disabled,
                    hintText: 'Your full name',
                    semanticLabel: 'Full name',
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.name],
                    onSubmitted: (_) => emailFocusNode.requestFocus(),
                  ),
                ),
                SizedBox(height: fieldGap),
                const AuthFieldLabel(label: 'Email address'),
                const SizedBox(height: 6),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(3),
                  child: AuthTextField(
                    key: const Key('register_email_field'),
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
                SizedBox(height: fieldGap),
                const AuthFieldLabel(label: 'Password'),
                const SizedBox(height: 6),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(4),
                  child: AuthTextField(
                    key: const Key('register_password_field'),
                    controller: passwordController,
                    focusNode: passwordFocusNode,
                    enabled: !disabled,
                    hintText: 'At least 8 characters',
                    semanticLabel: 'Password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: obscurePassword,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    suffix: AuthPasswordVisibilityButton(
                      key: const Key('register_password_visibility'),
                      obscurePassword: obscurePassword,
                      enabled: !disabled,
                      onPressed: onTogglePassword,
                    ),
                    onSubmitted: (_) => confirmPasswordFocusNode.requestFocus(),
                  ),
                ),
                SizedBox(height: fieldGap),
                const AuthFieldLabel(label: 'Confirm password'),
                const SizedBox(height: 6),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(5),
                  child: AuthTextField(
                    key: const Key('register_confirm_password_field'),
                    controller: confirmPasswordController,
                    focusNode: confirmPasswordFocusNode,
                    enabled: !disabled,
                    hintText: 'Re-enter your password',
                    semanticLabel: 'Confirm password',
                    prefixIcon: Icons.lock_outline_rounded,
                    obscureText: obscureConfirmation,
                    enableSuggestions: false,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.newPassword],
                    suffix: AuthPasswordVisibilityButton(
                      key: const Key('register_confirmation_visibility'),
                      fieldName: 'password confirmation',
                      obscurePassword: obscureConfirmation,
                      enabled: !disabled,
                      onPressed: onToggleConfirmation,
                    ),
                    onSubmitted: (_) {
                      if (!disabled) onSubmit();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                AuthFormNotice(
                  key:
                      errorText == null
                          ? null
                          : const Key('register_error_message'),
                  guidance:
                      'An Administrator must approve your account before '
                      'workspace access begins.',
                  errorText: errorText,
                ),
                SizedBox(height: compactHeight ? 12 : 16),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(6),
                  child: AuthPrimaryButton(
                    key: const Key('register_submit_button'),
                    label: 'Create teacher account',
                    loadingLabel: 'Creating account…',
                    isLoading: isSubmitting,
                    onPressed: disabled ? null : onSubmit,
                  ),
                ),
                SizedBox(height: compactHeight ? 10 : 14),
                Container(
                  padding: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE3E9EE))),
                  ),
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      Text(
                        'Already have an account?',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      FocusTraversalOrder(
                        order: const NumericFocusOrder(7),
                        child: TextButton(
                          key: const Key('register_login_button'),
                          onPressed: disabled ? null : onBack,
                          style: TextButton.styleFrom(
                            foregroundColor: AuthPalette.primary,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                          ),
                          child: const Text('Sign in'),
                        ),
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

class _RegistrationWorkspacePanel extends StatelessWidget {
  const _RegistrationWorkspacePanel();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AuthPalette.softBlue),
      child: CustomPaint(
        painter: const _RegistrationPatternPainter(),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool compactHeight = constraints.maxHeight < 720;
            final EdgeInsets panelPadding = EdgeInsets.fromLTRB(
              AppSpacing.xl,
              compactHeight ? AppSpacing.xl : 40,
              AppSpacing.xl,
              compactHeight ? AppSpacing.lg : AppSpacing.xl,
            );
            return SingleChildScrollView(
              padding: panelPadding,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - panelPadding.vertical)
                      .clamp(0, double.infinity),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const _RegistrationBadge(),
                    SizedBox(height: compactHeight ? 28 : 56),
                    Text(
                      'A thoughtful start for every teacher.',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(
                        color: AuthPalette.ink,
                        fontSize: compactHeight ? 27 : 31,
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Create your profile, then your Administrator confirms '
                      'access to the educator workspace.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF4E6B80),
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: compactHeight ? 20 : AppSpacing.xl),
                    const _ApprovalPathCard(),
                    SizedBox(height: compactHeight ? 28 : 64),
                    const _RegistrationFooter(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CompactRegistrationWorkspacePanel extends StatelessWidget {
  const _CompactRegistrationWorkspacePanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: const BoxDecoration(color: AuthPalette.softBlue),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _RegistrationBadge(compact: true),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Your profile starts with Administrator approval.',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AuthPalette.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Create the account here; BayMath will preserve the same '
                  'guided path into the educator workspace.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF526E81),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationBadge extends StatelessWidget {
  const _RegistrationBadge({this.compact = false});
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
        border: Border.all(color: const Color(0xFFD3E0E9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.badge_outlined, size: 16, color: AuthPalette.navy),
          if (!compact) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'TEACHER REGISTRATION',
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

class _ApprovalPathCard extends StatelessWidget {
  const _ApprovalPathCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: const Color(0xFFD2E0E9)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0D203950),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Your access path',
            style: TextStyle(
              color: AuthPalette.ink,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 18),
          _ApprovalStep(
            number: '1',
            title: 'Create profile',
            description: 'Enter your teacher account details.',
          ),
          _ApprovalConnector(),
          _ApprovalStep(
            number: '2',
            title: 'Administrator approval',
            description: 'Your account is reviewed before access.',
            highlighted: true,
          ),
          _ApprovalConnector(),
          _ApprovalStep(
            number: '3',
            title: 'Educator workspace',
            description: 'Sign in after the account is approved.',
          ),
        ],
      ),
    );
  }
}

class _ApprovalStep extends StatelessWidget {
  const _ApprovalStep({
    required this.number,
    required this.title,
    required this.description,
    this.highlighted = false,
  });

  final String number;
  final String title;
  final String description;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted ? AuthPalette.gold : AuthPalette.navy,
            shape: BoxShape.circle,
          ),
          child: Text(
            number,
            style: TextStyle(
              color: highlighted ? AuthPalette.ink : Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  color: AuthPalette.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF607686),
                  fontSize: 11,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ApprovalConnector extends StatelessWidget {
  const _ApprovalConnector();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 13, top: 4, bottom: 4),
      child: SizedBox(
        height: 14,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: Color(0xFFB8CAD6),
        ),
      ),
    );
  }
}

class _RegistrationFooter extends StatelessWidget {
  const _RegistrationFooter();

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
            'Built for teachers shaping every lesson.',
            style: TextStyle(
              color: Color(0xFF577083),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _RegistrationPatternPainter extends CustomPainter {
  const _RegistrationPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint =
        Paint()
          ..color = const Color(0x0F4B73A0)
          ..strokeWidth = 1;
    for (double x = 24; x < size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 24; y < size.height; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final Paint pathPaint =
        Paint()
          ..color = const Color(0x244B73A0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    final Path path =
        Path()
          ..moveTo(size.width * 0.08, size.height * 0.22)
          ..cubicTo(
            size.width * 0.3,
            size.height * 0.06,
            size.width * 0.64,
            size.height * 0.35,
            size.width * 0.94,
            size.height * 0.14,
          );
    canvas.drawPath(path, pathPaint);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.16),
      5,
      Paint()..color = const Color(0x99DCA329),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
