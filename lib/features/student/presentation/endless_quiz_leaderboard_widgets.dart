import 'package:flutter/material.dart';

import '../../../core/models/endless_quiz_leaderboard.dart';

// -----------------------------------------------------------------------
// Shared palette for the illustrated "adventure" theme used across all
// Endless Quiz screens (landing preview, full leaderboard, gameplay,
// results). Public (not per-file-private) because these three widgets are
// now shared by two screens; still scoped to this feature only, nothing
// in the global theme changed.
// -----------------------------------------------------------------------

const Color kEndlessQuizNavy = Color(0xFF17335A);
const Color kEndlessQuizPrimaryBlue = Color(0xFF2E6BE6);
const Color kEndlessQuizPrimaryBlueDark = Color(0xFF1F4FBF);

// -----------------------------------------------------------------------
// Shared back button — small rounded white button, dark navy arrow. Used
// by the landing screen and the full leaderboard screen so both headers
// match exactly.
// -----------------------------------------------------------------------

class EndlessRoundBackButton extends StatelessWidget {
  const EndlessRoundBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(11);
    return Material(
      color: Colors.white,
      borderRadius: radius,
      elevation: 2,
      shadowColor: Colors.black38,
      child: InkWell(
        borderRadius: radius,
        onTap: () => Navigator.maybePop(context),
        child: Container(
          width: 30,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: radius),
          child: const Icon(Icons.arrow_back_rounded, color: kEndlessQuizNavy, size: 16),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Leaderboard card shell — a wood-plank "LEADERBOARD" header over a cream
// body. Used both as the small 3-row preview on the landing screen and as
// the full-height list on the dedicated full-leaderboard screen; only the
// [child] differs between the two.
// -----------------------------------------------------------------------

class EndlessLeaderboardPanel extends StatelessWidget {
  const EndlessLeaderboardPanel({
    super.key,
    required this.child,
    this.headerHeight = 46,
    this.headerFontSize = 15,
    this.expandChild = true,
  });

  final Widget child;
  final double headerHeight;
  final double headerFontSize;
  final bool expandChild;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF6EC),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          Container(
            height: headerHeight,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[Color(0xFF9C6B3E), Color(0xFF6E4423)],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text('🏆', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(
                  'LEADERBOARD',
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          if (expandChild) Flexible(child: child) else child,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------
// Leaderboard rows
// -----------------------------------------------------------------------

class EndlessLeaderboardRow extends StatelessWidget {
  const EndlessLeaderboardRow({super.key, required this.entry, this.dense = false});

  final LeaderboardEntry entry;

  /// Tighter sizing for the compact 3-row landing preview.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        EndlessRankIndicator(rank: entry.rank, diameter: dense ? 21 : 32),
        SizedBox(width: dense ? 7 : 12),
        Expanded(
          child: Text(
            entry.fullName,
            style: TextStyle(
              fontSize: dense ? 11.5 : 15,
              fontWeight: FontWeight.w600,
              color: kEndlessQuizNavy,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: dense ? 5 : 8),
        Image.asset('assets/images/flame_icon.png', width: dense ? 12 : 16, height: dense ? 12 : 16),
        const SizedBox(width: 4),
        Text(
          '${entry.bestEndlessStreak}',
          style: TextStyle(
            fontSize: dense ? 11.5 : 15,
            fontWeight: FontWeight.bold,
            color: kEndlessQuizNavy,
          ),
        ),
      ],
    );
  }
}

/// Rank 1–3 get the gold/silver/bronze medal-ribbon artwork (cropped from
/// the approved wooden-leaderboard illustration); rank 4+ falls back to a
/// plain numbered circle.
class EndlessRankIndicator extends StatelessWidget {
  const EndlessRankIndicator({super.key, required this.rank, this.diameter = 32});

  final int rank;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final String? asset = switch (rank) {
      1 => 'assets/images/medal_gold.png',
      2 => 'assets/images/medal_silver.png',
      3 => 'assets/images/medal_bronze.png',
      _ => null,
    };

    if (asset != null) {
      return SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            Image.asset(asset, fit: BoxFit.contain),
            Positioned(
              top: diameter * 0.17,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: kEndlessQuizNavy,
                  fontSize: diameter * 0.30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  shadows: const <Shadow>[
                    Shadow(color: Colors.white70, blurRadius: 1.5, offset: Offset(0, 0.5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEFF3FA)),
      child: Text(
        '$rank',
        style: const TextStyle(fontWeight: FontWeight.bold, color: kEndlessQuizNavy),
      ),
    );
  }
}

// -----------------------------------------------------------------------
// "You: #N" card — shown only when the caller's rank falls outside the
// visible page above, kept visually distinct via the solid blue fill.
// -----------------------------------------------------------------------

class EndlessMyRankCard extends StatelessWidget {
  const EndlessMyRankCard({super.key, required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Your rank: number ${entry.rank}, streak ${entry.bestEndlessStreak}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: <Color>[kEndlessQuizPrimaryBlue, kEndlessQuizPrimaryBlueDark],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x4D1F4FBF), blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.person_pin_circle_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'You: #${entry.rank}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(width: 8),
            Image.asset('assets/images/flame_icon.png', width: 16, height: 16),
            const SizedBox(width: 4),
            Text(
              '${entry.bestEndlessStreak}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
