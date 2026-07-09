import 'package:flutter/material.dart';

import '../../app/constants/app_radius.dart';
import '../../app/constants/app_spacing.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_semantic_colors.dart';
import '../../core/widgets/widgets.dart';

/// Development-only screen that previews every widget in
/// `lib/core/widgets/`, plus the raw design tokens (colors, typography,
/// spacing) from Phase 0.5.
///
/// This screen is **not** part of the application experience. It exists
/// purely so the design system and component library can be visually
/// verified as they grow. It is only reachable via the hidden
/// `/dev/components` route, which is excluded from release builds
/// (see `app_router.dart`).
class ComponentGalleryScreen extends StatefulWidget {
  const ComponentGalleryScreen({super.key});

  @override
  State<ComponentGalleryScreen> createState() => _ComponentGalleryScreenState();
}

class _ComponentGalleryScreenState extends State<ComponentGalleryScreen> {
  bool _chipSelected = false;
  bool _buttonLoading = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Component Gallery (Dev Only)')),
      body: AppPageContainer(
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const AppSectionHeader(
              title: 'Buttons',
              subtitle: 'AppButton — every variant, plus loading & disabled',
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                AppButton(label: 'Primary', onPressed: () {}),
                AppButton(
                  label: 'Secondary',
                  variant: AppButtonVariant.secondary,
                  onPressed: () {},
                ),
                AppButton(
                  label: 'Outlined',
                  variant: AppButtonVariant.outlined,
                  onPressed: () {},
                ),
                AppButton(label: 'Text', variant: AppButtonVariant.text, onPressed: () {}),
                AppButton(
                  label: 'Danger',
                  variant: AppButtonVariant.danger,
                  onPressed: () {},
                ),
                const AppButton(label: 'Disabled', onPressed: null),
                AppButton(
                  label: 'Loading',
                  isLoading: _buttonLoading,
                  onPressed: () => setState(() => _buttonLoading = !_buttonLoading),
                ),
                AppButton(
                  label: 'With icons',
                  leadingIcon: Icons.calculate_outlined,
                  trailingIcon: Icons.arrow_forward,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const AppButton(label: 'Full width', isFullWidth: true, onPressed: null),

            const AppSectionHeader(title: 'Inputs', subtitle: 'AppTextField & AppSearchBar'),
            const AppTextField(label: 'Name', hint: 'Enter your name'),
            const SizedBox(height: AppSpacing.sm),
            const AppTextField(
              label: 'Password',
              type: AppTextFieldType.password,
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppTextField(
              label: 'Notes',
              type: AppTextFieldType.multiline,
              hint: 'Multiline input',
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppTextField(
              label: 'With error',
              errorText: 'This field is required',
            ),
            const SizedBox(height: AppSpacing.sm),
            AppSearchBar(controller: _searchController),

            const AppSectionHeader(title: 'Cards', subtitle: 'AppCard'),
            AppCard(
              header: const Text('Card header'),
              subtitle: const Text('Optional subtitle'),
              leading: const Icon(Icons.book_outlined),
              trailing: const AppBadge(label: 'New', variant: AppBadgeVariant.info),
              footer: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  AppButton(label: 'Action', size: AppComponentSize.small, onPressed: () {}),
                ],
              ),
              onTap: () {},
              child: const Text('Card body content goes here.'),
            ),

            const AppSectionHeader(title: 'Dialogs', subtitle: 'AppDialog — tap to preview'),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final AppDialogType type in AppDialogType.values)
                  AppButton(
                    label: type.name,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => AppDialog.show<void>(
                      context,
                      type: type,
                      title: '${type.name[0].toUpperCase()}${type.name.substring(1)} dialog',
                      message: 'This is a preview of the ${type.name} dialog variant.',
                      actions: <Widget>[
                        AppButton(
                          label: 'Cancel',
                          variant: AppButtonVariant.text,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        AppButton(
                          label: 'OK',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const AppSectionHeader(title: 'Badges & Chips'),
            const Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                AppBadge(label: 'Success', variant: AppBadgeVariant.success),
                AppBadge(label: 'Warning', variant: AppBadgeVariant.warning),
                AppBadge(label: 'Error', variant: AppBadgeVariant.error),
                AppBadge(label: 'Info', variant: AppBadgeVariant.info),
                AppBadge(label: 'Neutral', variant: AppBadgeVariant.neutral),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                AppChip(
                  label: 'Filter',
                  selected: _chipSelected,
                  icon: Icons.filter_alt_outlined,
                  onSelected: (value) => setState(() => _chipSelected = value),
                ),
                const AppChip(label: 'Disabled', enabled: false),
              ],
            ),

            const AppSectionHeader(title: 'Avatars', subtitle: 'AppAvatar — initials & icon fallback'),
            const Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                AppAvatar(initials: 'JS', size: AppComponentSize.small),
                AppAvatar(initials: 'MT', size: AppComponentSize.medium),
                AppAvatar(size: AppComponentSize.large),
              ],
            ),

            const AppSectionHeader(title: 'Loading'),
            const Row(
              children: <Widget>[
                AppLoadingIndicator(size: AppComponentSize.small),
                SizedBox(width: AppSpacing.lg),
                AppLoadingIndicator(size: AppComponentSize.large),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            const AppLoadingIndicator(variant: AppLoadingVariant.linear, message: 'Loading…'),

            const AppSectionHeader(title: 'Empty & Error States'),
            AppCard(
              child: SizedBox(
                height: 220,
                child: AppEmptyState(
                  title: 'No lessons yet',
                  description: 'Assigned lessons will show up here.',
                  actionLabel: 'Refresh',
                  onAction: () {},
                ),
              ),
            ),
            AppCard(
              child: SizedBox(
                height: 220,
                child: AppErrorState(
                  message: 'Could not load content.',
                  onRetry: () {},
                ),
              ),
            ),

            const AppSectionHeader(title: 'Dividers'),
            const AppDivider(),

            const AppSectionHeader(title: 'Typography'),
            const _TypographySwatch(),

            const AppSectionHeader(title: 'Colors'),
            const _ColorSwatch(),

            const AppSectionHeader(title: 'Spacing'),
            const _SpacingSwatch(),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _TypographySwatch extends StatelessWidget {
  const _TypographySwatch();

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Headline Large', style: t.headlineLarge),
        Text('Title Large', style: t.titleLarge),
        Text('Body Large — the quick brown fox jumps.', style: t.bodyLarge),
        Text('Body Medium — the quick brown fox jumps.', style: t.bodyMedium),
        Text('Label Large', style: t.labelLarge),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final Map<String, Color> swatches = <String, Color>{
      'Primary': cs.primary,
      'Secondary': cs.secondary,
      'Tertiary': cs.tertiary,
      'Error': cs.error,
      'Success': semantic.success,
      'Warning': semantic.warning,
      'Info': semantic.info,
      'Background': AppColors.background,
      'Surface': cs.surface,
    };

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final MapEntry<String, Color> entry in swatches.entries)
          Column(
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: entry.value,
                  borderRadius: AppRadius.mediumAll,
                  border: Border.all(color: cs.outlineVariant),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(entry.key, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
      ],
    );
  }
}

class _SpacingSwatch extends StatelessWidget {
  const _SpacingSwatch();

  @override
  Widget build(BuildContext context) {
    final Map<String, double> steps = <String, double>{
      'xs': AppSpacing.xs,
      'sm': AppSpacing.sm,
      'md': AppSpacing.md,
      'lg': AppSpacing.lg,
      'xl': AppSpacing.xl,
      'xxl': AppSpacing.xxl,
    };
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final MapEntry<String, double> entry in steps.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs / 2),
            child: Row(
              children: <Widget>[
                SizedBox(width: 32, child: Text(entry.key)),
                Container(width: entry.value, height: 16, color: cs.primary),
              ],
            ),
          ),
      ],
    );
  }
}
