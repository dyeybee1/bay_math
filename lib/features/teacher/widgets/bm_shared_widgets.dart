import 'package:flutter/material.dart';

import '../../../app/constants/app_colors.dart';
import '../../../app/constants/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BmPageHeader
// ─────────────────────────────────────────────────────────────────────────────

/// Shared page-level header: title + subtitle on the left, primary action
/// (e.g. "New Lesson" / "New Question") on the right.
///
/// Used by both [LessonsScreen] and [QuestionBankScreen] to keep the
/// heading style visually consistent.
class BmPageHeader extends StatelessWidget {
  const BmPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final String title;
  final String subtitle;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: AppTextStyles.lexend(
                    size: 26,
                    weight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.inter(
                    size: 13,
                    color: AppColors.textSoft,
                  ),
                ),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BmSourceBadge
// ─────────────────────────────────────────────────────────────────────────────

/// "Built-in" (amber) or "My Content" (accent-soft) pill badge.
///
/// Pass [isBuiltIn] to switch between variants. No other styling
/// differences — both are the same size / shape.
class BmSourceBadge extends StatelessWidget {
  const BmSourceBadge({super.key, required this.isBuiltIn});

  final bool isBuiltIn;

  @override
  Widget build(BuildContext context) {
    final Color bg = isBuiltIn ? AppColors.amberSoft : AppColors.accentSoft;
    final Color fg = isBuiltIn ? AppColors.amber : AppColors.accent;
    final String label = isBuiltIn ? 'Built-in' : 'My Content';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.inter(
          size: 12,
          weight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BmIconActionButton
// ─────────────────────────────────────────────────────────────────────────────

/// 32×32px bordered icon button with hover-state colour transitions.
///
/// Used for Edit (pencil) and Delete (trash) actions in the Question Bank
/// row.  Set [isDanger] = true on the Delete button to activate the red
/// hover state (dangerSoft bg, danger border/icon).
class BmIconActionButton extends StatefulWidget {
  const BmIconActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isDanger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isDanger;

  @override
  State<BmIconActionButton> createState() => _BmIconActionButtonState();
}

class _BmIconActionButtonState extends State<BmIconActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = _hovered && widget.isDanger
        ? AppColors.danger
        : AppColors.line;
    final Color bgColor = _hovered
        ? (widget.isDanger ? AppColors.dangerSoft : AppColors.graySoft)
        : AppColors.card;
    final Color iconColor = _hovered && widget.isDanger
        ? AppColors.danger
        : AppColors.textSoft;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Icon(widget.icon, size: 16, color: iconColor),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BmPrimaryButton
// ─────────────────────────────────────────────────────────────────────────────

/// Navy-filled pill button (10px radius) used for page-level primary
/// actions ("New Lesson", "New Question").
class BmPrimaryButton extends StatefulWidget {
  const BmPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData icon;

  @override
  State<BmPrimaryButton> createState() => _BmPrimaryButtonState();
}

class _BmPrimaryButtonState extends State<BmPrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.navy2 : AppColors.navy,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(widget.icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTextStyles.inter(
                  size: 14,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
