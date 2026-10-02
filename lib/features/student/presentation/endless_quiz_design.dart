import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';

/// Endless Quiz extends the approved Student palette only for the streak
/// mechanic. Every base surface and semantic state comes from [AppColors].
abstract final class EndlessQuizColors {
  static const Color pageBackground = Color(0xFFF3F7FC);
  static const Color challengeBlue = Color(0xFF2859DB);
  static const Color challengeInk = Color(0xFF24427D);
  static const Color challengeMuted = Color(0xFF5B6E90);
  static const Color lavender = Color(0xFF8F69D3);
  static const Color lavenderSoft = Color(0xFFF0EAFF);
  static const Color mintSoft = Color(0xFFE6F4EE);
  static const Color goldSoft = Color(0xFFFFF4D9);
  static const Color streak = AppColors.tertiary;
  static const Color streakSoft = AppColors.tertiaryContainer;
  static const Color success = AppColors.secondary;
  static const Color successSoft = AppColors.secondaryContainer;
  static const Color danger = AppColors.error;
  static const Color dangerSoft = AppColors.errorContainer;
  static const Color silver = Color(0xFF8A94A6);
  static const Color silverSoft = Color(0xFFE8ECF2);
  static const Color bronze = Color(0xFFA86834);
  static const Color bronzeSoft = Color(0xFFF3E2D2);
}

TextStyle endlessTitleStyle(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = AppColors.textPrimary,
}) {
  return GoogleFonts.lexend(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: 1.2,
  );
}

TextStyle endlessBodyStyle(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = AppColors.textPrimary,
  double height = 1.4,
}) {
  return GoogleFonts.inter(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

class EndlessQuizBackdrop extends StatelessWidget {
  const EndlessQuizBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const ColoredBox(color: EndlessQuizColors.pageBackground),
        IgnorePointer(
          child: Opacity(
            opacity: 0.58,
            child: Image.asset(
              'assets/images/stat_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class EndlessQuizHeader extends StatelessWidget {
  const EndlessQuizHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.action,
    this.brandLeading = false,
    this.showBrand = true,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget? action;
  final bool brandLeading;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final bool short = MediaQuery.sizeOf(context).height < 680;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.98),
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: short ? AppSpacing.md : AppSpacing.lg,
              vertical: short ? AppSpacing.xs : AppSpacing.sm,
            ),
            child: Semantics(
              container: true,
              header: true,
              child: Row(
                children: <Widget>[
                  EndlessIconButton(
                    tooltip: 'Back',
                    icon: Icons.arrow_back_rounded,
                    onPressed: onBack,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (brandLeading && showBrand) ...<Widget>[
                    const _BayMathBrand(),
                    const SizedBox(width: AppSpacing.md),
                    Container(
                      width: 1,
                      height: 32,
                      color: colors.outlineVariant,
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: endlessTitleStyle(short ? 19 : 21),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: endlessBodyStyle(
                            11,
                            weight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) ...<Widget>[
                    action!,
                    const SizedBox(width: AppSpacing.md),
                  ],
                  if (!brandLeading && showBrand) const _BayMathBrand(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BayMathBrand extends StatelessWidget {
  const _BayMathBrand();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'BayMath',
      image: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Image.asset(
            'assets/images/baymath_logo_for_login.png',
            width: 42,
            height: 34,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text('BayMath', style: endlessTitleStyle(17)),
        ],
      ),
    );
  }
}

class EndlessIconButton extends StatelessWidget {
  const EndlessIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppDimensions.minTouchTarget),
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.72),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class EndlessPageBody extends StatelessWidget {
  const EndlessPageBody({super.key, required this.child, this.maxWidth = 1400});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool short = size.height < 680;
    final bool expanded = size.width >= 1500 && size.height >= 900;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal:
            expanded
                ? AppSpacing.xl
                : short
                ? AppSpacing.md
                : AppSpacing.lg,
        vertical:
            expanded
                ? AppSpacing.xl
                : short
                ? AppSpacing.md
                : AppSpacing.lg,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

class EndlessPaper extends StatelessWidget {
  const EndlessPaper({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color = Colors.white,
    this.radius = 24,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow:
            elevated
                ? <BoxShadow>[
                  BoxShadow(
                    color: AppColors.onPrimaryContainer.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ]
                : null,
      ),
      child: child,
    );
  }
}

class EndlessPrimaryButton extends StatelessWidget {
  const EndlessPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expand = false,
    this.isLoading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool expand;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final Widget button = FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon:
          isLoading
              ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(strokeWidth: 2.3),
              )
              : Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 22),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: endlessBodyStyle(14, weight: FontWeight.w700),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class EndlessSecondaryButton extends StatelessWidget {
  const EndlessSecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.expand = false,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool expand;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color foreground = danger ? AppColors.error : AppColors.primary;
    final Widget button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        foregroundColor: foreground,
        side: BorderSide(color: foreground.withValues(alpha: 0.32)),
        backgroundColor: Colors.white.withValues(alpha: 0.78),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: endlessBodyStyle(14, weight: FontWeight.w700),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class EndlessStatePanel extends StatelessWidget {
  const EndlessStatePanel({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: EndlessPaper(
          child: Semantics(
            liveRegion: loading,
            label: '$title. $message',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child:
                      loading
                          ? const Padding(
                            padding: EdgeInsets.all(17),
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                          : Icon(icon, color: AppColors.primary, size: 29),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: endlessTitleStyle(19),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: endlessBodyStyle(13, color: AppColors.textSecondary),
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  EndlessSecondaryButton(
                    label: actionLabel!,
                    icon: Icons.refresh_rounded,
                    onPressed: onAction,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
