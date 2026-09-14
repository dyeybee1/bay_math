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
import 'student_curriculum_order.dart';
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

  static const double _maxContentWidth = 1280;

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
    final List<Lesson>? visibleLessons = lessonsAsync.value;
    final List<Quiz>? visibleQuizzes = quizzesAsync.value;
    final int? lessonCount =
        visibleLessons == null
            ? null
            : orderStudentLessons(visibleLessons).length;
    final int? quizCount =
        visibleQuizzes == null
            ? null
            : orderStudentQuizzes(visibleQuizzes).length;

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
                          final double welcomeHeight =
                              isExpanded
                                  ? 144
                                  : isShort
                                  ? 108
                                  : 128;
                          final double sectionGap =
                              isShort ? 12 : AppSpacing.lg;
                          final double gridGap =
                              isExpanded
                                  ? AppSpacing.lg
                                  : isShort
                                  ? 12
                                  : AppSpacing.md;
                          final double availableCardHeight =
                              (minContentHeight -
                                  welcomeHeight -
                                  sectionGap -
                                  gridGap) /
                              2;
                          final double cardHeight =
                              availableCardHeight
                                  .clamp(
                                    isShort ? 184.0 : 208.0,
                                    isExpanded ? 268.0 : 240.0,
                                  )
                                  .toDouble();

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
                                      height: welcomeHeight,
                                    ),
                                    SizedBox(height: sectionGap),
                                    _LearningDestinationGrid(
                                      isShort: isShort,
                                      isExpanded: isExpanded,
                                      cardHeight: cardHeight,
                                      gap: gridGap,
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
                  'assets/images/baymath_logo_for_login.png',
                  height: isShort ? 42 : 48,
                  fit: BoxFit.contain,
                  semanticLabel: 'BayMath',
                ),
                const Spacer(),
                PopupMenuButton<_StudentAccountAction>(
                  tooltip: 'Student account menu',
                  onSelected: (_StudentAccountAction action) {
                    if (action == _StudentAccountAction.logout) {
                      _confirmLogout(context, ref);
                    }
                  },
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  itemBuilder:
                      (BuildContext context) =>
                          <PopupMenuEntry<_StudentAccountAction>>[
                            PopupMenuItem<_StudentAccountAction>(
                              value: _StudentAccountAction.logout,
                              height: 52,
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    Icons.logout_rounded,
                                    color: colorScheme.error,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'Log out',
                                    style: GoogleFonts.inter(
                                      color: colorScheme.error,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                  child: _StudentIdentity(
                    profile: profile,
                    gradeLevel: gradeLevel,
                    avatar: avatar,
                    isLoading: isLoading,
                    isShort: isShort,
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

enum _StudentAccountAction { logout }

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
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
        maxWidth: 300,
      ),
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
          const SizedBox(width: 6),
          Icon(
            Icons.expand_more_rounded,
            size: 22,
            color: colorScheme.onSurfaceVariant,
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
    required this.height,
  });

  final String? name;
  final GradeLevel? gradeLevel;
  final bool isShort;
  final bool isExpanded;
  final double height;

  @override
  Widget build(BuildContext context) {
    final String firstName = _firstName(name);

    return SizedBox(
      height: height,
      child: ClipRRect(
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
              vertical: isShort ? 12 : AppSpacing.md,
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
                      SizedBox(height: isShort ? 5 : 8),
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
                                    ? 31
                                    : isShort
                                    ? 24
                                    : 27,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ),
                      SizedBox(height: isShort ? 3 : 5),
                      Text(
                        'Pick a path and keep your math momentum going!',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: isShort ? 14 : 15,
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
                          ? 272
                          : isShort
                          ? 184
                          : 224,
                  compact: isShort,
                ),
              ],
            ),
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
    final double tileSize = compact ? 38 : 44;

    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: compact ? 72 : 88,
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
    required this.cardHeight,
    required this.gap,
    required this.lessonCount,
    required this.quizCount,
    required this.lessonsLoading,
    required this.quizzesLoading,
  });

  final bool isShort;
  final bool isExpanded;
  final double cardHeight;
  final double gap;
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
        subtitle: 'Learn new math skills',
        statusLabel:
            lessonCount == null
                ? 'Lessons ready'
                : '$lessonCount ${lessonCount == 1 ? 'lesson' : 'lessons'}',
        statusLoading: lessonsLoading,
        ctaLabel: 'Open lessons',
        icon: Icons.menu_book_rounded,
        color: AppColors.primary,
        containerColor: AppColors.primaryContainer,
        onTap: () => context.push(AppRoutes.studentLessons),
      ),
      _LearningDestination(
        eyebrow: 'PRACTICE',
        title: 'Quizzes',
        subtitle: "Practice what you've learned",
        statusLabel:
            quizCount == null
                ? 'Quizzes ready'
                : '$quizCount ${quizCount == 1 ? 'assessment' : 'assessments'}',
        statusLoading: quizzesLoading,
        ctaLabel: 'Open quizzes',
        icon: Icons.assignment_turned_in_rounded,
        color: AppColors.secondary,
        containerColor: AppColors.secondaryContainer,
        onTap: () => context.push(AppRoutes.studentQuizzes),
      ),
      _LearningDestination(
        eyebrow: 'PROGRESS',
        title: 'Statistics',
        subtitle: "See how much you've improved",
        statusLabel: 'Your progress',
        statusLoading: false,
        ctaLabel: 'View stats',
        icon: Icons.insights_rounded,
        color: _StudentHomePalette.progress,
        containerColor: _StudentHomePalette.progressContainer,
        onTap: () => context.push(AppRoutes.studentStatistics),
      ),
      _LearningDestination(
        eyebrow: 'CHALLENGE',
        title: 'Endless Quiz',
        subtitle: 'Play, earn streaks, and climb the ranks',
        statusLabel: 'Streak challenge',
        statusLoading: false,
        ctaLabel: 'Play now',
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
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: destinations.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: cardHeight,
          ),
          itemBuilder: (BuildContext context, int index) {
            return _StudentFeatureCard(
              destination: destinations[index],
              compact: isShort,
              expanded: isExpanded,
            );
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
    required this.statusLabel,
    required this.statusLoading,
    required this.ctaLabel,
    required this.icon,
    required this.color,
    required this.containerColor,
    required this.onTap,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String statusLabel;
  final bool statusLoading;
  final String ctaLabel;
  final IconData icon;
  final Color color;
  final Color containerColor;
  final VoidCallback onTap;
}

class _StudentFeatureCard extends StatefulWidget {
  const _StudentFeatureCard({
    required this.destination,
    required this.compact,
    required this.expanded,
  });

  final _LearningDestination destination;
  final bool compact;
  final bool expanded;

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
      key: ValueKey<String>('student-home-card-${destination.title}'),
      button: true,
      label:
          '${destination.title}. ${destination.subtitle}. '
          '${destination.statusLabel}. ${destination.ctaLabel}.',
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
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
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: destination.onTap,
              onHighlightChanged: (bool value) {
                if (_pressed != value) setState(() => _pressed = value);
              },
              child: Ink(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      destination.containerColor.withValues(alpha: 0.62),
                      colorScheme.surface,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: destination.color.withValues(alpha: 0.2),
                  ),
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      right: -34,
                      top: -52,
                      child: Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: destination.color.withValues(alpha: 0.07),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.all(
                        widget.expanded ? AppSpacing.lg : AppSpacing.md,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            width: widget.expanded ? 78 : 66,
                            height: widget.expanded ? 78 : 66,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: destination.color,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: destination.color.withValues(
                                    alpha: 0.2,
                                  ),
                                  blurRadius: 16,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Icon(
                              destination.icon,
                              color: Colors.white,
                              size: widget.expanded ? 38 : 32,
                            ),
                          ),
                          SizedBox(width: widget.compact ? 14 : AppSpacing.lg),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  destination.eyebrow,
                                  style: GoogleFonts.inter(
                                    color: destination.color,
                                    fontSize: widget.compact ? 11 : 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  destination.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.lexend(
                                    color: AppColors.textPrimary,
                                    fontSize:
                                        widget.expanded
                                            ? 27
                                            : widget.compact
                                            ? 22
                                            : 24,
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                                ),
                                SizedBox(height: widget.compact ? 5 : 7),
                                Text(
                                  destination.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: AppColors.textSecondary,
                                    fontSize: widget.compact ? 14 : 15,
                                    fontWeight: FontWeight.w500,
                                    height: 1.3,
                                  ),
                                ),
                                SizedBox(height: widget.compact ? 10 : 14),
                                Row(
                                  children: <Widget>[
                                    Flexible(
                                      child: _DestinationStatus(
                                        label: destination.statusLabel,
                                        isLoading: destination.statusLoading,
                                        color: destination.color,
                                        containerColor:
                                            destination.containerColor,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    _DestinationCta(
                                      label: destination.ctaLabel,
                                      color: destination.color,
                                      compact: widget.compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
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

class _DestinationStatus extends StatelessWidget {
  const _DestinationStatus({
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
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
          ],
          Expanded(
            child: Text(
              isLoading ? 'Loading...' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 13,
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

class _DestinationCta extends StatelessWidget {
  const _DestinationCta({
    required this.label,
    required this.color,
    required this.compact,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 40),
      padding: EdgeInsets.symmetric(horizontal: compact ? 11 : 14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: compact ? 13 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(
            Icons.arrow_forward_rounded,
            color: Colors.white,
            size: 19,
          ),
        ],
      ),
    );
  }
}
