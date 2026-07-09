import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_component_size.dart';

/// Behavioral mode of an [AppTextField].
enum AppTextFieldType {
  normal,
  password,
  search,
  multiline,
}

/// The app's single reusable text input.
///
/// Wraps [TextField] and relies entirely on the app's global
/// `InputDecorationTheme` (configured in Phase 0.5) for visuals — this
/// widget only adds behavior: password visibility toggling, search
/// affordances, multiline sizing, and consistent sizing/typography via
/// [AppComponentSize].
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.type = AppTextFieldType.normal,
    this.size = AppComponentSize.medium,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.maxLines,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final AppTextFieldType type;
  final AppComponentSize size;

  final String? label;
  final String? hint;

  /// Validation/error message. When non-null, the field renders in its
  /// themed error state.
  final String? errorText;
  final String? helperText;

  final IconData? prefixIcon;

  /// Ignored when [type] is [AppTextFieldType.password] — that mode
  /// always shows the visibility toggle instead.
  final IconData? suffixIcon;

  final bool enabled;
  final bool readOnly;
  final bool autofocus;

  /// Only used when [type] is [AppTextFieldType.multiline]. Defaults to 4.
  final int? maxLines;
  final int? maxLength;

  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final bool isPassword = widget.type == AppTextFieldType.password;
    final bool isSearch = widget.type == AppTextFieldType.search;
    final bool isMultiline = widget.type == AppTextFieldType.multiline;

    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      autofocus: widget.autofocus,
      obscureText: isPassword && _obscure,
      maxLines: isMultiline ? (widget.maxLines ?? 4) : 1,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType ??
          (isMultiline ? TextInputType.multiline : TextInputType.text),
      textInputAction: widget.textInputAction ??
          (isSearch ? TextInputAction.search : null),
      inputFormatters: widget.inputFormatters,
      style: widget.size.textStyle(Theme.of(context).textTheme),
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        errorText: widget.errorText,
        helperText: widget.helperText,
        prefixIcon: isSearch
            ? const Icon(Icons.search)
            : widget.prefixIcon != null
                ? Icon(widget.prefixIcon)
                : null,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                tooltip: _obscure ? 'Show password' : 'Hide password',
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : widget.suffixIcon != null
                ? Icon(widget.suffixIcon)
                : null,
      ),
    );
  }
}
