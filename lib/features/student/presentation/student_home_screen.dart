import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/constants/app_layout_breakpoints.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/avatar_catalog.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../../../core/providers/student_session_provider.dart';
import 'endless_quiz_landing_screen.dart';
import 'student_lessons_screen.dart';
import 'student_quizzes_screen.dart';

/// Home screen colors that don't exist in the app-wide `AppColors` palette
/// (Statistics' purple). Kept local to this screen the same way
/// `student_login_screen.dart`'s `_LoginBrand` keeps its palette local —
/// promote into `app_colors.dart` if this direction is adopted elsewhere.
class _HomeBrand {
  const _HomeBrand._();

  static const Color statisticsPurple = Color(0xFF7C5CBF);
  static const Color statisticsPurpleContainer = Color(0xFFEFE9FB);
  static const Color pageBackground = Color(0xFFF4F7FC);
}

/// Icon-based v1 of the redesigned Student Home Screen — a colored 2x2
/// feature grid (Lessons/Quizzes/Statistics/Endless Quiz) replacing the
/// original plain button list. Deliberately uses Material [Icons] rather
/// than illustrated artwork throughout (avatar included, via
/// [AvatarCatalog]) — no new image assets exist for this yet; swap
/// [_FeatureCard.icon] / [AvatarCatalog] entries for real art later
/// without touching layout code.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StudentSession? session = ref.watch(studentSessionProvider);
    final Student? profile = ref.watch(ownStudentProfileProvider).value;
    final GradeLevel? gradeLevel = ref.watch(ownStudentGradeLevelProvider).value;
    final int? lessonCount = ref.watch(studentVisibleLessonsProvider).value?.length;
    final int? quizCount = ref.watch(studentVisibleQuizzesProvider).value?.length;

    if (session == null) {
      // Not reachable in normal use (this route is only ever entered after
      // a successful login), but kept as a safe fallback rather than
      // assuming non-null, same defensive shape the original bare version
      // of this screen used.
      return const Scaffold(body: Center(child: Text('No student session')));
    }

    final bool isCompact = AppLayoutBreakpoints.of(context) == AppLayoutType.compactLayout;

    return Scaffold(
      backgroundColor: _HomeBrand.pageBackground,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _HomeHeader(profile: profile, gradeLevel: gradeLevel),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _WelcomeBanner(name: profile?.fullName),
                        const SizedBox(height: AppSpacing.xs),
                        _FeatureGrid(
                          isCompact: isCompact,
                          lessonCount: lessonCount,
                          quizCount: quizCount,
                        ),
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

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({required this.profile, required this.gradeLevel});

  final Student? profile;
  final GradeLevel? gradeLevel;

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need your username and password to log back in."),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed == true) {
      ref.read(studentSessionProvider.notifier).state = null;
      if (context.mounted) context.go(AppRoutes.studentLogin);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AvatarOption avatar = AvatarCatalog.byId(profile?.avatarId);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Image.asset('assets/images/baymath_logo.png', height: 44, fit: BoxFit.contain),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatar.background,
                  child: Icon(avatar.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      profile?.fullName ?? '...',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (gradeLevel?.label != null && gradeLevel!.label.isNotEmpty)
                      Text(
                        gradeLevel!.label,
                        style: GoogleFonts.nunito(fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          IconButton(
            tooltip: 'Log out',
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.settings_outlined),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerHighest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({required this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFFEAF1FB), Color(0xFFF7F8FA)],
          ),
        ),
        child: Stack(
          children: <Widget>[
            const Positioned(top: 2, right: 210, child: _MathGlyph(symbol: '÷', angle: -0.2, size: 20)),
            const Positioned(top: 30, right: 160, child: _MathGlyph(symbol: 'x', angle: 0.2, size: 16)),
            const Positioned(top: 10, right: 110, child: _MathGlyph(symbol: '√', angle: -0.1, size: 22)),
            const Positioned(bottom: 4, right: 150, child: _MathGlyph(symbol: 'π', angle: 0.1, size: 18)),
            const Positioned(top: 18, right: 30, child: _MathGlyph(symbol: '×', angle: 0.15, size: 26)),
            const Positioned(bottom: 2, right: 70, child: _MathGlyph(symbol: '√', angle: 0.1, size: 20)),
            const Positioned(bottom: 20, right: 8, child: _MathGlyph(symbol: 'π', angle: -0.1, size: 24)),
            const Positioned(top: 4, right: 6, child: _MathGlyph(symbol: '+', angle: -0.15, size: 16)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Welcome, ${name ?? '...'}! 👋',
                  style: GoogleFonts.fredoka(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Keep learning, keep growing!',
                  style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MathGlyph extends StatelessWidget {
  const _MathGlyph({required this.symbol, this.angle = 0, this.size = 28});

  final String symbol;
  final double angle;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.25,
      child: Transform.rotate(
        angle: angle,
        child: Text(
          symbol,
          style: GoogleFonts.fredoka(
            fontSize: size,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.isCompact, required this.lessonCount, required this.quizCount});

  final bool isCompact;
  final int? lessonCount;
  final int? quizCount;

  @override
  Widget build(BuildContext context) {
    final List<Widget> cards = <Widget>[
      _FeatureCard(
        title: 'Lessons',
        subtitle: 'Explore and learn Mathematics',
        badgeLabel: lessonCount == null ? 'Mathematics Lessons' : '$lessonCount Mathematics Lessons',
        icon: Icons.menu_book_rounded,
        color: AppColors.primary,
        containerColor: AppColors.primaryContainer,
        onTap: () => context.push(AppRoutes.studentLessons),
      ),
      _FeatureCard(
        title: 'Quizzes',
        subtitle: 'Test your knowledge and skills',
        badgeLabel: quizCount == null ? 'Assessments' : '$quizCount Assessments',
        icon: Icons.assignment_turned_in_rounded,
        color: AppColors.secondary,
        containerColor: AppColors.secondaryContainer,
        onTap: () => context.push(AppRoutes.studentQuizzes),
      ),
      _FeatureCard(
        title: 'Statistics',
        subtitle: 'View your learning progress',
        badgeLabel: 'Track Your Progress',
        icon: Icons.bar_chart_rounded,
        color: _HomeBrand.statisticsPurple,
        containerColor: _HomeBrand.statisticsPurpleContainer,
        onTap: () => context.push(AppRoutes.studentStatistics),
      ),
      _FeatureCard(
        title: 'Endless Quiz',
        subtitle: 'Play and reach the leaderboard',
        badgeLabel: 'Play Anytime, Anywhere',
        icon: Icons.all_inclusive_rounded,
        color: AppColors.tertiary,
        containerColor: AppColors.tertiaryContainer,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const EndlessQuizLandingScreen()),
        ),
      ),
    ];

    if (isCompact) {
      return Column(
        children: <Widget>[
          for (final Widget card in cards)
            Padding(padding: const EdgeInsets.only(bottom: AppSpacing.md), child: SizedBox(height: 178, child: card)),
        ],
      );
    }

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.md,
        crossAxisSpacing: AppSpacing.md,
        mainAxisExtent: 178,
      ),
      children: cards,
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.icon,
    required this.color,
    required this.containerColor,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final IconData icon;
  final Color color;
  final Color containerColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  containerColor.withValues(alpha: 0.95),
                  containerColor.withValues(alpha: 0.55),
                ],
              ),
            ),
            child: Stack(
              children: <Widget>[
                // Soft decorative "wave" — a blurred, oversized circle
                // bleeding off the bottom-right corner, standing in for the
                // illustrated wave graphic in the target design until real
                // art exists.
                Positioned(
                  right: -30,
                  bottom: -40,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.16)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[color, color.withValues(alpha: 0.8)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: <BoxShadow>[
                            BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 23),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        style: GoogleFonts.fredoka(fontSize: 19, fontWeight: FontWeight.w700, color: color),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.nunito(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const Spacer(),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badgeLabel,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: <BoxShadow>[
                                BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Icon(Icons.chevron_right_rounded, color: color),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

