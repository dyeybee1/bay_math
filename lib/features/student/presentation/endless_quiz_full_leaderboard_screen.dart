import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/avatar_catalog.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/endless_quiz_leaderboard.dart';
import '../../../core/models/section.dart';
import '../../../core/models/student.dart';
import '../../../core/providers/student_profile_provider.dart';
import '../../../core/widgets/widgets.dart';
import '../data/endless_quiz_leaderboard_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colour palette — identical hex values to EndlessQuizLandingScreen._C so
// both screens share the same visual language without coupling to a shared
// constant file (each screen is self-contained per existing project style).
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _C {
  static const Color navyDeep    = Color(0xFF0B173F);
  static const Color navyMid     = Color(0xFF1E3A8C);
  static const Color bluePrimary = Color(0xFF2F6FED);
  static const Color blueGlow    = Color(0xFF3B8CFF);
  static const Color yellowAccent= Color(0xFFFFC839);
  static const Color yellowDark  = Color(0xFF6B4C00);
  static const Color textPrimary = Color(0xFFEAF0FF);
  static const Color textMuted   = Color(0xFF9FB4E8);
  static const Color silver      = Color(0xFFC7D0E0);
  static const Color bronze      = Color(0xFFE0A972);
  static const Color panelBg     = Color(0x0FFFFFFF); // ~6 % white
  static const Color panelBorder = Color(0x1FFFFFFF); // ~12 % white
  static const Color divider     = Color(0x33FFFFFF); // 20 % white
}

// ─────────────────────────────────────────────────────────────────────────────
// Typography helpers
// ─────────────────────────────────────────────────────────────────────────────
TextStyle _baloo(double size, {FontWeight weight = FontWeight.w700, Color color = _C.textPrimary}) =>
    GoogleFonts.baloo2(fontSize: size, fontWeight: weight, color: color);

TextStyle _inter(double size, {FontWeight weight = FontWeight.w400, Color color = _C.textPrimary}) =>
    GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

// ─────────────────────────────────────────────────────────────────────────────
// Misc helpers
// ─────────────────────────────────────────────────────────────────────────────
String _initials(String name) {
  final List<String> parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0].substring(0, math.min(2, parts[0].length)).toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────
class EndlessQuizFullLeaderboardScreen extends ConsumerWidget {
  const EndlessQuizFullLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EndlessQuizLeaderboardData> dataAsync =
        ref.watch(endlessQuizLeaderboardProvider);
    final Student? ownProfile   = ref.watch(ownStudentProfileProvider).value;
    final GradeLevel? gradeLevel = ref.watch(ownStudentGradeLevelProvider).value;

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
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _TopBar(gradeLevel: gradeLevel),
                const SizedBox(height: 20),
                Expanded(
                  child: dataAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: _C.blueGlow),
                    ),
                    error: (Object e, _) => Center(
                      child: AppErrorState(
                        message: e is AppFailure ? e.message : 'Could not load leaderboard.',
                        onRetry: () => ref.invalidate(endlessQuizLeaderboardProvider),
                      ),
                    ),
                    data: (EndlessQuizLeaderboardData data) => Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Left panel — ~30 % of screen width
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.27,
                          child: _LeftPanel(
                            myRank: data.myRank,
                            ownProfile: ownProfile,
                          ),
                        ),
                        // Vertical 1 px divider
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(horizontal: 22),
                          color: _C.divider,
                        ),
                        // Right panel — fills remaining space
                        Expanded(
                          child: _RightPanel(entries: data.topEntries),
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
  const _TopBar({this.gradeLevel});
  final GradeLevel? gradeLevel;

  @override
  Widget build(BuildContext context) {
    final String subtitle = gradeLevel != null
        ? '${gradeLevel!.label} · Endless Quiz'
        : 'Endless Quiz';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Back button
        _CircleNavBtn(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: 14),
        // Title + subtitle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Leaderboard', style: _baloo(22, weight: FontWeight.w800)),
            Text(
              subtitle,
              style: _inter(12, weight: FontWeight.w500, color: _C.textMuted),
            ),
          ],
        ),
        const Spacer(),
        // Logo + app name pinned to the right
        Image.asset(
          'assets/images/baymath_logo.png',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 8),
        Text('BayMath', style: _baloo(19, weight: FontWeight.w800)),
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
          color: _C.panelBg,
          border: Border.all(color: _C.panelBorder),
        ),
        child: Icon(icon, color: _C.textMuted, size: 20),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left panel
// ─────────────────────────────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  const _LeftPanel({required this.myRank, this.ownProfile});
  final LeaderboardEntry myRank;
  final Student? ownProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StandingCard(myRank: myRank, ownProfile: ownProfile),
        const SizedBox(height: 16),
        const Expanded(child: _CheerCard()),
      ],
    );
  }
}

// "Your Standing" card ────────────────────────────────────────────────────────
class _StandingCard extends StatelessWidget {
  const _StandingCard({required this.myRank, this.ownProfile});
  final LeaderboardEntry myRank;
  final Student? ownProfile;

  @override
  Widget build(BuildContext context) {
    final AvatarOption? avatar = ownProfile?.avatarId != null
        ? AvatarCatalog.byId(ownProfile!.avatarId)
        : null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _C.panelBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Section label
          Text(
            'YOUR STANDING',
            style: _inter(10, weight: FontWeight.w600, color: _C.textMuted)
                .copyWith(letterSpacing: 1.5),
          ),
          const SizedBox(height: 14),
          // Avatar + name + rank row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              // Circular avatar with gold glow
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: avatar?.background ?? _C.yellowAccent,
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x60FFC839),
                      blurRadius: 18,
                      offset: Offset.zero,
                    ),
                  ],
                ),
                child: avatar != null
                    ? Icon(avatar.icon, color: Colors.white, size: 26)
                    : Text(
                        'YOU',
                        style: _inter(11, weight: FontWeight.w800, color: _C.yellowDark),
                      ),
              ),
              const SizedBox(width: 12),
              // Name + streak
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      myRank.fullName,
                      style: _inter(14, weight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Best streak: ${myRank.bestEndlessStreak}',
                      style: _inter(11, color: _C.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Rank number — large yellow Baloo 2
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '#${myRank.rank}',
                    style: _baloo(28, weight: FontWeight.w800, color: _C.yellowAccent),
                  ),
                  Text(
                    'RANK',
                    style: _inter(9, weight: FontWeight.w600, color: _C.textMuted)
                        .copyWith(letterSpacing: 1.2),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Cheer card ──────────────────────────────────────────────────────────────────
class _CheerCard extends StatelessWidget {
  const _CheerCard();

  static const List<String> _lines = <String>[
    'Keep Learning',
    'Be Curious',
    'You Can Do It!',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      decoration: BoxDecoration(
        color: _C.panelBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.panelBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < _lines.length; i++) ...<Widget>[
            if (i != 0) const SizedBox(height: 18),
            Row(
              children: <Widget>[
                // Yellow bullet dot
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.yellowAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _lines[i],
                  style: _baloo(16, weight: FontWeight.w800, color: _C.yellowAccent),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right panel — full rank list
// ─────────────────────────────────────────────────────────────────────────────
class _RightPanel extends StatelessWidget {
  const _RightPanel({required this.entries});
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _C.panelBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.panelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _RankListHeader(),
          Container(height: 1, color: _C.divider),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No entries yet — be the first!',
                      style: _inter(14, color: _C.textMuted),
                    ),
                  )
                : _RankListBody(entries: entries),
          ),
        ],
      ),
    );
  }
}

// Card header ─────────────────────────────────────────────────────────────────
class _RankListHeader extends StatelessWidget {
  const _RankListHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      child: Row(
        children: <Widget>[
          const Text('🏆', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Text('All Rankings', style: _baloo(18, weight: FontWeight.w700)),
          const Spacer(),
          // Static "Top Students" active pill — no filter logic, one view only
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              color: _C.bluePrimary,
              borderRadius: BorderRadius.circular(30),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x603B8CFF),
                  blurRadius: 14,
                  offset: Offset.zero,
                ),
              ],
            ),
            child: Text(
              'Top Students',
              style: _inter(12, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// Scrollable list body ────────────────────────────────────────────────────────
class _RankListBody extends StatelessWidget {
  const _RankListBody({required this.entries});
  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      itemCount: entries.length,
      itemBuilder: (BuildContext context, int index) =>
          _RankRow(entry: entries[index], isFirstRow: index == 0),
    );
  }
}

// Individual rank row ─────────────────────────────────────────────────────────
class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.isFirstRow});
  final LeaderboardEntry entry;
  final bool isFirstRow; // suppresses top border on the very first row

  // Badge circle fill colour by rank
  static Color _fill(int rank) {
    if (rank == 1) return _C.yellowAccent;
    if (rank == 2) return _C.silver;
    if (rank == 3) return _C.bronze;
    return const Color(0x282F6FED); // blue-tinted translucent for 4+
  }

  // BoxShadow glow colour by rank
  static Color _glow(int rank) {
    if (rank == 1) return const Color(0x80FFC839);
    if (rank == 2) return const Color(0x40C7D0E0);
    if (rank == 3) return const Color(0x40E0A972);
    return const Color(0x403B8CFF);
  }

  // Number text colour by rank
  static Color _numColor(int rank) {
    if (rank == 1) return _C.yellowDark;
    if (rank == 2) return _C.navyDeep;
    if (rank == 3) return _C.navyDeep;
    return _C.blueGlow;
  }

  @override
  Widget build(BuildContext context) {
    final int rank      = entry.rank;
    final bool isFirst  = rank == 1;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
      decoration: BoxDecoration(
        // Subtle yellow wash on the #1 row only
        color: isFirst ? const Color(0x12FFC839) : Colors.transparent,
        borderRadius: isFirst ? BorderRadius.circular(10) : null,
        // Thin top divider between rows — none on the very first item
        border: isFirstRow
            ? null
            : const Border(top: BorderSide(color: _C.divider, width: 0.8)),
      ),
      child: Row(
        children: <Widget>[
          // ── Rank badge ──────────────────────────────────────────────────
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _fill(rank),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: _glow(rank),
                  blurRadius: isFirst ? 16 : 8,
                  offset: Offset.zero,
                ),
              ],
            ),
            child: Text(
              '$rank',
              style: _inter(13, weight: FontWeight.w700, color: _numColor(rank)),
            ),
          ),
          const SizedBox(width: 12),
          // ── Student avatar (initials) ────────────────────────────────────
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.10),
              border: Border.all(color: _C.panelBorder),
            ),
            child: Text(
              _initials(entry.fullName),
              style: _inter(12, weight: FontWeight.w700, color: _C.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          // ── Student name (flex-grow) ─────────────────────────────────────
          Expanded(
            child: Text(
              entry.fullName,
              style: _inter(14, weight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          // ── Streak + flame ───────────────────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('🔥', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 5),
              Text(
                '${entry.bestEndlessStreak}',
                style: _baloo(17, weight: FontWeight.w700, color: _C.yellowAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
