import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/constants/app_radius.dart';
import '../../../../app/constants/app_spacing.dart';
import '../../../../app/theme/adult_workspace_colors.dart';
import '../../../../core/validation/teacher_registration_validators.dart';

/// Semantic presentation roles for the adult Teacher/Administrator Auth flow.
///
/// These colors are intentionally scoped to Auth so refining the official
/// BayMath identity here cannot unexpectedly recolor Student or dashboard UI.
abstract final class AuthPalette {
  static const Color canvas = AdultWorkspaceColors.canvas;
  static const Color ink = AdultWorkspaceColors.ink;
  static const Color navy = AdultWorkspaceColors.navy;
  static const Color primary = AdultWorkspaceColors.primary;
  static const Color primaryMuted = AdultWorkspaceColors.primaryMuted;
  static const Color softBlue = AdultWorkspaceColors.softBlue;
  static const Color paleBlue = AdultWorkspaceColors.paleBlue;
  static const Color gold = AdultWorkspaceColors.gold;
  static const Color fieldFill = AdultWorkspaceColors.fieldFill;
  static const Color outline = AdultWorkspaceColors.outline;
}

/// Responsive centered canvas for focused staff-auth tasks such as password
/// recovery. It keeps the same visual language as login and registration.
class AuthCenteredPage extends StatelessWidget {
  const AuthCenteredPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuthPalette.canvas,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double horizontalPadding =
                  constraints.maxWidth < 600 ? AppSpacing.md : AppSpacing.xl;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: AppSpacing.xl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - (AppSpacing.xl * 2))
                        .clamp(0, double.infinity),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 590),
                      child: AuthShellSurface(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal:
                                constraints.maxWidth < 600
                                    ? AppSpacing.lg
                                    : AppSpacing.xxl,
                            vertical: AppSpacing.xl,
                          ),
                          child: child,
                        ),
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
}

class AuthShellSurface extends StatelessWidget {
  const AuthShellSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.extraLargeAll,
        border: Border.all(color: const Color(0xFFDCE4EA)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14203950),
            blurRadius: 34,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: AppRadius.extraLargeAll, child: child),
    );
  }
}

/// The complete official BayMath mascot-and-wordmark lockup.
class AuthBrandLogo extends StatelessWidget {
  const AuthBrandLogo({super.key, this.width = 190});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        image: true,
        label: 'BayMath, Learn, Practice, Master',
        child: Image.asset(
          'assets/images/baymath_logo.png',
          width: width,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: AuthPalette.ink,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hintText,
    required this.semanticLabel,
    required this.prefixIcon,
    required this.textInputAction,
    required this.autofillHints,
    required this.onSubmitted,
    this.keyboardType,
    this.obscureText = false,
    this.enableSuggestions = true,
    this.autocorrect = true,
    this.suffix,
    this.onChanged,
    this.validator,
    this.forceErrorText,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String hintText;
  final String semanticLabel;
  final IconData prefixIcon;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final ValueChanged<String> onSubmitted;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool enableSuggestions;
  final bool autocorrect;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final String? forceErrorText;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    const OutlineInputBorder baseBorder = OutlineInputBorder(
      borderRadius: AppRadius.mediumAll,
      borderSide: BorderSide(color: AuthPalette.outline),
    );

    return Semantics(
      textField: true,
      label: semanticLabel,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: obscureText,
        enableSuggestions: enableSuggestions,
        autocorrect: autocorrect,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onFieldSubmitted: onSubmitted,
        onChanged: onChanged,
        validator: validator,
        forceErrorText: forceErrorText,
        maxLength: maxLength,
        maxLengthEnforcement: MaxLengthEnforcement.none,
        textCapitalization: textCapitalization,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: AuthPalette.ink),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.82),
          ),
          filled: true,
          fillColor: enabled ? AuthPalette.fieldFill : const Color(0xFFF0F3F5),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 15,
          ),
          prefixIcon: Icon(prefixIcon, size: 20),
          prefixIconColor: const Color(0xFF647C8D),
          suffixIcon: suffix,
          counterText: '',
          errorMaxLines: 2,
          border: baseBorder,
          enabledBorder: baseBorder,
          disabledBorder: baseBorder.copyWith(
            borderSide: const BorderSide(color: Color(0xFFDCE3E8)),
          ),
          focusedBorder: baseBorder.copyWith(
            borderSide: const BorderSide(color: AuthPalette.primary, width: 2),
          ),
        ),
      ),
    );
  }
}

class AuthPasswordVisibilityButton extends StatelessWidget {
  const AuthPasswordVisibilityButton({
    super.key,
    required this.obscurePassword,
    required this.enabled,
    required this.onPressed,
    this.fieldName = 'password',
  });

  final bool obscurePassword;
  final bool enabled;
  final VoidCallback onPressed;
  final String fieldName;

  @override
  Widget build(BuildContext context) {
    final String label =
        obscurePassword ? 'Show $fieldName' : 'Hide $fieldName';
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: ExcludeSemantics(
        child: IconButton(
          onPressed: enabled ? onPressed : null,
          tooltip: label,
          icon: Icon(
            obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 21,
          ),
        ),
      ),
    );
  }
}

/// A stable-height guidance surface that becomes an error surface in place.
class AuthFormNotice extends StatelessWidget {
  const AuthFormNotice({super.key, required this.guidance, this.errorText});

  final String guidance;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null;
    final Color foreground =
        hasError
            ? Theme.of(context).colorScheme.onErrorContainer
            : const Color(0xFF49677B);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color:
            hasError
                ? Theme.of(context).colorScheme.errorContainer
                : AuthPalette.paleBlue,
        borderRadius: AppRadius.mediumAll,
        border: Border.all(
          color:
              hasError
                  ? Theme.of(context).colorScheme.error.withValues(alpha: 0.25)
                  : const Color(0xFFD8E7F0),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            hasError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Text(
                errorText ?? guidance,
                key: ValueKey<String>(errorText ?? guidance),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontWeight: hasError ? FontWeight.w600 : FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final String loadingLabel;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AuthPalette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AuthPalette.primaryMuted,
          disabledForegroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.mediumAll,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child:
              isLoading
                  ? Row(
                    key: const ValueKey<String>('loading'),
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(loadingLabel),
                    ],
                  )
                  : Row(
                    key: const ValueKey<String>('idle'),
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(label),
                      const SizedBox(width: AppSpacing.sm),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
        ),
      ),
    );
  }
}

/// Shared live password-policy display used by registration and recovery.
class AuthPasswordRequirements extends StatelessWidget {
  const AuthPasswordRequirements({
    super.key,
    required this.password,
    this.requirementKeyPrefix = 'password_requirement',
  });

  final String password;
  final String requirementKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final PasswordRequirements requirements =
        TeacherRegistrationValidators.passwordRequirements(password);
    final bool hasInput = password.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AuthPalette.paleBlue.withValues(alpha: 0.62),
        borderRadius: AppRadius.mediumAll,
        border: Border.all(color: const Color(0xFFD8E7F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Password must contain:',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AuthPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 5,
            children: <Widget>[
              _AuthPasswordRequirement(
                key: Key('${requirementKeyPrefix}_length'),
                label:
                    'At least ${TeacherRegistrationValidators.passwordMinLength} characters',
                isMet: requirements.hasMinimumLength,
                hasInput: hasInput,
              ),
              _AuthPasswordRequirement(
                key: Key('${requirementKeyPrefix}_uppercase'),
                label: 'One uppercase letter',
                isMet: requirements.hasUppercase,
                hasInput: hasInput,
              ),
              _AuthPasswordRequirement(
                key: Key('${requirementKeyPrefix}_lowercase'),
                label: 'One lowercase letter',
                isMet: requirements.hasLowercase,
                hasInput: hasInput,
              ),
              _AuthPasswordRequirement(
                key: Key('${requirementKeyPrefix}_number'),
                label: 'One number',
                isMet: requirements.hasNumber,
                hasInput: hasInput,
              ),
              _AuthPasswordRequirement(
                key: Key('${requirementKeyPrefix}_special'),
                label: 'One special character',
                isMet: requirements.hasSpecialCharacter,
                hasInput: hasInput,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AuthPasswordRequirement extends StatelessWidget {
  const _AuthPasswordRequirement({
    super.key,
    required this.label,
    required this.isMet,
    required this.hasInput,
  });

  final String label;
  final bool isMet;
  final bool hasInput;

  @override
  Widget build(BuildContext context) {
    final Color color =
        isMet
            ? const Color(0xFF217A50)
            : hasInput
            ? Theme.of(context).colorScheme.error
            : const Color(0xFF6B7F8E);
    final IconData icon =
        isMet
            ? Icons.check_circle_rounded
            : hasInput
            ? Icons.cancel_rounded
            : Icons.circle_outlined;

    return Semantics(
      label: '$label, ${isMet ? 'complete' : 'incomplete'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
