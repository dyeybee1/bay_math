import 'package:flutter/material.dart';

import '../../../../app/constants/app_radius.dart';
import '../../../../app/constants/app_spacing.dart';
import '../../../../app/theme/adult_workspace_colors.dart';
import '../../../../core/widgets/widgets.dart';

class AdminDrilldownPage extends StatelessWidget {
  const AdminDrilldownPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.eyebrow = 'ADMIN DIRECTORY',
    this.summary,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final String eyebrow;
  final Widget? summary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdultWorkspaceColors.canvas,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _AdminDrilldownTopBar(onBack: () => Navigator.maybePop(context)),
            Expanded(
              child: AppPageContainer(
                scrollable: true,
                applySafeArea: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1040),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        AdminDrilldownHeader(
                          eyebrow: eyebrow,
                          title: title,
                          subtitle: subtitle,
                          icon: icon,
                          summary: summary,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminDrilldownTopBar extends StatelessWidget {
  const _AdminDrilldownTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AdultWorkspaceColors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Back',
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              style: IconButton.styleFrom(
                foregroundColor: AdultWorkspaceColors.navy,
                backgroundColor: AdultWorkspaceColors.softBlue,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.mediumAll,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const Icon(
              Icons.admin_panel_settings_outlined,
              color: AdultWorkspaceColors.primary,
              size: 21,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'BayMath Admin',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AdultWorkspaceColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminDrilldownHeader extends StatelessWidget {
  const AdminDrilldownHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.summary,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              eyebrow,
              style: const TextStyle(
                color: AdultWorkspaceColors.primaryMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.15,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AdultWorkspaceColors.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AdultWorkspaceColors.secondaryText,
                height: 1.4,
              ),
            ),
          ],
        );

        final Widget visual = Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: AdultWorkspaceColors.softBlue,
            borderRadius: AppRadius.largeAll,
          ),
          child: Icon(icon, color: AdultWorkspaceColors.primary, size: 28),
        );

        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              visual,
              const SizedBox(height: AppSpacing.md),
              heading,
              if (summary != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                summary!,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            visual,
            const SizedBox(width: AppSpacing.md),
            Expanded(child: heading),
            if (summary != null) ...<Widget>[
              const SizedBox(width: AppSpacing.lg),
              summary!,
            ],
          ],
        );
      },
    );
  }
}

class AdminCountPill extends StatelessWidget {
  const AdminCountPill({
    super.key,
    required this.label,
    this.icon = Icons.format_list_bulleted_rounded,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AdultWorkspaceColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 17, color: AdultWorkspaceColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AdultWorkspaceColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminDrilldownPanel extends StatelessWidget {
  const AdminDrilldownPanel({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: AdultWorkspaceColors.border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A173D5A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AdminDirectoryRow extends StatefulWidget {
  const AdminDirectoryRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.metadata,
    this.trailing,
    this.onTap,
    this.semanticLabel,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget metadata;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<AdminDirectoryRow> createState() => _AdminDirectoryRowState();
}

class _AdminDirectoryRowState extends State<AdminDirectoryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Widget content = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget identity = Row(
          children: <Widget>[
            widget.leading,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AdultWorkspaceColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AdultWorkspaceColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 700) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                identity,
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Expanded(child: widget.metadata),
                    if (widget.trailing != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      widget.trailing!,
                    ],
                  ],
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: <Widget>[
              Expanded(flex: 5, child: identity),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 3, child: widget.metadata),
              if (widget.trailing != null) ...<Widget>[
                const SizedBox(width: AppSpacing.lg),
                widget.trailing!,
              ],
            ],
          ),
        );
      },
    );

    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor:
            widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        onEnter:
            widget.onTap == null
                ? null
                : (_) => setState(() => _hovered = true),
        onExit:
            widget.onTap == null
                ? null
                : (_) => setState(() => _hovered = false),
        child: Material(
          color: _hovered ? AdultWorkspaceColors.paleBlue : Colors.white,
          child: InkWell(
            onTap: widget.onTap,
            hoverColor: AdultWorkspaceColors.paleBlue,
            focusColor: AdultWorkspaceColors.softBlue,
            child: content,
          ),
        ),
      ),
    );
  }
}

class AdminInitialsAvatar extends StatelessWidget {
  const AdminInitialsAvatar({
    super.key,
    required this.fullName,
    this.icon,
    this.size = AppComponentSize.medium,
  });

  final String fullName;
  final IconData? icon;
  final AppComponentSize size;

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      initials: icon == null ? adminInitials(fullName) : null,
      icon: icon ?? Icons.person_outline_rounded,
      size: size,
      semanticLabel: '$fullName avatar',
    );
  }
}

String adminInitials(String fullName) {
  final List<String> parts =
      fullName
          .trim()
          .split(RegExp(r'\s+'))
          .where((String part) => part.isNotEmpty)
          .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class AdminMetadataLabel extends StatelessWidget {
  const AdminMetadataLabel({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color foreground = color ?? AdultWorkspaceColors.secondaryText;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 18, color: foreground),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class AdminViewDetailsAffordance extends StatelessWidget {
  const AdminViewDetailsAffordance({super.key, this.label = 'View details'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AdultWorkspaceColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        const Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: AdultWorkspaceColors.primary,
        ),
      ],
    );
  }
}

class AdminListDivider extends StatelessWidget {
  const AdminListDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 74,
      color: AdultWorkspaceColors.border,
    );
  }
}
