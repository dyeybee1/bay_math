/// Single import point for the entire reusable widget library.
///
/// Feature modules should generally do:
/// ```dart
/// import 'package:instructional_math_app/core/widgets/widgets.dart';
/// ```
/// rather than importing individual widget files, so the library's
/// internal folder layout can evolve without breaking call sites.
library;

export 'app_component_size.dart';
export 'buttons/app_button.dart';
export 'cards/app_card.dart';
export 'dialogs/app_dialog.dart';
export 'feedback/app_badge.dart';
export 'feedback/app_chip.dart';
export 'inputs/app_dropdown.dart';
export 'inputs/app_search_bar.dart';
export 'inputs/app_text_field.dart';
export 'layout/app_divider.dart';
export 'layout/app_page_container.dart';
export 'layout/app_section_header.dart';
export 'loading/app_loading_indicator.dart';
export 'navigation/app_avatar.dart';
export 'states/app_empty_state.dart';
export 'states/app_error_state.dart';
