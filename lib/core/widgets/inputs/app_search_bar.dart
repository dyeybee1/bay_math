import 'package:flutter/material.dart';

import '../app_component_size.dart';
import 'app_text_field.dart';

/// The app's single reusable search field.
///
/// Deliberately thin — it's an [AppTextField] preconfigured with
/// [AppTextFieldType.search], so search inputs anywhere in the app look
/// and behave identically to every other text field.
class AppSearchBar extends StatelessWidget {
  const AppSearchBar({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.size = AppComponentSize.medium,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String hint;
  final AppComponentSize size;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      type: AppTextFieldType.search,
      size: size,
      hint: hint,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
