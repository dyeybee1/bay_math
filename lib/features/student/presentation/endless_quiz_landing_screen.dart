import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/avatar_catalog.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/endless_quiz_leaderboard.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../data/endless_quiz_leaderboard_providers.dart';
import 'endless_quiz_full_leaderboard_screen.dart';
import 'endless_quiz_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Named colour palette — all hex values live here, never inline.
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _C {
  static const Color navyDeep     = Color(0xFF0B173F);
  static const Color navyMid      = Color(0xFF1E3A8C);
  static const Color navyDark     = Color(0xFF16307A);
  static const Color bluePrimary  = Color(0xFF2F6FED);
  static const Color blueGlow     = Color(0xFF3B8CFF);
  static const Color yellowAccent = Color(0xFFFFC839);
  static const Color yellowDark   = Color(0xFF6B4C00);
  static const Color textPrimary  = Color(0xFFEAF0FF);
  static const Color textMuted    = Color(0xFF9FB4E8);
  static const Color silver       = Color(0xFFC7D0E0);
  static const Color bronze       = Color(0xFFE0A972);
  static const Color panelBg      = Color(0x0FFFFFFF); // 6 % white
  static const Color panelBorder  = Color(0x1FFFFFFF); // 12 % white
  static const Color divider      = Color(0x33FFFFFF); // 20 % white
  static const Color xpTrack      = Color(0x1AFFFFFF); // 10 % white
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

int _level(int streak)       => (streak / 10).floor() + 1;
double _xpFraction(int streak) => (streak % 10) / 10.0;

TextStyle _baloo(double size, {FontWeight weight = FontWeight.w700, Color color = _C.textPrimary}) =>
    GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);

TextStyle _inter(double size, {FontWeight weight = FontWeight.w400, Color color = _C.textPrimary}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

void _showHowItWorksDialog(BuildContext context) {
  AppDialog.show<void>(
    context,
    title: 'How Endless Quiz Works',
    type: AppDialogType.info,
    icon: Icons.help_outline_rounded,
    message: 'Answer questions back-to-back — there\'s no fixed end point, so keep going as long '
        'as you can. Every correct answer extends your streak; a wrong answer ends the round. '
        'Your best streak is saved and ranked on the leaderboard!',
    actions: <Widget>[
      AppButton(label: 'Got it', onPressed: () => Navigator.of(context).pop()),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────
class EndlessQuizLandingScreen extends ConsumerWidget {
  const EndlessQuizLandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(endlessQuizLeaderboardProvider);
    // Own profile — used to render the signed-in student's avatar icon inside
    // the podium. The leaderboard RPC only returns (rank, full_name,
    // best_endless_streak) — no avatarId — so only the current student's own
    // avatar can be looked up from the profile provider.
    final ownProfile = ref.watch(ownStudentProfileProvider).value;

    return Scaffold(
      backgroundColor: _C.navyDeep,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.75),
            radius: 1.5,
            colors: <Color>[_C.navyMid, _C.navyDeep],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // ── Top bar ────────────────────────────────────────────
                _TopBar(onInfo: () => _showHowItWorksDialog(context)),
                const SizedBox(height: 18),
                // ── Two-panel body ─────────────────────────────────────
                Expanded(
                  child: dataAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: _C.blueGlow),
                    ),
                    error: (e, _) => Center(
                      child: AppErrorState(
                        message: e is AppFailure ? e.message : 'Could not load leaderboard.',
                        onRetry: () => ref.invalidate(endlessQuizLeaderboardProvider),
                      ),
                    ),
                    data: (data) => Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Left panel — 38 %
                        Expanded(
                          flex: 38,
                          child: _LeftPanel(
                            myRank: data.myRank,
                            onPlay: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const EndlessQuizScreen(),
                              ),
                            ),
                            onHowItWorks: () => _showHowItWorksDialog(context),
                          ),
                        ),
                        // Vertical divider
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 22),
                          color: _C.divider,
                        ),
                        // Right panel — remaining width
                        Expanded(
                          flex: 62,
                          child: _RightPanel(data: data, ownProfile: ownProfile),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar({required this.onInfo});
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _CircleNavBtn(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 10),
        // Logo — the login-screen hero image (baymath_logo_for_login.png)
        Image.asset('assets/images/baymath_logo_for_login.png', width: 36, height: 36, fit: BoxFit.contain),
        const SizedBox(width: 8),
        Text('BayMath', style: _baloo(19, weight: FontWeight.w800)),
        const Spacer(),
        _CircleNavBtn(icon: Icons.info_outline_rounded, onTap: onInfo),
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
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _C.panelBg,
          border: Border.all(color: _C.panelBorder),
        ),
        child: Icon(icon, color: _C.textMuted, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left panel
// ─────────────────────────────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  const _LeftPanel({
    required this.myRank,
    required this.onPlay,
    required this.onHowItWorks,
  });

  final LeaderboardEntry myRank;
  final VoidCallback onPlay;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    // Level is derived from bestEndlessStreak (10 streak = 1 level).
    // NOTE: There is no XP/level table in the database — this is a
    // purely visual progression indicator based on streak milestones.
    // A real XP system would require a dedicated database column/table.
    final int streak = myRank.bestEndlessStreak;
    final int lv     = _level(streak);
    final double xp  = _xpFraction(streak);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // 1 ── Level + XP bar
        _LevelXpRow(level: lv, xpFraction: xp, streak: streak),
        const SizedBox(height: 18),
        // 2 ── Title
        _GlowText(
          'Endless Quiz',
          style: _baloo(34, weight: FontWeight.w800),
          glowColor: _C.blueGlow,
        ),
        const SizedBox(height: 8),
        // 3 ── Subtitle
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'How far can you go? Answer as many as you can, for as long as you can.',
            style: _inter(13.5, color: _C.textMuted),
          ),
        ),
        const SizedBox(height: 26),
        // 4 ── Buttons
        _ButtonRow(onPlay: onPlay, onHowItWorks: onHowItWorks),
        const SizedBox(height: 24),
        // 5 ── Stats chips
        _StatsRow(streak: streak, rank: myRank.rank),
      ],
    );
  }
}

// Level + XP row ──────────────────────────────────────────────────────────────
class _LevelXpRow extends StatelessWidget {
  const _LevelXpRow({required this.level, required this.xpFraction, required this.streak});
  final int level;
  final double xpFraction;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        // LVL badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _C.yellowAccent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x60FFC839), blurRadius: 10, offset: Offset(0, 2)),
            ],
          ),
          child: Text(
            'LVL $level',
            style: _inter(12, weight: FontWeight.w700, color: _C.yellowDark),
          ),
        ),
        const SizedBox(width: 10),
        // XP bar
        Expanded(child: _XpBar(fraction: xpFraction)),
      ],
    );
  }
}

class _XpBar extends StatelessWidget {
  const _XpBar({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        return Stack(
          children: <Widget>[
            // Track
            Container(
              height: 7,
              decoration: BoxDecoration(
                color: _C.xpTrack,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            // Fill
            Container(
              height: 7,
              width: w * fraction.clamp(0.04, 1.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                gradient: const LinearGradient(
                  colors: <Color>[_C.bluePrimary, _C.yellowAccent],
                ),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0x703B8CFF), blurRadius: 8, offset: Offset(0, 0)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// Glow text ───────────────────────────────────────────────────────────────────
class _GlowText extends StatelessWidget {
  const _GlowText(this.text, {required this.style, required this.glowColor});
  final String text;
  final TextStyle style;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        // Glow layer (blurred copy behind)
        Text(
          text,
          style: style.copyWith(
            foreground: Paint()
              ..color = glowColor.withAlpha(120)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
          ),
        ),
        // Actual text
        Text(text, style: style),
      ],
    );
  }
}

// Button row ──────────────────────────────────────────────────────────────────
class _ButtonRow extends StatelessWidget {
  const _ButtonRow({required this.onPlay, required this.onHowItWorks});
  final VoidCallback onPlay;
  final VoidCallback onHowItWorks;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        // Play Now — primary CTA
        _PlayNowBtn(onPressed: onPlay),
        const SizedBox(width: 12),
        // How It Works — ghost
        _GhostBtn(onPressed: onHowItWorks),
      ],
    );
  }
}

class _PlayNowBtn extends StatelessWidget {
  const _PlayNowBtn({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[_C.blueGlow, _C.bluePrimary],
            ),
            boxShadow: const <BoxShadow>[
              // Glow
              BoxShadow(color: Color(0x803B8CFF), blurRadius: 22, offset: Offset(0, 0)),
              // 3-D depth press
              BoxShadow(color: _C.navyDark, blurRadius: 0, offset: Offset(0, 4)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 6),
              Text('Play Now', style: _inter(15, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostBtn extends StatelessWidget {
  const _GhostBtn({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _C.panelBg,
            border: Border.all(color: _C.panelBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.help_outline_rounded, color: _C.textMuted, size: 18),
              const SizedBox(width: 6),
              Text('How It Works', style: _inter(15, weight: FontWeight.w600, color: _C.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

// Stats row ───────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.streak, required this.rank});
  final int streak;
  final int rank;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        _StatChip(value: '$streak', label: 'BEST STREAK'),
        const SizedBox(width: 10),
        _StatChip(value: '#$rank', label: 'RANK'),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: _C.panelBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            value,
            style: _baloo(26, weight: FontWeight.w800, color: _C.yellowAccent),
          ),
          Text(
            label,
            style: _inter(10, weight: FontWeight.w600, color: _C.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right panel — leaderboard
// ─────────────────────────────────────────────────────────────────────────────
class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.data, this.ownProfile});
  final EndlessQuizLeaderboardData data;
  final dynamic ownProfile; // Student? — typed as dynamic to avoid coupling

  @override
  Widget build(BuildContext context) {
    final List<LeaderboardEntry> top3   = data.topEntries.take(3).toList();
    final List<LeaderboardEntry> rest   = data.topEntries.skip(3).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
        child: Container(
          decoration: BoxDecoration(
            color: _C.panelBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.panelBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Card header
              _LeaderboardHeader(
                onViewFull: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const EndlessQuizFullLeaderboardScreen(),
                  ),
                ),
              ),
              Container(height: 1, color: _C.divider),
              // Podium (top 3) — fixed height
              _Podium(entries: top3, ownProfile: ownProfile),
              Container(height: 1, color: _C.divider),
              // Remaining ranks — fills leftover space and scrolls only if overflow
              Expanded(
                child: _RankList(entries: rest),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Card header ─────────────────────────────────────────────────────────────────
class _LeaderboardHeader extends StatelessWidget {
  const _LeaderboardHeader({required this.onViewFull});
  final VoidCallback onViewFull;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: <Widget>[
          const Text('🏆', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Text('Leaderboard', style: _baloo(18, weight: FontWeight.w700)),
          const Spacer(),
          GestureDetector(
            onTap: onViewFull,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'View Full Leaderboard',
                  style: _inter(12, weight: FontWeight.w600, color: _C.blueGlow),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: _C.blueGlow),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Podium (top 3) ──────────────────────────────────────────────────────────────
class _Podium extends StatelessWidget {
  const _Podium({required this.entries, this.ownProfile});
  final List<LeaderboardEntry> entries;
  /// Student? — own profile fetched by the parent so we can render the
  /// signed-in student's real avatar icon when they appear in the podium.
  /// The leaderboard RPC does NOT return avatarId, so only the own entry
  /// can have the real avatar; all other entries fall back to initials.
  final dynamic ownProfile;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text('No entries yet — be the first!',
              style: TextStyle(color: _C.textMuted)),
        ),
      );
    }

    // Rearrange: 2nd | 1st | 3rd (podium order)
    final LeaderboardEntry? first  = entries.isNotEmpty  ? entries[0] : null;
    final LeaderboardEntry? second = entries.length > 1  ? entries[1] : null;
    final LeaderboardEntry? third  = entries.length > 2  ? entries[2] : null;

    // The tie note: SQL RANK() gives the same number to tied students, so
    // 1,2,2 is correct — not a bug. The next distinct rank after two rank-2s
    // would be 4, skipping 3. This is intentional and documented in the RPC.

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (second != null) _PodiumAvatar(entry: second, avatarSize: 56, ownProfile: ownProfile),
          if (second != null) const SizedBox(width: 20),
          if (first  != null) _PodiumAvatar(entry: first,  avatarSize: 72, ownProfile: ownProfile),
          if (third  != null) const SizedBox(width: 20),
          if (third  != null) _PodiumAvatar(entry: third,  avatarSize: 56, ownProfile: ownProfile),
        ],
      ),
    );
  }
}

class _PodiumAvatar extends StatelessWidget {
  const _PodiumAvatar({required this.entry, required this.avatarSize, this.ownProfile});
  final LeaderboardEntry entry;
  final double avatarSize;
  /// Student? — only provided when this is the signed-in student's entry,
  /// so the real avatar icon can be shown instead of initials.
  final dynamic ownProfile;

  static const List<Color> _fills = <Color>[
    _C.yellowAccent, // 1st
    _C.silver,       // 2nd
    _C.bronze,       // 3rd
  ];
  static const List<Color> _glows = <Color>[
    Color(0x80FFC839),
    Color(0x40C7D0E0),
    Color(0x40E0A972),
  ];

  @override
  Widget build(BuildContext context) {
    final int r      = (entry.rank - 1).clamp(0, 2);
    final Color fill = _fills[r];
    final Color glow = _glows[r];
    final bool isFirst = entry.rank == 1;

    // Determine whether this entry belongs to the signed-in student.
    // If so, show their avatar icon; otherwise show name initials.
    final bool isOwnEntry =
        ownProfile != null && (ownProfile as dynamic).fullName == entry.fullName;
    final dynamic avatar = isOwnEntry
        ? AvatarCatalog.byId((ownProfile as dynamic).avatarId as String?)
        : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: avatarSize,
              height: avatarSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatar != null ? (avatar as AvatarOption).background : fill,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: glow,
                    blurRadius: isFirst ? 22 : 10,
                    offset: Offset.zero,
                  ),
                ],
              ),
              child: avatar != null
                  ? Icon(
                      (avatar as AvatarOption).icon,
                      color: Colors.white,
                      size: avatarSize * 0.45,
                    )
                  : Text(
                      _initials(entry.fullName),
                      style: _baloo(
                        avatarSize * 0.30,
                        weight: FontWeight.w800,
                        color: isFirst ? _C.yellowDark : _C.navyDeep,
                      ),
                    ),
            ),
            // Rank medal badge at bottom-center
            Positioned(
              bottom: -6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.navyDeep,
                    border: Border.all(color: fill, width: 1.5),
                  ),
                  child: Text(
                    '${entry.rank}',
                    style: _inter(10, weight: FontWeight.w700, color: fill),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          entry.fullName.split(' ').first,
          style: _inter(12, weight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          'Streak ${entry.bestEndlessStreak}',
          style: _inter(11, color: _C.textMuted),
        ),
      ],
    );
  }
}

// Rank list (4+) ──────────────────────────────────────────────────────────────
class _RankList extends StatelessWidget {
  const _RankList({required this.entries});
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            border: index == 0
                ? null
                : const Border(top: BorderSide(color: _C.divider, width: 0.8)),
          ),
          child: Row(
            children: <Widget>[
              // Rank badge
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _C.panelBg,
                  border: Border.all(color: _C.panelBorder),
                ),
                child: Text(
                  '${entry.rank}',
                  style: _inter(11, weight: FontWeight.w700, color: _C.textMuted),
                ),
              ),
              const SizedBox(width: 10),
              // Name
              Expanded(
                child: Text(
                  entry.fullName,
                  style: _inter(13, weight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Streak
              Text(
                'Streak ${entry.bestEndlessStreak}',
                style: _inter(12, color: _C.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}
