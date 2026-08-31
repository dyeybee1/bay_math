import 'package:flutter/material.dart';

import '../../../../app/constants/app_radius.dart';
import '../../../../app/constants/app_spacing.dart';
import '../../../../app/theme/adult_workspace_colors.dart';

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
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        obscureText: obscureText,
        enableSuggestions: enableSuggestions,
        autocorrect: autocorrect,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        onSubmitted: onSubmitted,
        onChanged: onChanged,
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
