import 'package:flutter/material.dart';

import 'endless_quiz_screen.dart';

// -----------------------------------------------------------------------
// Shared "adventure" palette — see the matching comment in
// endless_quiz_landing_screen.dart.
// -----------------------------------------------------------------------

const Color _kNavy = Color(0xFF17335A);
const Color _kPrimaryBlue = Color(0xFF2E6BE6);
const Color _kPrimaryBlueDark = Color(0xFF1F4FBF);

/// Shown after `finalizeSession` succeeds — the two numbers this screen
/// shows are exactly the ones just written to `endless_quiz_sessions`, so
/// this takes them as plain constructor args rather than re-fetching
/// anything (there's no per-session read endpoint for this in Phase 7;
/// the session list/leaderboard view is Phase 8, Statistics).
///
/// Deliberately a plain `StatelessWidget`, no Riverpod — nothing here is
/// async or reactive.
///
/// Visual treatment matches the illustrated "adventure" reference used by
/// the other two Endless Quiz screens: a celebratory backdrop with
/// confetti, a "Great job!" ribbon, the trophy-on-pedestal illustration,
/// and the two result numbers in a clean white card. The constructor
/// contract and "Play Again" navigation below are unchanged from before.
class EndlessQuizResultsScreen extends StatelessWidget {
  const EndlessQuizResultsScreen({
    super.key,
    required this.questionsAnswered,
    required this.bestStreakSession,
  });

  final int questionsAnswered;
  final int bestStreakSession;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kNavy,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset('assets/images/endless_result_bg.png', fit: BoxFit.cover),
          SafeArea(
            child: Column(
              children: <Widget>[
                const _ResultsHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Column(
                      children: <Widget>[
                        Image.asset(
                          'assets/images/great_job_ribbon.png',
                          height: 80,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 8),
                        Image.asset(
                          'assets/images/trophy_with_pedestal.png',
                          height: 190,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 20),
                        _ResultsStatsCard(
                          questionsAnswered: questionsAnswered,
                          bestStreakSession: bestStreakSession,
                        ),
                        const SizedBox(height: 24),
                        _PlayAgainButton(
                          onPressed: () => Navigator.of(context).pushReplacement(
                            MaterialPageRoute<void>(builder: (_) => const EndlessQuizScreen()),
                          ),
                        ),
                      ],
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
// Header — same rounded-rectangle back button as the other two screens.
// `Navigator` already has `EndlessQuizLandingScreen` beneath this route
// (this screen was reached via `pushReplacement` of the play screen, not
// of the landing screen — see the play screen's `_finishSession`), so a
// back affordance here pops to a real, already-loaded screen, same as
// Flutter's own default `AppBar` back button would have.
// -----------------------------------------------------------------------

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 2,
                shadowColor: Colors.black38,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.maybePop(context),
                  child: const SizedBox(
                    width: 46,
                    height: 42,
                    child: Icon(Icons.arrow_back_rounded, color: _kNavy, size: 20),
                  ),
                ),
              ),
            ),
            const Text(
              'Endless Quiz — Results',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white, shadows: <Shadow>[
                Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 1)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Results stats
// -----------------------------------------------------------------------

class _ResultsStatsCard extends StatelessWidget {
  const _ResultsStatsCard({
    required this.questionsAnswered,
    required this.bestStreakSession,
  });

  final int questionsAnswered;
  final int bestStreakSession;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _ResultStatColumn(
              icon: Icons.checklist_rounded,
              iconColor: _kPrimaryBlue,
              label: 'Questions Answered',
              value: '$questionsAnswered',
            ),
          ),
          Container(width: 1, height: 56, color: Colors.black.withValues(alpha: 0.06)),
          Expanded(
            child: _ResultStatColumn(
              imageAsset: 'assets/images/flame_icon.png',
              label: 'Best Streak This Session',
              value: '$bestStreakSession',
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultStatColumn extends StatelessWidget {
  const _ResultStatColumn({
    required this.label,
    required this.value,
    this.icon,
    this.iconColor,
    this.imageAsset,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? iconColor;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (imageAsset != null)
          Image.asset(imageAsset!, width: 28, height: 28)
        else
          Icon(icon, color: iconColor, size: 26),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _kNavy)),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8592A6), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------
// "Play Again" CTA
// -----------------------------------------------------------------------

class _PlayAgainButton extends StatelessWidget {
  const _PlayAgainButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[_kPrimaryBlue, _kPrimaryBlueDark],
              ),
              boxShadow: const <BoxShadow>[
                BoxShadow(color: Color(0x4D1F4FBF), blurRadius: 14, offset: Offset(0, 6)),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.replay_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('Play Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
