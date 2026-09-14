import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/providers/password_recovery_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/validation/teacher_registration_validators.dart';
import 'widgets/auth_presentation.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final FocusNode _confirmPasswordFocusNode = FocusNode();

  bool _isSubmitting = false;
  bool _isComplete = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isComplete) return;
    setState(() => _errorText = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .updateRecoveredPassword(_passwordController.text);
      // Remove the browser's recovery session before allowing navigation away.
      // Supabase removes the local session before attempting its best-effort
      // server notification. Once updateUser succeeds, a later sign-out error
      // must not misreport the already-completed password change as failed.
      try {
        await ref.read(authRepositoryProvider).endRecoverySession();
      } on AppFailure {
        // The local recovery session has already been cleared by signOut.
      }
      if (!mounted) return;
      ref.read(passwordRecoveryProvider.notifier).markCompleted();
      setState(() => _isComplete = true);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _errorText =
            failure is SessionExpiredFailure || failure is RecoveryLinkFailure
                ? const RecoveryLinkFailure().message
                : failure.message;
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PasswordRecoveryStatus status = ref.watch(passwordRecoveryProvider);
    if (_isComplete || status == PasswordRecoveryStatus.completed) {
      return const _RecoveryOutcome(
        key: Key('reset_success_view'),
        isSuccess: true,
      );
    }
    if (status != PasswordRecoveryStatus.valid) {
      return const _RecoveryOutcome(
        key: Key('reset_invalid_view'),
        isSuccess: false,
      );
    }

    return AuthCenteredPage(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AuthBrandLogo(width: 182),
            const SizedBox(height: AppSpacing.xl),
            const Icon(
              Icons.password_rounded,
              color: AuthPalette.primary,
              size: 42,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Choose a new password',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AuthPalette.ink,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This changes only your BayMath staff password. Your role and '
              'account approval status will not change.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            const AuthFieldLabel(label: 'New password'),
            const SizedBox(height: AppSpacing.sm),
            AuthTextField(
              key: const Key('reset_password_field'),
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              enabled: !_isSubmitting,
              hintText: 'Enter your new password',
              semanticLabel: 'New password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscurePassword,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              maxLength: TeacherRegistrationValidators.passwordMaxLength,
              validator: TeacherRegistrationValidators.validatePassword,
              suffix: AuthPasswordVisibilityButton(
                key: const Key('reset_password_visibility'),
                obscurePassword: _obscurePassword,
                enabled: !_isSubmitting,
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              onChanged: (_) {
                setState(() {});
                if (_confirmPasswordController.text.isNotEmpty) {
                  _formKey.currentState?.validate();
                }
              },
              onSubmitted: (_) => _confirmPasswordFocusNode.requestFocus(),
            ),
            const SizedBox(height: 10),
            AuthPasswordRequirements(
              key: const Key('reset_password_requirements'),
              password: _passwordController.text,
              requirementKeyPrefix: 'reset_password_requirement',
            ),
            const SizedBox(height: AppSpacing.md),
            const AuthFieldLabel(label: 'Confirm password'),
            const SizedBox(height: AppSpacing.sm),
            AuthTextField(
              key: const Key('reset_confirm_password_field'),
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              enabled: !_isSubmitting,
              hintText: 'Re-enter your new password',
              semanticLabel: 'Confirm password',
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: _obscureConfirmation,
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.newPassword],
              maxLength: TeacherRegistrationValidators.passwordMaxLength,
              validator:
                  (String? value) =>
                      TeacherRegistrationValidators.validateConfirmPassword(
                        value,
                        _passwordController.text,
                      ),
              suffix: AuthPasswordVisibilityButton(
                key: const Key('reset_confirmation_visibility'),
                fieldName: 'password confirmation',
                obscurePassword: _obscureConfirmation,
                enabled: !_isSubmitting,
                onPressed: () {
                  setState(() => _obscureConfirmation = !_obscureConfirmation);
                },
              ),
              onSubmitted: (_) => _submit(),
            ),
            if (_errorText != null) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              AuthFormNotice(
                key: const Key('reset_error_message'),
                guidance: '',
                errorText: _errorText,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            AuthPrimaryButton(
              key: const Key('reset_submit_button'),
              label: 'Update password',
              loadingLabel: 'Updating password…',
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryOutcome extends StatelessWidget {
  const _RecoveryOutcome({super.key, required this.isSuccess});

  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    return AuthCenteredPage(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AuthBrandLogo(width: 182),
          const SizedBox(height: AppSpacing.xl),
          Icon(
            isSuccess
                ? Icons.check_circle_outline_rounded
                : Icons.link_off_rounded,
            color:
                isSuccess
                    ? const Color(0xFF217A50)
                    : Theme.of(context).colorScheme.error,
            size: 48,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isSuccess ? 'Password updated' : 'Reset link unavailable',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AuthPalette.ink,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isSuccess
                ? 'Your password has been changed. Return to the BayMath '
                    'desktop app and sign in with your new password.'
                : const RecoveryLinkFailure().message,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AuthPrimaryButton(
            key: Key(
              isSuccess ? 'reset_done_button' : 'reset_request_new_button',
            ),
            label: isSuccess ? 'Go to sign in' : 'Request a new reset link',
            loadingLabel: 'Opening…',
            isLoading: false,
            onPressed:
                () => context.go(
                  isSuccess ? AppRoutes.login : AppRoutes.forgotPassword,
                ),
          ),
        ],
      ),
    );
  }
}
