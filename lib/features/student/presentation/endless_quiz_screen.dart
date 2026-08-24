import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/constants/app_spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/endless_question.dart';
import '../../../core/models/quiz_attempt_choice.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/repositories/endless_quiz_repository.dart';
import '../../../core/widgets/widgets.dart';
import '../data/endless_quiz_leaderboard_providers.dart';
import 'endless_quiz_results_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// HUD colour palette — identical hex values to EndlessQuizLandingScreen
// and EndlessQuizFullLeaderboardScreen for cross-screen visual consistency.
// ─────────────────────────────────────────────────────────────────────────────
const Color _kNavyDeep    = Color(0xFF0B173F);
const Color _kNavyMid     = Color(0xFF1E3A8C);

const Color _kBlueGlow    = Color(0xFF3B8CFF);
const Color _kYellow      = Color(0xFFFFC839);

const Color _kTextPrimary = Color(0xFFEAF0FF);
const Color _kTextMuted   = Color(0xFF9FB4E8);
const Color _kPanelBg     = Color(0x0FFFFFFF);
const Color _kPanelBorder = Color(0x1FFFFFFF);
const Color _kCorrectGreen = Color(0xFF33D69F);
const Color _kIncorrectRed = Color(0xFFFF5E5E);


/// Option badge fills: A=glow-blue, B=green, C=yellow, D=purple
const List<Color> _kChoiceColors = <Color>[
  Color(0xFF3B8CFF),
  Color(0xFF33D69F),
  Color(0xFFFFC839),
  Color(0xFF9B7CF0),
];

/// Text colour on each badge (dark where bg is light)
const List<Color> _kChoiceTextColors = <Color>[
  Colors.white,
  Color(0xFF08291A),
  Color(0xFF6B4C00),
  Colors.white,
];

const Duration _kFeedbackDelay = Duration(milliseconds: 1750);

/// Phase 7 (Endless Quiz) — one freshly-random practice question at a
/// time, straight through: pick a choice, see correct/incorrect
/// immediately, then auto-advance after [_kFeedbackDelay]. A wrong answer
/// resets the current streak but never ends the session; the only way out
/// is the always-visible Done/Quit button.
///
/// Deliberately a `ConsumerStatefulWidget` with plain local `State` for
/// all of this screen's transient play state — same shape as
/// `quiz_taking_screen.dart`'s `_QuizTakingScreenState` (see that class's
/// own doc comment) — rather than a Riverpod `StateNotifier`. Unlike that
/// screen, the "current question" here is not driven by a watched
/// `FutureProvider`: there is no attempt/content row behind Endless Quiz
/// to watch, every `fetchQuestion()` call is an independent, imperative
/// step in a fetch → answer → delay → fetch chain, and a provider
/// watch/invalidate cycle would just reintroduce a loading-flicker between
/// questions that this imperative version avoids by only ever swapping
/// `_currentQuestion` at the one point a replacement is actually ready
/// (see `_loadNextQuestion` below).
///
/// Visual treatment matches the illustrated "adventure" reference used by
/// the landing and results screens either side of this one: a full-bleed
/// forest backdrop, a wooden signboard for the question prompt, and
/// colored letter badges for each choice instead of plain radio dots.
/// Every piece of state/business logic below is unchanged from before —
/// only the `build`/presentational widgets were reworked.
class EndlessQuizScreen extends ConsumerStatefulWidget {
  const EndlessQuizScreen({super.key});

  @override
  ConsumerState<EndlessQuizScreen> createState() => _EndlessQuizScreenState();
}

class _EndlessQuizScreenState extends ConsumerState<EndlessQuizScreen> {
  /// Captured once, the first time this screen is entered — never
  /// refreshed on subsequent question loads. This is `finalizeSession`'s
  /// `startedAt`.
  late final DateTime _startedAt = DateTime.now();

  EndlessQuestion? _currentQuestion;

  /// Set (and left set) whenever a question load or answer check fails —
  /// paired with whether `_currentQuestion` is still null to decide
  /// between a full-screen error (nothing to show yet) and an inline one
  /// (a question is still on screen, just stuck mid-transition).
  AppFailure? _loadError;

  /// The choice tapped for the CURRENT question, before/after the
  /// `checkAnswer` round-trip. Only ever cleared together with
  /// `_isAnswerCorrect`, at the single point in `_loadNextQuestion` where
  /// a new question actually replaces this one — never independently, so
  /// the two can't desync the way `quiz_taking_screen.dart` guards against
  /// too.
  String? _selectedChoiceId;

  /// Set once `checkAnswer` returns for `_selectedChoiceId`. Null means
  /// "not yet answered this question".
  bool? _isAnswerCorrect;

  /// True from the moment a choice is tapped until the NEXT question has
  /// actually loaded — spans the `checkAnswer` round-trip, the feedback
  /// delay, AND the following `fetchQuestion` round-trip, not just the
  /// first of those. Disables further choice taps for the whole span (the
  /// answered/locked choice list doesn't take taps anyway, but this also
  /// covers the brief window before that view is showing yet) and is the
  /// single flag `_loadNextQuestion` clears once a replacement question is
  /// in hand.
  bool _isBusy = false;

  int _currentStreak = 0;
  int _bestStreakSession = 0;
  int _questionsAnswered = 0;

  /// Debounce only for Done/Quit, per the already-settled call on this
  /// (see `EndlessQuizRepository.finalizeSession`'s doc comment) — set the
  /// instant the button is tapped, never reset on success (the screen
  /// navigates away), reset on failure so the student can retry.
  bool _isFinalizing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadNextQuestion());
  }

  Future<void> _loadNextQuestion() async {
    setState(() {
      _isBusy = true;
      _loadError = null;
    });

    try {
      final EndlessQuizRepository? repo = ref.read(
        endlessQuizRepositoryProvider,
      );
      if (repo == null) throw const SessionExpiredFailure();

      final EndlessQuestion question = await repo.fetchQuestion();
      if (!mounted) return;

      setState(() {
        _currentQuestion = question;
        _selectedChoiceId = null;
        _isAnswerCorrect = null;
        _isBusy = false;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _loadError = failure;
        _isBusy = false;
      });
    }
  }

  Future<void> _selectChoice(String choiceId) async {
    final EndlessQuestion? question = _currentQuestion;
    if (_isBusy || question == null) return;

    setState(() {
      _selectedChoiceId = choiceId;
      _isBusy = true;
    });

    try {
      final EndlessQuizRepository? repo = ref.read(
        endlessQuizRepositoryProvider,
      );
      if (repo == null) throw const SessionExpiredFailure();

      // The single authoritative correctness check — never computed
      // locally. Returns only a boolean (see the repository's own doc
      // comment on why there's no per-choice detail to show here, unlike
      // `quiz_taking_screen.dart`'s `_AnsweredChoiceList`).
      final bool isCorrect = await repo.checkAnswer(
        questionId: question.questionId,
        choiceId: choiceId,
      );
      if (!mounted) return;

      setState(() {
        _isAnswerCorrect = isCorrect;
        _questionsAnswered += 1;
        // Increments on every answer, correct or incorrect; resets to 0
        // on incorrect without ending the session.
        _currentStreak = isCorrect ? _currentStreak + 1 : 0;
        // Recomputed every time `_currentStreak` changes — including right
        // before a reset — so the peak reached just before a wrong answer
        // is never lost. In practice the peak is already captured here on
        // the correct answer that set it; a following reset to 0 can only
        // leave this unchanged (`max(best, 0) == best`), never lower it.
        _bestStreakSession = math.max(_bestStreakSession, _currentStreak);
      });

      await Future<void>.delayed(_kFeedbackDelay);
      if (!mounted) return;

      await _loadNextQuestion();
    } on AppFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      // checkAnswer itself never returned here (`_isAnswerCorrect` is
      // still null), so it's safe to clear the selection and let the
      // student try again — unlike the mid-transition failure path in
      // `_loadNextQuestion`, there's no answered feedback to preserve.
      setState(() {
        _selectedChoiceId = null;
        _isBusy = false;
      });
    }
  }

  Future<void> _finishSession() async {
    if (_isFinalizing) return;
    setState(() => _isFinalizing = true);

    try {
      final StudentSession? session = ref.read(studentSessionProvider);
      final EndlessQuizRepository? repo = ref.read(
        endlessQuizRepositoryProvider,
      );
      if (session == null || repo == null) throw const SessionExpiredFailure();

      await repo.finalizeSession(
        studentId: session.studentId,
        startedAt: _startedAt,
        endedAt: DateTime.now(),
        questionsAnswered: _questionsAnswered,
        bestStreakSession: _bestStreakSession,
      );
      if (!mounted) return;

      // `EndlessQuizLandingScreen` stays mounted underneath this whole
      // time — it was reached via `Navigator.push` (not `pushReplacement`)
      // from the home screen, and this screen's own navigation below is a
      // `pushReplacement` onto Results, not a pop back to Landing. Without
      // this, popping from Results back to Landing later would show the
      // leaderboard/rank data exactly as it was before this session was
      // played, since nothing would ever mark
      // `endlessQuizLeaderboardProvider` for refetch. Invalidating here
      // (rather than waiting for Landing's own `build` to run again) lets
      // Riverpod refetch it now, in the background, while the student is
      // still looking at Results — by the time they pop back, the data is
      // already fresh instead of only starting to load at that point.
      ref.invalidate(endlessQuizLeaderboardProvider);

      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => EndlessQuizResultsScreen(
              questionsAnswered: _questionsAnswered,
              bestStreakSession: _bestStreakSession,
            ),
          ),
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      setState(() => _isFinalizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavyDeep,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.75),
            radius: 1.5,
            colors: <Color>[_kNavyMid, _kNavyDeep],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _QuizHeader(),
                const SizedBox(height: 18),
                _StreakStatsCard(
                  currentStreak: _currentStreak,
                  bestStreakSession: _bestStreakSession,
                  questionsAnswered: _questionsAnswered,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        _buildQuestionArea(),
                        const SizedBox(height: 16),
                        _DoneButton(
                          isLoading: _isFinalizing,
                          onPressed: _isFinalizing ? null : _finishSession,
                        ),
                      ],
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

  Widget _buildQuestionArea() {
    final EndlessQuestion? question = _currentQuestion;

    // Nothing to show yet at all (first load, or every retry of it, still
    // in flight or failed) — full-screen loading/error in place of the
    // question area.
    if (question == null) {
      if (_loadError != null) {
        return AppErrorState(
          message: _loadError!.message,
          onRetry: _loadNextQuestion,
        );
      }
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: AppLoadingIndicator(),
      );
    }

    // Local copies so Dart can promote both together — same reasoning as
    // `quiz_taking_screen.dart`'s `justAnswered` guard.
    final String? selectedChoiceId = _selectedChoiceId;
    final bool? isAnswerCorrect = _isAnswerCorrect;
    final bool justAnswered = selectedChoiceId != null && isAnswerCorrect != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _WoodenQuestionBoard(promptText: question.promptText),
        const SizedBox(height: AppSpacing.md),
        if (justAnswered)
          _EndlessAnsweredChoiceList(
            question: question,
            selectedChoiceId: selectedChoiceId,
            isCorrect: isAnswerCorrect,
          )
        else
          _EndlessSelectableChoiceList(
            question: question,
            selectedChoiceId: selectedChoiceId,
            isEnabled: !_isBusy,
            onSelect: _selectChoice,
          ),
        if (justAnswered) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          _EndlessFeedbackBanner(isCorrect: isAnswerCorrect),
        ],
        // A failure here only happens mid-transition (fetching the NEXT
        // question after the delay above) — the answered feedback for the
        // question the student can still see stays exactly as it was;
        // this just adds a way to retry the stuck fetch without losing it.
        if (_loadError != null) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    _loadError!.message,
                    style: const TextStyle(color: _kIncorrectRed),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: _loadNextQuestion,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────

class _QuizHeader extends ConsumerWidget {
  const _QuizHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GradeLevel? grade = ref.watch(ownStudentGradeLevelProvider).value;
    final String sub = grade != null ? '${grade.label} · Endless Quiz' : 'Endless Quiz';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _CircleNavBtn(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Endless Quiz',
                style: GoogleFonts.baloo2(fontSize: 20, fontWeight: FontWeight.w800, color: _kTextPrimary)),
            Text(sub,
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted)),
          ],
        ),
        const Spacer(),
        Image.asset('assets/images/baymath_logo.png', width: 34, height: 34, fit: BoxFit.contain),
        const SizedBox(width: 8),
        Text('BayMath',
            style: GoogleFonts.baloo2(fontSize: 18, fontWeight: FontWeight.w800, color: _kTextPrimary)),
      ],
    );
  }
}

class _CircleNavBtn extends StatelessWidget {
  const _CircleNavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _kPanelBg,
          border: Border.all(color: _kPanelBorder),
        ),
        child: Icon(icon, color: _kTextMuted, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats row — three equal glass-panel chips
// ─────────────────────────────────────────────────────────────────────────────

class _StreakStatsCard extends StatelessWidget {
  const _StreakStatsCard({
    required this.currentStreak,
    required this.bestStreakSession,
    required this.questionsAnswered,
  });

  final int currentStreak;
  final int bestStreakSession;
  final int questionsAnswered;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _StatChip(
            icon: Icons.local_fire_department_rounded,
            iconBg: const Color(0x33FF7A00),
            iconColor: const Color(0xFFFF8C42),
            value: '$currentStreak',
            label: 'STREAK',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            icon: Icons.emoji_events_rounded,
            iconBg: const Color(0x33FFC839),
            iconColor: _kYellow,
            iconGlow: const Color(0x50FFC839),
            value: '$bestStreakSession',
            label: 'BEST',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatChip(
            icon: Icons.checklist_rounded,
            iconBg: const Color(0x333B8CFF),
            iconColor: _kBlueGlow,
            value: '$questionsAnswered',
            label: 'ANSWERED',
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    this.iconGlow,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final Color? iconGlow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kPanelBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kPanelBorder),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconBg,
              boxShadow: iconGlow != null
                  ? <BoxShadow>[BoxShadow(color: iconGlow!, blurRadius: 10, offset: Offset.zero)]
                  : null,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(value,
                  style: GoogleFonts.baloo2(
                      fontSize: 22, fontWeight: FontWeight.w800, color: _kTextPrimary)),
              Text(label,
                  style: GoogleFonts.inter(
                          fontSize: 10, fontWeight: FontWeight.w600, color: _kTextMuted)
                      .copyWith(letterSpacing: 1.2)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question card (replaces wooden board — class name kept for call-site compat)
// ─────────────────────────────────────────────────────────────────────────────

class _WoodenQuestionBoard extends StatelessWidget {
  const _WoodenQuestionBoard({required this.promptText});
  final String promptText;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 90),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[Color(0x293B8CFF), Color(0x0DFFFFFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kBlueGlow),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x303B8CFF), blurRadius: 28, offset: Offset.zero),
        ],
      ),
      child: Text(
        promptText,
        textAlign: TextAlign.center,
        style: GoogleFonts.baloo2(
            fontSize: 19, fontWeight: FontWeight.w700, color: _kTextPrimary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Done / quit button
// ─────────────────────────────────────────────────────────────────────────────

class _DoneButton extends StatelessWidget {
  const _DoneButton({required this.isLoading, required this.onPressed});
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onPressed,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _kPanelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPanelBorder),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: _kTextMuted),
              )
            : Semantics(
                label: 'End Endless Quiz session',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.stop_circle_outlined, color: _kTextMuted, size: 20),
                    const SizedBox(width: 8),
                    Text('Done',
                        style: GoogleFonts.inter(
                            fontSize: 15, fontWeight: FontWeight.w600, color: _kTextMuted)),
                  ],
                ),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Choice lists — 2 × 2 grid layout
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a 2-column grid of tappable option cards before an answer is
/// submitted. Selected state (blue tint + glow border) is shown for the
/// tapped choice while the server round-trip is in flight.
class _EndlessSelectableChoiceList extends StatelessWidget {
  const _EndlessSelectableChoiceList({
    required this.question,
    required this.selectedChoiceId,
    required this.isEnabled,
    required this.onSelect,
  });

  final EndlessQuestion question;
  final String? selectedChoiceId;
  final bool isEnabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final List<QuizAttemptChoice> ch = question.choices;

    _ChoiceCard card(int i) => _ChoiceCard(
          index: i,
          text: ch[i].choiceText,
          state: selectedChoiceId == ch[i].choiceId
              ? _ChoiceVisualState.selected
              : _ChoiceVisualState.neutral,
          onTap: isEnabled ? () => onSelect(ch[i].choiceId) : null,
        );

    return Column(
      children: <Widget>[
        IntrinsicHeight(
          child: Row(children: <Widget>[
            if (ch.isNotEmpty) Expanded(child: card(0)),
            if (ch.length > 1) ...<Widget>[const SizedBox(width: 12), Expanded(child: card(1))],
          ]),
        ),
        if (ch.length > 2) ...<Widget>[
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(children: <Widget>[
              Expanded(child: card(2)),
              if (ch.length > 3) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(child: card(3)),
              ],
            ]),
          ),
        ],
      ],
    );
  }
}

/// Choice list after `checkAnswer` returns. Only the selected choice is
/// marked correct/incorrect; others stay neutral — the Endless Quiz RPC
/// returns only `{ is_correct }`, not per-choice correctness.
class _EndlessAnsweredChoiceList extends StatelessWidget {
  const _EndlessAnsweredChoiceList({
    required this.question,
    required this.selectedChoiceId,
    required this.isCorrect,
  });

  final EndlessQuestion question;
  final String selectedChoiceId;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final List<QuizAttemptChoice> ch = question.choices;

    _ChoiceCard card(int i) => _ChoiceCard(
          index: i,
          text: ch[i].choiceText,
          state: ch[i].choiceId != selectedChoiceId
              ? _ChoiceVisualState.neutral
              : (isCorrect ? _ChoiceVisualState.correct : _ChoiceVisualState.incorrect),
          onTap: null,
        );

    return Column(
      children: <Widget>[
        IntrinsicHeight(
          child: Row(children: <Widget>[
            if (ch.isNotEmpty) Expanded(child: card(0)),
            if (ch.length > 1) ...<Widget>[const SizedBox(width: 12), Expanded(child: card(1))],
          ]),
        ),
        if (ch.length > 2) ...<Widget>[
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(children: <Widget>[
              Expanded(child: card(2)),
              if (ch.length > 3) ...<Widget>[
                const SizedBox(width: 12),
                Expanded(child: card(3)),
              ],
            ]),
          ),
        ],
      ],
    );
  }
}

enum _ChoiceVisualState { neutral, selected, correct, incorrect }

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.index,
    required this.text,
    required this.state,
    required this.onTap,
  });

  final int index;
  final String text;
  final _ChoiceVisualState state;
  final VoidCallback? onTap;

  String get _letter => String.fromCharCode(65 + index);
  Color get _badgeFill => _kChoiceColors[index % _kChoiceColors.length];
  Color get _badgeText => _kChoiceTextColors[index % _kChoiceTextColors.length];

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color border;
    final List<BoxShadow> shadows;
    final IconData? trailingIcon;

    switch (state) {
      case _ChoiceVisualState.selected:
        fill = const Color(0x243B8CFF);
        border = _kBlueGlow;
        shadows = const <BoxShadow>[
          BoxShadow(color: Color(0x403B8CFF), blurRadius: 18, offset: Offset.zero),
        ];
        trailingIcon = null;
      case _ChoiceVisualState.correct:
        fill = const Color(0x2233D69F);
        border = _kCorrectGreen;
        shadows = const <BoxShadow>[
          BoxShadow(color: Color(0x4033D69F), blurRadius: 14, offset: Offset.zero),
        ];
        trailingIcon = Icons.check_circle_rounded;
      case _ChoiceVisualState.incorrect:
        fill = const Color(0x22FF5E5E);
        border = _kIncorrectRed;
        shadows = const <BoxShadow>[
          BoxShadow(color: Color(0x40FF5E5E), blurRadius: 14, offset: Offset.zero),
        ];
        trailingIcon = Icons.cancel_rounded;
      case _ChoiceVisualState.neutral:
        fill = _kPanelBg;
        border = _kPanelBorder;
        shadows = const <BoxShadow>[];
        trailingIcon = null;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
          boxShadow: shadows,
        ),
        child: Row(
          children: <Widget>[
            // Letter badge
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: _badgeFill),
              child: Text(
                _letter,
                style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _badgeText),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: _kTextPrimary),
              ),
            ),
            if (trailingIcon != null) ...<Widget>[
              const SizedBox(width: 8),
              Icon(trailingIcon, color: border, size: 22),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Correctness feedback banner
// ─────────────────────────────────────────────────────────────────────────────

class _EndlessFeedbackBanner extends StatelessWidget {
  const _EndlessFeedbackBanner({required this.isCorrect});
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    final Color accent = isCorrect ? _kCorrectGreen : _kIncorrectRed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0x2233D69F) : const Color(0x22FF5E5E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: accent,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            isCorrect ? 'Correct!' : 'Not quite.',
            style: GoogleFonts.inter(
                fontSize: 15, fontWeight: FontWeight.w700, color: accent),
          ),
        ],
      ),
    );
  }
}

