import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/student_statistics.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/widgets.dart';
import '../data/student_statistics_providers.dart';

/// Phase 8 (Student Statistics) — Part 3: the visible screen.
///
/// Watches [studentStatisticsProvider] (Part 2) for the whole page — every
/// tile/chart/bar here loads together as one `AsyncValue`, matching that
/// provider's own doc comment on why that granularity is right for this
/// screen (unlike e.g. `StudentQuizzesScreen`, which has independent
/// per-row providers for a list of tappable items).
///
/// Two distinct "no data" states are handled deliberately as different
/// cases, per this phase's business rules (rule #10 + the accompanying
/// empty-state requirements) rather than being collapsed into one generic
/// message:
///   - `summary.lessonsTotal == 0` — this student's grade has no seeded
///     content at all yet (Grade 5/6, currently). A normal, expected
///     state, not an error — the whole screen becomes a single friendly
///     empty state instead of showing zeroed-out tiles/charts.
///   - `summary.lessonsTotal > 0` but `quizzesCompleted == 0` — the grade
///     has content, this student just hasn't done any of it yet. Tiles
///     still render with real zeros; only the charts/mastery section swap
///     in an encouraging empty state.
///
/// Visual treatment on this screen deliberately departs from the shared
/// `AppCard`/`AppAppBarTheme` defaults (which are tuned for denser,
/// business-y admin/teacher screens) to match the approved "Modern Clean
/// – Light Blue" reference for the student-facing statistics page: a soft
/// light-blue backdrop with the title painted directly on top of it (no
/// AppBar surface — see [_StatisticsHeader]), a rounded-rectangle back
/// button (see [_BackButton]), borderless-looking white cards with a soft
/// shadow (see [_StatCard]), hand-drawn rounded vector icons instead of
/// stock Material glyphs (see [_VectorIcon]), and a brighter accent blue
/// than the app's default (muted/navy) `colorScheme.primary` (see
/// [_kAccentBlue]). Nothing here touches the global theme, so other
/// screens are unaffected.
class StudentStatisticsScreen extends ConsumerWidget {
  const StudentStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<StudentStatistics> statsAsync = ref.watch(studentStatisticsProvider);

    // No Scaffold.appBar here on purpose: an AppBar always paints its own
    // opaque/elevated surface behind its content, which is exactly the
    // "white card behind the title" look this screen is moving away from.
    // Instead the title + back button are laid out as a plain header row
    // inside the same Stack as `_StatisticsBackdrop`, so they sit directly
    // on the light-blue backdrop with nothing painted behind them.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: <Widget>[
          const Positioned.fill(child: _StatisticsBackdrop()),
          SafeArea(
            child: Column(
              children: <Widget>[
                const _StatisticsHeader(),
                Expanded(
                  child: AppPageContainer(
                    scrollable: true,
                    child: statsAsync.when(
                      loading: () => const AppLoadingIndicator(),
                      error: (error, _) => AppErrorState(
                        message: error is AppFailure ? error.message : 'Could not load your statistics.',
                        onRetry: () => ref.invalidate(studentStatisticsProvider),
                      ),
                      data: (stats) => _StatisticsContent(stats: stats),
                    ),
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

// -----------------------------------------------------------------------
// Header — centered "Statistics" title with the back button on the left,
// both painted directly on the backdrop (no AppBar surface, no white bar).
// -----------------------------------------------------------------------

class _StatisticsHeader extends StatelessWidget {
  const _StatisticsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Align(
              alignment: Alignment.centerLeft,
              child: _BackButton(),
            ),
            const Text(
              'Statistics',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: _kNavy),
            ),
          ],
        ),
      ),
    );
  }
}

// Rounded-rectangle back button (replaces the previous circular button) —
// a modern-tablet-style nav control: white/very-slightly-tinted fill, a
// subtle border + soft shadow, and a dark navy arrow. Same tap target
// (`Navigator.maybePop`) as before; only the shape/chrome changed.
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(14);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      elevation: 1.5,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: radius,
        onTap: () => Navigator.maybePop(context),
        child: Container(
          width: 50,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: const Icon(Icons.arrow_back_rounded, color: _kNavy, size: 20),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Screen-local color constants — a brighter accent blue and a consistent
// dark navy for headings/values than the app's default (muted) theme
// tokens, matching the reference mock. Reused everywhere on this screen
// instead of `colorScheme.primary`/`onSurface` so every blue accent and
// every heading stays visually consistent with each other.
// -----------------------------------------------------------------------

const Color _kAccentBlue = Color(0xFF3D82F6);
const Color _kAccentBlueContainer = Color(0xFFDCEAFE);
const Color _kNavy = Color(0xFF15304A);

// -----------------------------------------------------------------------
// Background decoration — the app's own bundled background artwork
// (light blue wash + scattered math symbols), shipped as a local asset
// (`assets/images/stat_background.png`, declared under the existing
// `assets/images/` entry in pubspec.yaml) rather than fetched from
// Supabase storage or drawn in code, so it loads instantly with zero
// network/storage cost. Purely decorative and non-interactive.
// -----------------------------------------------------------------------

class _StatisticsBackdrop extends StatelessWidget {
  const _StatisticsBackdrop();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Image(
        image: AssetImage('assets/images/stat_background.png'),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Shared card chrome for this screen — a borderless white card with a
// soft shadow (no visible stroke, unlike the shared `AppCard`/
// `AppCardTheme`, which draws an `outlineVariant` border). Built locally
// rather than reusing `AppCard` so this screen can match the reference
// mock's flatter, shadow-only card look exactly, without changing that
// shared theme for every other screen in the app.
// -----------------------------------------------------------------------

class _StatCard extends StatelessWidget {
  const _StatCard({required this.child, this.headerIcon, this.headerText, this.padding});

  final Widget child;
  final Widget? headerIcon;
  final String? headerText;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (headerText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: <Widget>[
                  if (headerIcon != null) ...<Widget>[
                    headerIcon!,
                    const SizedBox(width: 9),
                  ],
                  Text(
                    headerText!,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNavy),
                  ),
                ],
              ),
            ),
          child,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Custom vector icons — the four stat tiles and the two section headers
// use hand-drawn rounded vector icons (book, target, trending-arrow,
// trophy, bar-chart, graduation-cap) instead of stock Material glyphs, to
// match the approved icon set. No image assets are required for these;
// if real exported icon assets from the design system are ever added to
// `assets/icons/`, each `_VectorIcon` call below can be swapped for an
// `Image.asset(...)` one-for-one without touching anything else on this
// screen.
// -----------------------------------------------------------------------

enum _StatIconKind { book, target, trending, trophy, barChart, graduationCap }

class _VectorIcon extends StatelessWidget {
  const _VectorIcon({required this.kind, required this.color, this.size = 20});

  final _StatIconKind kind;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _VectorIconPainter(kind: kind, color: color)),
    );
  }
}

class _VectorIconPainter extends CustomPainter {
  _VectorIconPainter({required this.kind, required this.color});

  final _StatIconKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case _StatIconKind.book:
        _paintBook(canvas, size);
      case _StatIconKind.target:
        _paintTarget(canvas, size);
      case _StatIconKind.trending:
        _paintTrending(canvas, size);
      case _StatIconKind.trophy:
        _paintTrophy(canvas, size);
      case _StatIconKind.barChart:
        _paintBarChart(canvas, size);
      case _StatIconKind.graduationCap:
        _paintGraduationCap(canvas, size);
    }
  }

  void _paintBook(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint leftPage = Paint()..color = color.withValues(alpha: 0.62);
    final Paint rightPage = Paint()..color = color;

    final Path left = Path()
      ..moveTo(w * 0.50, h * 0.22)
      ..cubicTo(w * 0.50, h * 0.16, w * 0.40, h * 0.12, w * 0.27, h * 0.12)
      ..cubicTo(w * 0.17, h * 0.12, w * 0.10, h * 0.16, w * 0.10, h * 0.22)
      ..lineTo(w * 0.10, h * 0.76)
      ..cubicTo(w * 0.10, h * 0.82, w * 0.17, h * 0.86, w * 0.27, h * 0.86)
      ..cubicTo(w * 0.40, h * 0.86, w * 0.50, h * 0.82, w * 0.50, h * 0.78)
      ..close();
    canvas.drawPath(left, leftPage);

    final Path right = Path()
      ..moveTo(w * 0.50, h * 0.22)
      ..cubicTo(w * 0.50, h * 0.16, w * 0.60, h * 0.12, w * 0.73, h * 0.12)
      ..cubicTo(w * 0.83, h * 0.12, w * 0.90, h * 0.16, w * 0.90, h * 0.22)
      ..lineTo(w * 0.90, h * 0.76)
      ..cubicTo(w * 0.90, h * 0.82, w * 0.83, h * 0.86, w * 0.73, h * 0.86)
      ..cubicTo(w * 0.60, h * 0.86, w * 0.50, h * 0.82, w * 0.50, h * 0.78)
      ..close();
    canvas.drawPath(right, rightPage);
  }

  void _paintTarget(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w * 0.42, h * 0.58);
    final double outerRadius = w * 0.32;
    final Paint ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.095
      ..color = color;
    canvas.drawCircle(center, outerRadius, ring);
    canvas.drawCircle(center, outerRadius * 0.5, ring);
    canvas.drawCircle(center, outerRadius * 0.14, Paint()..color = color);

    final Offset arrowStart = Offset(center.dx + outerRadius * 0.5, center.dy - outerRadius * 0.5);
    final Offset arrowEnd = Offset(w * 0.90, h * 0.10);
    final Paint arrow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.10
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawLine(arrowStart, arrowEnd, arrow);

    final Path head = Path()
      ..moveTo(arrowEnd.dx, arrowEnd.dy)
      ..lineTo(arrowEnd.dx - w * 0.20, arrowEnd.dy - h * 0.02)
      ..lineTo(arrowEnd.dx - h * 0.02, arrowEnd.dy + w * 0.20)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  void _paintTrending(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final Path path = Path()
      ..moveTo(w * 0.10, h * 0.74)
      ..lineTo(w * 0.36, h * 0.46)
      ..lineTo(w * 0.53, h * 0.60)
      ..lineTo(w * 0.84, h * 0.20);
    canvas.drawPath(path, line);

    final Path head = Path()
      ..moveTo(w * 0.84, h * 0.20)
      ..lineTo(w * 0.62, h * 0.20)
      ..lineTo(w * 0.84, h * 0.42)
      ..close();
    canvas.drawPath(head, Paint()..color = color);

    canvas.drawLine(
      Offset(w * 0.10, h * 0.88),
      Offset(w * 0.50, h * 0.88),
      Paint()
        ..color = color
        ..strokeWidth = w * 0.09
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintTrophy(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint gold = Paint()..color = color;

    final Path cup = Path()
      ..moveTo(w * 0.30, h * 0.14)
      ..lineTo(w * 0.70, h * 0.14)
      ..lineTo(w * 0.66, h * 0.48)
      ..cubicTo(w * 0.66, h * 0.60, w * 0.58, h * 0.66, w * 0.50, h * 0.66)
      ..cubicTo(w * 0.42, h * 0.66, w * 0.34, h * 0.60, w * 0.34, h * 0.48)
      ..close();
    canvas.drawPath(cup, gold);

    final Paint handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.075
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.22, h * 0.28), radius: w * 0.13), -1.65, 2.9, false, handle);
    canvas.drawArc(Rect.fromCircle(center: Offset(w * 0.78, h * 0.28), radius: w * 0.13), 1.65 - 2.9, 2.9, false, handle);

    canvas.drawRect(Rect.fromLTWH(w * 0.45, h * 0.64, w * 0.10, h * 0.12), gold);

    final Path base = Path()
      ..moveTo(w * 0.30, h * 0.78)
      ..lineTo(w * 0.70, h * 0.78)
      ..lineTo(w * 0.78, h * 0.90)
      ..lineTo(w * 0.22, h * 0.90)
      ..close();
    canvas.drawPath(base, gold);

    // Small star centered on the cup.
    final Path star = Path();
    const int points = 5;
    final double cx = w * 0.50, cy = h * 0.36;
    final double outer = w * 0.11, inner = w * 0.05;
    for (int i = 0; i < points * 2; i++) {
      final double angle = (math.pi / points) * i - math.pi / 2;
      final double r = i.isEven ? outer : inner;
      final Offset p = Offset(cx + r * math.cos(angle), cy + r * math.sin(angle));
      if (i == 0) {
        star.moveTo(p.dx, p.dy);
      } else {
        star.lineTo(p.dx, p.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = Colors.white.withValues(alpha: 0.95));
  }

  void _paintBarChart(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    void bar(double x, double barWidth, double topY, double alpha) {
      final RRect rect = RRect.fromRectAndCorners(
        Rect.fromLTRB(x, topY, x + barWidth, h * 0.80),
        topLeft: Radius.circular(barWidth * 0.35),
        topRight: Radius.circular(barWidth * 0.35),
      );
      canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: alpha));
    }

    final double barWidth = w * 0.17;
    bar(w * 0.10, barWidth, h * 0.52, 0.5);
    bar(w * 0.41, barWidth, h * 0.32, 0.75);
    bar(w * 0.72, barWidth, h * 0.14, 1.0);

    canvas.drawLine(
      Offset(w * 0.06, h * 0.82),
      Offset(w * 0.94, h * 0.82),
      Paint()
        ..color = color
        ..strokeWidth = w * 0.055
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintGraduationCap(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Path top = Path()
      ..moveTo(w * 0.50, h * 0.12)
      ..lineTo(w * 0.92, h * 0.34)
      ..lineTo(w * 0.50, h * 0.56)
      ..lineTo(w * 0.08, h * 0.34)
      ..close();
    canvas.drawPath(top, Paint()..color = color);

    final Path band = Path()
      ..moveTo(w * 0.24, h * 0.42)
      ..lineTo(w * 0.76, h * 0.42)
      ..lineTo(w * 0.76, h * 0.62)
      ..cubicTo(w * 0.76, h * 0.73, w * 0.64, h * 0.80, w * 0.50, h * 0.80)
      ..cubicTo(w * 0.36, h * 0.80, w * 0.24, h * 0.73, w * 0.24, h * 0.62)
      ..close();
    canvas.drawPath(band, Paint()..color = color.withValues(alpha: 0.72));

    canvas.drawLine(
      Offset(w * 0.88, h * 0.36),
      Offset(w * 0.88, h * 0.70),
      Paint()
        ..color = color
        ..strokeWidth = w * 0.045
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(Offset(w * 0.88, h * 0.74), w * 0.06, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _VectorIconPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.color != color;
}

class _StatisticsContent extends StatelessWidget {
  const _StatisticsContent({required this.stats});

  final StudentStatistics stats;

  @override
  Widget build(BuildContext context) {
    final StudentSummaryTiles summary = stats.summary;

    // Rule #10 / empty-state (b): a grade with zero seeded lessons right
    // now (Grade 5/6) is a normal, expected state. lessonsTotal is a real,
    // meaningful zero here — the underlying view always returns exactly
    // one row for the signed-in student (LEFT JOIN LATERAL off `students`),
    // so this is never "the request failed to find data," it's "there is
    // genuinely nothing for this grade yet."
    if (summary.lessonsTotal == 0) {
      return const SizedBox(
        height: 480,
        child: AppEmptyState(
          icon: Icons.hourglass_empty,
          title: 'Nothing here yet for your grade',
          description:
              "There aren't any lessons or quizzes for your grade yet. "
              'Check back once your teacher adds some!',
        ),
      );
    }

    // Empty-state (a): content exists for this grade, but this student
    // hasn't completed any quizzes yet — tiles below still show real
    // zeros; only the charts/mastery section swap in encouragement.
    final bool hasAnyQuizActivity = summary.quizzesCompleted > 0;

    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SummaryTilesGrid(summary: summary),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final Widget barCard = _QuizScoresByLessonCard(
                lessonQuizScores: stats.lessonQuizScores,
                hasAnyQuizActivity: hasAnyQuizActivity,
              );
              final Widget pieCard = _OverallAccuracyCard(
                overallAccuracy: stats.overallAccuracy,
                hasAnyQuizActivity: hasAnyQuizActivity,
              );

              // Side-by-side once there's room (matches the mockup's
              // desktop layout); stacked on the narrower student-tablet/
              // compact widths, same breakpoint spirit as
              // AppPageContainer's own responsive padding.
              if (constraints.maxWidth >= 700) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: barCard),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: pieCard),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  barCard,
                  const SizedBox(height: AppSpacing.md),
                  pieCard,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          _CompetencyMasteryCard(
            competencyMastery: stats.competencyMastery,
            hasAnyQuizActivity: hasAnyQuizActivity,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Summary tiles
// -----------------------------------------------------------------------

class _SummaryTileData {
  const _SummaryTileData({
    required this.icon,
    required this.label,
    required this.value,
    required this.accentColor,
    required this.accentBackground,
  });

  final _StatIconKind icon;
  final String label;
  final String value;

  /// Icon color for this tile's rounded badge (matches the reference's
  /// per-tile color coding — blue for lesson/score tiles, green for the
  /// best-score tile, orange for the trophy tile).
  final Color accentColor;

  /// Light tint behind the icon, paired with [accentColor] so the
  /// combination always stays legible and matches the reference's soft
  /// icon-badge look.
  final Color accentBackground;
}

class _SummaryTilesGrid extends StatelessWidget {
  const _SummaryTilesGrid({required this.summary});

  final StudentSummaryTiles summary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final List<_SummaryTileData> tiles = <_SummaryTileData>[
      _SummaryTileData(
        icon: _StatIconKind.book,
        label: 'Lessons Completed',
        value: '${summary.lessonsCompleted}/${summary.lessonsTotal}',
        accentColor: _kAccentBlue,
        accentBackground: _kAccentBlueContainer,
      ),
      _SummaryTileData(
        icon: _StatIconKind.target,
        label: 'Average Quiz Score',
        value: formatPercent(summary.averageScorePercent),
        accentColor: _kAccentBlue,
        accentBackground: _kAccentBlueContainer,
      ),
      _SummaryTileData(
        icon: _StatIconKind.trending,
        label: 'Best Score',
        value: formatPercent(summary.bestScorePercent),
        accentColor: colorScheme.secondary,
        accentBackground: AppColors.secondaryContainer,
      ),
      _SummaryTileData(
        icon: _StatIconKind.trophy,
        label: 'Endless Quiz High',
        value: '${summary.bestEndlessStreak}',
        accentColor: colorScheme.tertiary,
        accentBackground: AppColors.tertiaryContainer,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final int columns = constraints.maxWidth >= 700 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: columns == 4 ? 1.25 : 1.6,
          children: <Widget>[for (final tile in tiles) _SummaryTile(data: tile)],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.data});

  final _SummaryTileData data;

  @override
  Widget build(BuildContext context) {
    return _StatCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: data.accentBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: _VectorIcon(kind: data.icon, color: data.accentColor, size: 24),
          ),
          const SizedBox(height: 10),
          Text(
            data.label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.25),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: _kNavy),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// "Quiz Scores by Lesson" bar chart
// -----------------------------------------------------------------------

class _QuizScoresByLessonCard extends StatelessWidget {
  const _QuizScoresByLessonCard({
    required this.lessonQuizScores,
    required this.hasAnyQuizActivity,
  });

  final List<LessonQuizScore> lessonQuizScores;
  final bool hasAnyQuizActivity;

  @override
  Widget build(BuildContext context) {
    // Two distinct empty cases here, both real: no lesson in this grade
    // has a linked quiz at all (rare, but the view can legitimately return
    // an empty list — rule #6), vs. lessons-with-linked-quizzes exist but
    // this student hasn't completed any of them yet (the common case,
    // matching the mockup's L3–L10 no-bar columns).
    final bool showEmptyState = lessonQuizScores.isEmpty || !hasAnyQuizActivity;

    return _StatCard(
      headerText: 'Quiz Scores by Lesson',
      headerIcon: const _VectorIcon(kind: _StatIconKind.barChart, color: _kAccentBlue, size: 17),
      child: SizedBox(
        height: 200,
        child: showEmptyState
            ? AppEmptyState(
                icon: Icons.bar_chart_outlined,
                title: lessonQuizScores.isEmpty ? 'No quiz-linked lessons yet' : 'No quiz scores yet',
                description: lessonQuizScores.isEmpty
                    ? "Your teacher hasn't linked a quiz to a lesson yet."
                    : 'Take a quiz to see your scores here.',
              )
            : _LessonScoresBarChart(lessonQuizScores: lessonQuizScores),
      ),
    );
  }
}

class _LessonScoresBarChart extends StatelessWidget {
  const _LessonScoresBarChart({required this.lessonQuizScores});

  final List<LessonQuizScore> lessonQuizScores;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    // Lighter, softer gridlines than the default outline token, so they
    // read as a faint guide rather than competing with the bars.
    const Color gridlineColor = Color(0xFFE5E9F0);
    const TextStyle axisLabelStyle = TextStyle(fontSize: 12, color: Color(0xFF9CA3AF));

    return BarChart(
      BarChartData(
        minY: 0,
        maxY: 100,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) => const FlLine(color: gridlineColor, strokeWidth: 1, dashArray: <int>[4, 4]),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => Text('${value.toInt()}', style: axisLabelStyle),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final int index = value.toInt();
                if (index < 0 || index >= lessonQuizScores.length) return const SizedBox.shrink();
                // Short "L1"/"L2" axis labels (matches the mockup) — the
                // full lesson title (never shortened) is still available
                // via the touch tooltip below, per rule #9's spirit of not
                // discarding the underlying text anywhere in the UI.
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text('L${index + 1}', style: axisLabelStyle),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final LessonQuizScore lesson = lessonQuizScores[group.x.toInt()];
              return BarTooltipItem(
                '${lesson.lessonTitle}\n${formatPercent(lesson.scorePercent)}',
                TextStyle(color: colorScheme.onInverseSurface),
              );
            },
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < lessonQuizScores.length; i++)
            BarChartGroupData(
              x: i,
              // Null score = "not yet attempted" (rule per the model's own
              // doc comment) — no rod at all for this x position, not a
              // zero-height bar, so the axis label still renders via
              // bottomTitles above with nothing drawn over it.
              barRods: lessonQuizScores[i].scorePercent == null
                  ? const <BarChartRodData>[]
                  : <BarChartRodData>[
                      BarChartRodData(
                        toY: lessonQuizScores[i].scorePercent!.clamp(0, 100).toDouble(),
                        color: _kAccentBlue,
                        width: 18,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// "Overall Accuracy" pie chart
// -----------------------------------------------------------------------

class _OverallAccuracyCard extends StatelessWidget {
  const _OverallAccuracyCard({
    required this.overallAccuracy,
    required this.hasAnyQuizActivity,
  });

  final OverallAccuracy overallAccuracy;
  final bool hasAnyQuizActivity;

  @override
  Widget build(BuildContext context) {
    return _StatCard(
      headerText: 'Overall Accuracy',
      child: SizedBox(
        height: 200,
        child: !hasAnyQuizActivity
            ? const AppEmptyState(
                icon: Icons.pie_chart_outline,
                title: 'No accuracy data yet',
                description: 'Take a quiz to see your accuracy here.',
              )
            : _AccuracyPieChart(overallAccuracy: overallAccuracy),
      ),
    );
  }
}

class _AccuracyPieChart extends StatelessWidget {
  const _AccuracyPieChart({required this.overallAccuracy});

  final OverallAccuracy overallAccuracy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // accuracyPercent (server-computed, already divide-by-zero-guarded via
    // the view's own `nullif`) is used directly rather than re-derived
    // from correct/incorrect here — this branch only renders once
    // hasAnyQuizActivity is true, so it's never actually null in practice,
    // but the null-safe formatting below doesn't assume that.
    final num? accuracyPercent = overallAccuracy.accuracyPercent;
    final String correctLabel =
        'Correct: ${overallAccuracy.correct}'
        '${accuracyPercent == null ? '' : ' (${formatPercent(accuracyPercent)})'}';
    final String incorrectLabel =
        'Incorrect: ${overallAccuracy.incorrect}'
        '${accuracyPercent == null ? '' : ' (${formatPercent(100 - accuracyPercent)})'}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          flex: 3,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  // A larger center-space relative to the section radius
                  // reads as a cleaner, thicker ring (matching the
                  // reference) rather than a thin, chart-junk-heavy donut.
                  centerSpaceRadius: 38,
                  sections: <PieChartSectionData>[
                    PieChartSectionData(
                      value: overallAccuracy.correct.toDouble(),
                      color: _kAccentBlue,
                      title: '',
                      radius: 52,
                    ),
                    PieChartSectionData(
                      value: overallAccuracy.incorrect.toDouble(),
                      color: colorScheme.surfaceContainerHighest,
                      title: '',
                      radius: 52,
                    ),
                  ],
                ),
              ),
              // Center label — the percentage this ring represents,
              // matching the reference's "90%" centered inside the donut.
              Text(
                accuracyPercent == null ? '—' : formatPercent(accuracyPercent),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _kNavy),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 3,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _LegendRow(color: _kAccentBlue, label: correctLabel),
              const SizedBox(height: AppSpacing.sm),
              _LegendRow(color: colorScheme.surfaceContainerHighest, label: incorrectLabel),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF374151)),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// "Competency Mastery" bars
// -----------------------------------------------------------------------

class _CompetencyMasteryCard extends StatelessWidget {
  const _CompetencyMasteryCard({
    required this.competencyMastery,
    required this.hasAnyQuizActivity,
  });

  final List<TopicMastery> competencyMastery;
  final bool hasAnyQuizActivity;

  @override
  Widget build(BuildContext context) {
    final bool showEmptyState = !hasAnyQuizActivity || competencyMastery.isEmpty;

    // Presentation order isn't specified by the view (its own comment
    // leaves this to Part 3) — alphabetical by topic is the most
    // predictable choice for a student scanning for a specific topic.
    final List<TopicMastery> sorted = <TopicMastery>[...competencyMastery]
      ..sort((a, b) => a.topic.compareTo(b.topic));

    return _StatCard(
      headerText: 'Competency Mastery',
      headerIcon: const _VectorIcon(kind: _StatIconKind.graduationCap, color: _kAccentBlue, size: 17),
      child: showEmptyState
          ? const AppEmptyState(
              icon: Icons.insights_outlined,
              title: 'No mastery data yet',
              description: 'Take a quiz to see your mastery by topic here.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < sorted.length; i++) ...<Widget>[
                  _TopicMasteryBar(topicMastery: sorted[i]),
                  if (i != sorted.length - 1) const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
    );
  }
}

class _TopicMasteryBar extends StatelessWidget {
  const _TopicMasteryBar({required this.topicMastery});

  final TopicMastery topicMastery;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    // Guarded against an out-of-range value even though the view's own
    // rounding should never produce one — this is the one place this
    // screen feeds a percent into something (LinearProgressIndicator's
    // `value`) that misbehaves outside [0, 1], so the clamp is cheap
    // insurance, not an assumption that Dart-side math is safe by default.
    final double progress = topicMastery.masteryPercent.clamp(0, 100).toDouble() / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Rule #9 — question_bank.topic used verbatim, even long
            // full-title values. No maxLines/ellipsis here: it wraps
            // naturally instead of being cut off, so nothing is ever
            // visually hidden, let alone actually truncated in code.
            Expanded(
              child: Text(
                topicMastery.topic,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _kNavy),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              formatPercent(topicMastery.masteryPercent),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _kNavy),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // Thicker, fully rounded pill (matches the reference's chunkier
        // progress bar) rather than the thin, barely-rounded default.
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 14,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: const AlwaysStoppedAnimation<Color>(_kAccentBlue),
          ),
        ),
      ],
    );
  }
}
