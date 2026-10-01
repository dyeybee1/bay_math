import 'package:flutter/material.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/constants/app_text_styles.dart';

/// Shared desktop shell for Teacher pages pushed from dashboard cards.
class TeacherDrilldownPage extends StatelessWidget {
  const TeacherDrilldownPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        centerTitle: false,
        toolbarHeight: 78,
        titleSpacing: AppSpacing.xs,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              title,
              style: AppTextStyles.lexend(
                size: 21,
                weight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.inter(size: 12, color: AppColors.textSoft),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.line),
        ),
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final EdgeInsets padding = EdgeInsets.symmetric(
              horizontal:
                  constraints.maxWidth >= 900 ? AppSpacing.xl : AppSpacing.md,
              vertical: AppSpacing.lg,
            );
            return SingleChildScrollView(
              padding: padding,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact context panel placed above a drill-down collection.
class TeacherListSummary extends StatelessWidget {
  const TeacherListSummary({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.mediumAll,
            ),
            child: Icon(icon, size: 21, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: AppTextStyles.inter(
                    size: 14,
                    weight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: AppTextStyles.inter(
                    size: 12,
                    color: AppColors.textSoft,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (badge != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            badge!,
          ],
        ],
      ),
    );
  }
}

/// Two columns on comfortable desktop widths and one column when narrow.
class TeacherResponsiveGrid extends StatelessWidget {
  const TeacherResponsiveGrid({
    super.key,
    required this.children,
    this.twoColumnBreakpoint = 760,
  });

  final List<Widget> children;
  final double twoColumnBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns = constraints.maxWidth >= twoColumnBreakpoint;
        final double itemWidth =
            twoColumns
                ? (constraints.maxWidth - AppSpacing.md) / 2
                : constraints.maxWidth;
        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

/// Bordered Teacher card with desktop hover and Material interaction states.
class TeacherDrilldownCard extends StatefulWidget {
  const TeacherDrilldownCard({
    super.key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(AppSpacing.md),
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  @override
  State<TeacherDrilldownCard> createState() => _TeacherDrilldownCardState();
}

class _TeacherDrilldownCardState extends State<TeacherDrilldownCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bool interactive = widget.onTap != null;
    final Color background =
        interactive && _hovered ? AppColors.accentSoft : AppColors.card;
    final Color border =
        interactive && _hovered
            ? AppColors.accent.withValues(alpha: 0.45)
            : AppColors.line;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.navy.withValues(
              alpha: interactive && _hovered ? 0.09 : 0.035,
            ),
            blurRadius: interactive && _hovered ? 18 : 10,
            offset: Offset(0, interactive && _hovered ? 7 : 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.largeAll,
        child: InkWell(
          borderRadius: AppRadius.largeAll,
          onTap: widget.onTap,
          mouseCursor:
              interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
          focusColor: AppColors.accent.withValues(alpha: 0.10),
          splashColor: AppColors.accent.withValues(alpha: 0.12),
          child: Padding(padding: widget.padding, child: widget.child),
        ),
      ),
    );

    card = MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: interactive ? (_) => setState(() => _hovered = true) : null,
      onExit: interactive ? (_) => setState(() => _hovered = false) : null,
      child: card,
    );

    if (widget.semanticLabel != null) {
      card = Semantics(
        button: interactive,
        label: widget.semanticLabel,
        child: card,
      );
    }
    return card;
  }
}

/// Gives asynchronous and empty states a deliberate contained footprint.
class TeacherStatePanel extends StatelessWidget {
  const TeacherStatePanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 300),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.largeAll,
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}
