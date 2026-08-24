import 'package:flutter/material.dart';

import '../app_component_size.dart';

/// One selectable entry in an [AppDropdown].
///
/// Deliberately not just "a `T` plus a label lookup function" — modeling
/// each option as its own value+label pair (rather than, say, requiring
/// `T` to implement a display-label interface) is what lets a null "All
/// ___" option sit in the exact same list as the real values: `T?` can
/// carry a `null` entry, but a bare `T` never could.
class AppDropdownOption<T> {
  const AppDropdownOption({required this.value, required this.label});

  /// The underlying value this option represents. `null` is a legal,
  /// first-class value here — see the "All ___" convention on
  /// [AppDropdown] itself.
  final T? value;

  final String label;
}

/// The app's single reusable dropdown / select input, generic over the
/// value type `T` (an enum, a `String` id, etc).
///
/// Deliberately thin, the same way [AppSearchBar] is thin over
/// [AppTextField]: this wraps [DropdownMenu] rather than reimplementing
/// its look, because [DropdownMenu] already inherits [AppInputTheme]
/// wholesale via the app-wide `DropdownMenuThemeData` (see
/// `app_dropdown_menu_theme.dart` — "Reuses [AppInputTheme] so the
/// dropdown's field looks identical to a regular text input"). So this
/// widget adds no manual box/border/fill/padding styling at all — not
/// even `AppSpacing`/`AppRadius` constants directly — since
/// `AppInputTheme.inputDecoration` already applies both (`AppSpacing.md`
/// content padding, `AppRadius.mediumAll` border radius) globally; adding
/// them again here would either fight the theme or duplicate it. The only
/// visual choice made directly here is [width] (via [SizedBox]), because unlike a text
/// field a dropdown's natural width is content-driven (it shrinks to fit
/// its widest menu entry) and a filter bar needs each dropdown to hold a
/// stable, predictable width instead of jumping around as the selection
/// changes.
///
/// Built for, but not limited to, a results-filter-bar layout: a Section
/// dropdown, an Assessment Type dropdown (All / Pre-Test / Post-Test), a
/// Date Range dropdown (All Time / Today / This Week / This Month) sitting
/// in a row. Every one of those examples has an "All ___" catch-all entry
/// that maps to "no filter" — i.e. a `null` selection — rather than to any
/// real value of the underlying enum/type. [AppDropdown] treats that as
/// the normal case, not a special one: [options] is `List<AppDropdownOption<T>>`
/// (so `null` is just another [AppDropdownOption.value]), [selected] and
/// [onChanged] are both `T?`, and equality between [selected] and each
/// option's value is what determines the highlighted entry — a caller
/// building an "All Sections" filter passes `AppDropdownOption<Section>(value: null,
/// label: 'All Sections')` alongside the real sections and everything
/// else just works, with no separate null-handling API to learn.
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.label,
    this.size = AppComponentSize.medium,
    this.width,
    this.enabled = true,
  });

  /// The full option list, including any "All ___" / null entry. Order is
  /// preserved as given — callers are expected to put the "All ___" entry
  /// first if that's the desired menu order, the same way they would for
  /// any other list-backed widget.
  final List<AppDropdownOption<T>> options;

  /// The currently selected value. Matched against each option's
  /// [AppDropdownOption.value] by `==`, so `T` (or its `null` case) needs
  /// only value equality, not identity — true for enums and `String` ids
  /// alike.
  final T? selected;

  final ValueChanged<T?> onChanged;

  final String? label;

  final AppComponentSize size;

  /// Fixed width for the dropdown field. When null, [DropdownMenu] sizes
  /// itself to its widest entry (its own default) — set this explicitly
  /// in a filter bar so a row of [AppDropdown]s lines up rather than each
  /// one sizing independently to its own content.
  final double? width;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final DropdownMenu<T?> menu = DropdownMenu<T?>(
      initialSelection: selected,
      enabled: enabled,
      label: label == null ? null : Text(label!),
      textStyle: size.textStyle(Theme.of(context).textTheme),
      dropdownMenuEntries: [
        for (final AppDropdownOption<T> option in options)
          DropdownMenuEntry<T?>(value: option.value, label: option.label),
      ],
      onSelected: onChanged,
    );

    if (width == null) {
      return menu;
    }

    return SizedBox(width: width, child: menu);
  }
}
