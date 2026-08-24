import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/constants/app_dimensions.dart';
import '../../../app/constants/app_spacing.dart';
import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/constants/avatar_catalog.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/quiz.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/widgets/widgets.dart';
import 'endless_quiz_landing_screen.dart';
import 'student_lessons_screen.dart';
import 'student_quizzes_screen.dart';

/// Student Home colors that extend the app's muted Material palette for one
/// repeated learning destination (Statistics). Everything else comes from
/// [AppColors], keeping this pilot visually compatible with the wider app.
abstract final class _StudentHomePalette {
  static const Color pageBackground = Color(0xFFF3F7FC);
  static const Color progress = Color(0xFF705CA3);
  static const Color progressContainer = Color(0xFFEDE8F7);
}

/// Landscape-only Student landing page.
///
/// This screen deliberately does not use `AppLayoutBreakpoints`: those
/// breakpoints currently infer the audience from width, while this route is
/// always the Student tablet experience even on a wide, high-resolution
/// device. The layout adapts to its available landscape width and height
/// directly without introducing a portrait-specific branch.
class StudentHomeScreen extends ConsumerWidget {
  const StudentHomeScreen({super.key});

  static const double _maxContentWidth = 1400;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StudentSession? session = ref.watch(studentSessionProvider);
    final AsyncValue<Student?> profileAsync = ref.watch(
      ownStudentProfileProvider,
    );
    final AsyncValue<GradeLevel?> gradeAsync = ref.watch(
      ownStudentGradeLevelProvider,
    );
    final AsyncValue<List<Lesson>> lessonsAsync = ref.watch(
      studentVisibleLessonsProvider,
    );
    final AsyncValue<List<Quiz>> quizzesAsync = ref.watch(
      studentVisibleQuizzesProvider,
    );

    if (session == null) {
      // Not reachable in normal use (this route is only entered after a
      // successful login), but retained as the original defensive fallback.
      return const Scaffold(body: Center(child: Text('No student session')));
    }

    final Student? profile = profileAsync.value;
    final GradeLevel? gradeLevel = gradeAsync.value;
    final int? lessonCount = lessonsAsync.value?.length;
    final int? quizCount = quizzesAsync.value?.length;

    return Scaffold(
      backgroundColor: _StudentHomePalette.pageBackground,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _HomeBackdrop()),
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isShort = constraints.maxHeight < 680;
                final bool isExpanded =
                    constraints.maxWidth >= 1500 &&
                    constraints.maxHeight >= 900;
                final double horizontalPadding =
                    isExpanded
                        ? AppSpacing.xl
                        : isShort
                        ? AppSpacing.md
                        : AppSpacing.lg;
                final double verticalPadding =
                    isShort ? AppSpacing.md : AppSpacing.lg;

                return Column(
                  children: <Widget>[
                    _HomeHeader(
                      profile: profile,
                      gradeLevel: gradeLevel,
                      isLoading: profileAsync.isLoading || gradeAsync.isLoading,
                      isShort: isShort,
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (
                          BuildContext context,
                          BoxConstraints bodyConstraints,
                        ) {
                          final double minContentHeight =
                              bodyConstraints.maxHeight - (verticalPadding * 2);

                          return SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              horizontalPadding,
                              verticalPadding,
                              horizontalPadding,
                              verticalPadding,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: _maxContentWidth,
                                  minHeight:
                                      minContentHeight > 0
                                          ? minContentHeight
                                          : 0,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    _WelcomeBanner(
                                      name: profile?.fullName,
                                      gradeLevel: gradeLevel,
                                      isShort: isShort,
                                      isExpanded: isExpanded,
                                    ),
                                    SizedBox(
                                      height:
                                          isShort
                                              ? AppSpacing.md
                                              : AppSpacing.lg,
                                    ),
                                    _LearningDestinationGrid(
                                      isShort: isShort,
                                      isExpanded: isExpanded,
                                      lessonCount: lessonCount,
                                      quizCount: quizCount,
                                      lessonsLoading: lessonsAsync.isLoading,
                                      quizzesLoading: quizzesAsync.isLoading,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: _StudentHomePalette.pageBackground),
          Opacity(
            opacity: 0.62,
            child: Image.asset(
              'assets/images/stat_background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.profile,
    required this.gradeLevel,
    required this.isLoading,
    required this.isShort,
  });

  final Student? profile;
  final GradeLevel? gradeLevel;
  final bool isLoading;
  final bool isShort;

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await AppDialog.show<bool>(
      context,
      title: 'Log out of BayMath?',
      type: AppDialogType.confirmation,
      icon: Icons.logout_rounded,
      message: "You'll need your username and password to log back in.",
      actions: <Widget>[
        AppButton(
          label: 'Stay here',
          size: AppComponentSize.large,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        AppButton(
          label: 'Log out',
          size: AppComponentSize.large,
          variant: AppButtonVariant.danger,
          leadingIcon: Icons.logout_rounded,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );

    if (confirmed == true) {
      ref.read(studentSessionProvider.notifier).state = null;
      if (context.mounted) context.go(AppRoutes.studentLogin);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AvatarOption avatar = AvatarCatalog.byId(profile?.avatarId);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.97),
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: StudentHomeScreen._maxContentWidth,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isShort ? AppSpacing.md : AppSpacing.lg,
              vertical: isShort ? AppSpacing.xs : AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                Image.asset(
                  'assets/images/baymath_logo.png',
                  height: isShort ? 42 : 48,
                  fit: BoxFit.contain,
                  semanticLabel: 'BayMath',
                ),
                const Spacer(),
                _StudentIdentity(
                  profile: profile,
                  gradeLevel: gradeLevel,
                  avatar: avatar,
                  isLoading: isLoading,
                  isShort: isShort,
                ),
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  onPressed: () => _confirmLogout(context, ref),
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('Log out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                    side: BorderSide(
                      color: colorScheme.error.withValues(alpha: 0.35),
                    ),
                    minimumSize: Size(
                      isShort ? 108 : 116,
                      isShort
                          ? AppDimensions.minTouchTarget
                          : AppDimensions.minTouchTarget + 4,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
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

class _StudentIdentity extends StatelessWidget {
  const _StudentIdentity({
    required this.profile,
    required this.gradeLevel,
    required this.avatar,
    required this.isLoading,
    required this.isShort,
  });

  final Student? profile;
  final GradeLevel? gradeLevel;
  final AvatarOption avatar;
  final bool isLoading;
  final bool isShort;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.fromLTRB(6, 6, AppSpacing.md, 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CircleAvatar(
            radius: isShort ? 20 : 22,
            backgroundColor: avatar.background,
            child: Icon(
              avatar.icon,
              color: Colors.white,
              size: isShort ? 20 : 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child:
                isLoading && profile == null
                    ? const _IdentityLoadingPlaceholder()
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          profile?.fullName ?? 'BayMath Student',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          gradeLevel?.label ?? 'Student workspace',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

class _IdentityLoadingPlaceholder extends StatelessWidget {
  const _IdentityLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final Color placeholder = Theme.of(context).colorScheme.outlineVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 112,
          height: 11,
          decoration: BoxDecoration(
            color: placeholder,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 72,
          height: 9,
          decoration: BoxDecoration(
            color: placeholder.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ],
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner({
    required this.name,
    required this.gradeLevel,
    required this.isShort,
    required this.isExpanded,
  });

  final String? name;
  final GradeLevel? gradeLevel;
  final bool isShort;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final String firstName = _firstName(name);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[AppColors.onPrimaryContainer, AppColors.primary],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isExpanded ? AppSpacing.xl : AppSpacing.lg,
            vertical: isShort ? AppSpacing.md : AppSpacing.lg,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        gradeLevel == null
                            ? 'YOUR MATH SPACE'
                            : '${gradeLevel!.label.toUpperCase()}  |  YOUR MATH SPACE',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    SizedBox(height: isShort ? 8 : 12),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        firstName.isEmpty
                            ? 'Welcome back.'
                            : 'Welcome back, $firstName.',
                        key: ValueKey<String>(firstName),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.lexend(
                          color: Colors.white,
                          fontSize:
                              isExpanded
                                  ? 32
                                  : isShort
                                  ? 25
                                  : 28,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose where to begin and keep your math momentum going.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: isShort ? 13 : 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isShort ? AppSpacing.md : AppSpacing.xl),
              _MathConstellation(
                width:
                    isExpanded
                        ? 300
                        : isShort
                        ? 220
                        : 260,
                compact: isShort,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _firstName(String? fullName) {
    final String trimmed = fullName?.trim() ?? '';
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _MathConstellation extends StatelessWidget {
  const _MathConstellation({required this.width, required this.compact});

  final double width;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double tileSize = compact ? 42 : 50;

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: compact ? 88 : 108,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 4,
              top: compact ? 8 : 12,
              child: _MathTile(symbol: 'π', size: tileSize, angle: -0.08),
            ),
            Positioned(
              left: width * 0.32,
              bottom: 2,
              child: _MathTile(symbol: '÷', size: tileSize, angle: 0.06),
            ),
            Positioned(
              right: width * 0.18,
              top: 0,
              child: _MathTile(symbol: '√', size: tileSize, angle: -0.04),
            ),
            Positioned(
              right: 0,
              bottom: compact ? 8 : 10,
              child: _MathTile(symbol: 'x²', size: tileSize, angle: 0.08),
            ),
          ],
        ),
      ),
    );
  }
}

class _MathTile extends StatelessWidget {
  const _MathTile({
    required this.symbol,
    required this.size,
    required this.angle,
  });

  final String symbol;
  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Text(
          symbol,
          style: GoogleFonts.lexend(
            color: Colors.white.withValues(alpha: 0.88),
            fontSize: symbol.length > 1 ? size * 0.32 : size * 0.44,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LearningDestinationGrid extends StatelessWidget {
  const _LearningDestinationGrid({
    required this.isShort,
    required this.isExpanded,
    required this.lessonCount,
    required this.quizCount,
    required this.lessonsLoading,
    required this.quizzesLoading,
  });

  final bool isShort;
  final bool isExpanded;
  final int? lessonCount;
  final int? quizCount;
  final bool lessonsLoading;
  final bool quizzesLoading;

  @override
  Widget build(BuildContext context) {
    final List<_LearningDestination> destinations = <_LearningDestination>[
      _LearningDestination(
        eyebrow: 'EXPLORE',
        title: 'Lessons',
        subtitle: 'Build new skills with guided mathematics lessons.',
        metaLabel:
            lessonCount == null
                ? 'Open lessons'
                : '$lessonCount ${lessonCount == 1 ? 'lesson' : 'lessons'}',
        metaLoading: lessonsLoading,
        icon: Icons.menu_book_rounded,
        color: AppColors.primary,
        containerColor: AppColors.primaryContainer,
        onTap: () => context.push(AppRoutes.studentLessons),
      ),
      _LearningDestination(
        eyebrow: 'PRACTICE',
        title: 'Quizzes',
        subtitle: 'Check your understanding and strengthen your skills.',
        metaLabel:
            quizCount == null
                ? 'Open assessments'
                : '$quizCount ${quizCount == 1 ? 'assessment' : 'assessments'}',
        metaLoading: quizzesLoading,
        icon: Icons.assignment_turned_in_rounded,
        color: AppColors.secondary,
        containerColor: AppColors.secondaryContainer,
        onTap: () => context.push(AppRoutes.studentQuizzes),
      ),
      _LearningDestination(
        eyebrow: 'PROGRESS',
        title: 'Statistics',
        subtitle: 'See your learning progress and growing math mastery.',
        metaLabel: 'View your progress',
        metaLoading: false,
        icon: Icons.insights_rounded,
        color: _StudentHomePalette.progress,
        containerColor: _StudentHomePalette.progressContainer,
        onTap: () => context.push(AppRoutes.studentStatistics),
      ),
      _LearningDestination(
        eyebrow: 'CHALLENGE',
        title: 'Endless Quiz',
        subtitle: 'Keep answering, build a streak, and climb the leaderboard.',
        metaLabel: 'Start a new round',
        metaLoading: false,
        icon: Icons.all_inclusive_rounded,
        color: AppColors.tertiary,
        containerColor: AppColors.tertiaryContainer,
        onTap:
            () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const EndlessQuizLandingScreen(),
              ),
            ),
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double gap =
            isExpanded
                ? AppSpacing.lg
                : isShort
                ? 12
                : AppSpacing.md;
        final double cardWidth = (constraints.maxWidth - (gap * 3)) / 4;
        final double textScale = MediaQuery.textScalerOf(context).scale(1);
        final double scaleAllowance =
            ((textScale - 1).clamp(0.0, 1.0)).toDouble() * 52;
        final double widthDrivenHeight = cardWidth * 0.76;
        final double baseHeight =
            isExpanded
                ? 258
                : isShort
                ? 238
                : 236;
        final double cardHeight =
            widthDrivenHeight
                .clamp(baseHeight, isExpanded ? 278 : 252)
                .toDouble() +
            scaleAllowance;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: destinations.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (BuildContext context, int index) {
            return _StudentFeatureCard(destination: destinations[index]);
          },
        );
      },
    );
  }
}

class _LearningDestination {
  const _LearningDestination({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.metaLabel,
    required this.metaLoading,
    required this.icon,
    required this.color,
    required this.containerColor,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String metaLabel;
  final bool metaLoading;
  final IconData icon;
  final Color color;
  final Color containerColor;
  final VoidCallback onTap;
}

class _StudentFeatureCard extends StatefulWidget {
  const _StudentFeatureCard({required this.destination});

  final _LearningDestination destination;

  @override
  State<_StudentFeatureCard> createState() => _StudentFeatureCardState();
}

class _StudentFeatureCardState extends State<_StudentFeatureCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final _LearningDestination destination = widget.destination;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label:
          '${destination.title}. ${destination.subtitle} ${destination.metaLabel}.',
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.onPrimaryContainer.withValues(
                  alpha: _pressed ? 0.04 : 0.08,
                ),
                blurRadius: _pressed ? 8 : 18,
                offset: Offset(0, _pressed ? 3 : 8),
              ),
            ],
          ),
          child: Material(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: destination.onTap,
              onHighlightChanged: (bool value) {
                if (_pressed != value) setState(() => _pressed = value);
              },
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: destination.color.withValues(alpha: 0.2),
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      right: -42,
                      top: -48,
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: destination.containerColor.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: destination.containerColor,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  destination.icon,
                                  color: destination.color,
                                  size: 27,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                width: AppDimensions.minTouchTarget,
                                height: AppDimensions.minTouchTarget,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: destination.color,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            destination.eyebrow,
                            style: GoogleFonts.inter(
                              color: destination.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            destination.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.lexend(
                              color: AppColors.textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              height: 1.18,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            destination.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                          const Spacer(),
                          _DestinationMeta(
                            label: destination.metaLabel,
                            isLoading: destination.metaLoading,
                            color: destination.color,
                            containerColor: destination.containerColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationMeta extends StatelessWidget {
  const _DestinationMeta({
    required this.label,
    required this.isLoading,
    required this.color,
    required this.containerColor,
  });

  final String label;
  final bool isLoading;
  final Color color;
  final Color containerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: containerColor.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          if (isLoading) ...<Widget>[
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
            const SizedBox(width: AppSpacing.sm),
          ] else ...<Widget>[
            Icon(Icons.arrow_right_alt_rounded, color: color, size: 20),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              isLoading ? 'Loading...' : label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
