import 'package:flutter/material.dart';

import '../../../app/constants/app_radius.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/adult_workspace_colors.dart';

/// The presentation shown while `sessionProvider` restores the current
/// session. This screen deliberately owns no timer, initialization, session,
/// or navigation behavior; the router moves away from it as soon as startup
/// resolution completes.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      key: const Key('baymath_splash_screen'),
      backgroundColor: AdultWorkspaceColors.canvas,
      body: Stack(
        children: <Widget>[
          const Positioned(
            top: -170,
            right: -130,
            child: _AmbientOrb(
              diameter: 390,
              color: AdultWorkspaceColors.softBlue,
            ),
          ),
          Positioned(
            bottom: -220,
            left: -150,
            child: _AmbientOrb(
              diameter: 460,
              color: AdultWorkspaceColors.primary.withValues(alpha: 0.045),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - AppSpacing.lg * 2,
                    ),
                    child: Center(
                      child: TweenAnimationBuilder<double>(
                        duration:
                            reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        tween: Tween<double>(begin: 0, end: 1),
                        builder: (
                          BuildContext context,
                          double progress,
                          Widget? child,
                        ) {
                          return Opacity(
                            opacity: progress,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - progress)),
                              child: Transform.scale(
                                scale: 0.985 + 0.015 * progress,
                                child: child,
                              ),
                            ),
                          );
                        },
                        child: const _SplashBrandPanel(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientOrb extends StatelessWidget {
  const _AmbientOrb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _SplashBrandPanel extends StatelessWidget {
  const _SplashBrandPanel();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double panelWidth =
            constraints.maxWidth < 520 ? constraints.maxWidth : 520;
        final bool compact = panelWidth < 380;
        final double horizontalPadding = compact ? 24 : 40;
        final double logoWidth =
            (panelWidth - horizontalPadding * 2).clamp(0, 336).toDouble();

        return Container(
          key: const Key('splash_brand_panel'),
          width: panelWidth,
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            compact ? 28 : 36,
            horizontalPadding,
            compact ? 24 : 30,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.extraLargeAll,
            border: Border.all(color: AdultWorkspaceColors.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AdultWorkspaceColors.navy.withValues(alpha: 0.08),
                offset: const Offset(0, 18),
                blurRadius: 42,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Semantics(
                image: true,
                label: 'BayMath — Learn, Practice, Master',
                child: Image.asset(
                  'assets/images/baymath_logo.png',
                  key: const Key('splash_baymath_logo'),
                  width: logoWidth,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.lg : AppSpacing.xl),
              const Divider(height: 1, color: AdultWorkspaceColors.border),
              SizedBox(height: compact ? AppSpacing.md : 18),
              const _SplashLoadingStatus(),
            ],
          ),
        );
      },
    );
  }
}

class _SplashLoadingStatus extends StatelessWidget {
  const _SplashLoadingStatus();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const Key('splash_loading_status'),
      liveRegion: true,
      label: 'Preparing BayMath',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              strokeCap: StrokeCap.round,
              color: AdultWorkspaceColors.primary,
              backgroundColor: AdultWorkspaceColors.softBlue,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Preparing your learning space',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AdultWorkspaceColors.secondaryText,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
