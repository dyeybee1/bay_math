import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/config/env_config.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/validation/teacher_registration_validators.dart';
import 'widgets/auth_presentation.dart';

const String passwordResetRequestSuccessMessage =
    'If an account exists for this email, a password reset link has been sent.';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key, this.redirectUrl});

  /// Test/deployment injection point. Production routing uses [EnvConfig].
  final String? redirectUrl;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _wasSent = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _wasSent) return;
    setState(() => _errorText = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      _emailFocusNode.requestFocus();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .requestPasswordReset(
            email: _emailController.text,
            redirectTo:
                widget.redirectUrl ??
                EnvConfig.staffPasswordResetRedirectUrl ??
                '',
          );
      if (mounted) setState(() => _wasSent = true);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _errorText = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return AuthCenteredPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              TextButton.icon(
                key: const Key('forgot_back_button'),
                onPressed:
                    _isSubmitting ? null : () => context.go(AppRoutes.login),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Back to sign in'),
              ),
              const Spacer(),
              const AuthBrandLogo(width: 172),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Icon(
            _wasSent
                ? Icons.mark_email_read_outlined
                : Icons.lock_reset_rounded,
            color: AuthPalette.primary,
            size: 42,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _wasSent ? 'Check your email' : 'Reset your password',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AuthPalette.ink,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _wasSent
                ? passwordResetRequestSuccessMessage
                : 'Enter the email address for your Teacher or Administrator '
                    'account. The secure reset page will open in your browser.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_wasSent)
            AuthPrimaryButton(
              key: const Key('forgot_return_button'),
              label: 'Return to sign in',
              loadingLabel: 'Returning…',
              isLoading: false,
              onPressed: () => context.go(AppRoutes.login),
            )
          else
            Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const AuthFieldLabel(label: 'Email address'),
                  const SizedBox(height: AppSpacing.sm),
                  AuthTextField(
                    key: const Key('forgot_email_field'),
                    controller: _emailController,
                    focusNode: _emailFocusNode,
                    enabled: !_isSubmitting,
                    hintText: 'name@school.edu',
                    semanticLabel: 'Email address',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const <String>[AutofillHints.email],
                    maxLength: TeacherRegistrationValidators.emailMaxLength,
                    validator: TeacherRegistrationValidators.validateEmail,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_errorText != null) ...<Widget>[
                    AuthFormNotice(
                      key: const Key('forgot_error_message'),
                      guidance: '',
                      errorText: _errorText,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  AuthPrimaryButton(
                    key: const Key('forgot_submit_button'),
                    label: 'Send reset link',
                    loadingLabel: 'Sending reset link…',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
