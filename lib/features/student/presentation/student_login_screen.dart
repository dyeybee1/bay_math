import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/constants/app_layout_breakpoints.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';

/// BayMath brand palette for the Student Login screen only.
///
/// Deliberately kept local to this screen (not merged into the app-wide
/// `AppColors`) — that file documents a moderate/muted color decision
/// for the rest of the app, which this screen intentionally departs
/// from as part of the login-specific visual refresh. If the brand
/// direction is later adopted app-wide, promote these into
/// `app_colors.dart` instead of duplicating them.
class _LoginBrand {
  const _LoginBrand._();

  static const Color blue = Color(0xFF1E5FD9);
  static const Color blueDark = Color(0xFF0F2D6E);
  static const Color yellow = Color(0xFFFFC833);
  static const Color fieldBg = Color(0xFFF4F8FF);
  static const Color fieldBorder = Color(0xFFDCE7FA);
  static const Color heroBg = Color(0xFFF4F8FF);
  static const Color mutedText = Color(0xFF6B84A8);
}

/// Proves a student account created by a Teacher can actually log in
/// end-to-end (Phase 4 §4 priority 3). Deliberately bare — no lesson/quiz
/// content, no persistence across app restarts; that's later-phase scope
/// (§8). Not gated by `sessionProvider`/the Teacher-Admin redirect switch —
/// this route is reachable directly and independently of that logic (see
/// the note in `app_router.dart`).
class StudentLoginScreen extends ConsumerStatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  ConsumerState<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends ConsumerState<StudentLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final StudentSession session = await ref
          .read(studentAuthRepositoryProvider)
          .signIn(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
      ref.read(studentSessionProvider.notifier).state = session;
      final String destination = await _postLoginDestination(ref);
      if (mounted) context.go(destination);
    } on AppFailure catch (failure) {
      setState(() => _errorText = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Where to send a just-logged-in student: the first-login avatar picker
  /// if their `avatar_id` is still NULL (0053_student_avatar.sql), the home
  /// screen otherwise. Reads [studentProfileRepositoryProvider] directly
  /// (a fresh, un-cached call) rather than [ownStudentProfileProvider] —
  /// this is a one-shot routing decision made once, right after login, not
  /// something the UI needs to stay reactively subscribed to here.
  ///
  /// Deliberately fails open to the home screen on a profile-fetch error:
  /// the student already has a valid session at this point (`signIn`
  /// succeeded above), so a transient read failure here shouldn't block
  /// them out of the app entirely — worst case they just don't see the
  /// picker this session and can be prompted again next login, since
  /// `avatar_id` would still be NULL server-side.
  Future<String> _postLoginDestination(WidgetRef ref) async {
    try {
      final student =
          await ref.read(studentProfileRepositoryProvider)!.fetchOwnProfile();
      return student.avatarId == null
          ? AppRoutes.studentAvatarSelect
          : AppRoutes.studentHome;
    } catch (_) {
      return AppRoutes.studentHome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLayoutType layout = AppLayoutBreakpoints.of(context);
    final bool isWide = layout != AppLayoutType.compactLayout;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _LoginCard(
                  isWide: isWide,
                  usernameController: _usernameController,
                  passwordController: _passwordController,
                  obscurePassword: _obscurePassword,
                  onToggleObscure:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                  isSubmitting: _isSubmitting,
                  errorText: _errorText,
                  onSubmit: _submit,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.isWide,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isSubmitting,
    required this.errorText,
    required this.onSubmit,
  });

  final bool isWide;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isSubmitting;
  final String? errorText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final Widget hero = _LogoHero(compact: !isWide);
    final Widget form = _LoginForm(
      usernameController: usernameController,
      passwordController: passwordController,
      obscurePassword: obscurePassword,
      onToggleObscure: onToggleObscure,
      isSubmitting: isSubmitting,
      errorText: errorText,
      onSubmit: onSubmit,
    );

    final BoxDecoration cardDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE7EEFA), width: 0.5),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: _LoginBrand.blueDark.withValues(alpha: 0.06),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
        BoxShadow(
          color: _LoginBrand.blueDark.withValues(alpha: 0.06),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );

    // Tablet / desktop landscape: mascot and form sit side by side so both
    // are visible at once without scrolling. Narrow / portrait: stacked,
    // mascot on top, so the layout still reads top-to-bottom naturally.
    if (isWide) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: cardDecoration,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: hero),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 40,
                    ),
                    child: Center(child: form),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: cardDecoration,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[hero, const SizedBox(height: 24), form],
      ),
    );
  }
}

/// The branded hero panel — logo lives here. Swap the placeholder box
/// below for the real asset once `baymath_logo.png` is in
/// `assets/images/`.
class _LogoHero extends StatelessWidget {
  const _LogoHero({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final double size = compact ? 220 : 320;

    return Container(
      color: _LoginBrand.heroBg,
      padding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          const Positioned(
            top: 12,
            left: 8,
            child: _MathGlyph(icon: Icons.add, color: _LoginBrand.yellow),
          ),
          const Positioned(
            top: 24,
            right: 12,
            child: _MathGlyph(
              icon: Icons.close,
              color: _LoginBrand.blue,
              opacity: 0.5,
            ),
          ),
          const Positioned(
            bottom: 16,
            left: 16,
            child: _MathGlyph(icon: Icons.percent, color: _LoginBrand.yellow),
          ),
          const Positioned(
            bottom: 28,
            right: 8,
            child: _MathGlyph(
              icon: Icons.change_history,
              color: _LoginBrand.blue,
              opacity: 0.5,
            ),
          ),
          // ---- Replace this Container with the real logo asset: ----
          // Image.asset('assets/images/baymath_logo.png', width: size, height: size, fit: BoxFit.contain),
          Image.asset(
            'assets/images/baymath_logo_for_login.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
          ),
        ],
      ),
    );
  }
}

class _MathGlyph extends StatelessWidget {
  const _MathGlyph({
    required this.icon,
    required this.color,
    this.opacity = 1.0,
  });

  final IconData icon;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(opacity: opacity, child: Icon(icon, size: 20, color: color));
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.isSubmitting,
    required this.errorText,
    required this.onSubmit,
  });

  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final bool isSubmitting;
  final String? errorText;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 380),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'Welcome back!',
            style: GoogleFonts.fredoka(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _LoginBrand.blueDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Log in to continue learning.',
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: _LoginBrand.mutedText,
            ),
          ),
          const SizedBox(height: 28),
          const _BrandLabel('Username'),
          const SizedBox(height: 6),
          _BrandField(
            controller: usernameController,
            icon: Icons.person_outline,
            hint: 'juan.delacruz',
          ),
          const SizedBox(height: 16),
          const _BrandLabel('Password'),
          const SizedBox(height: 6),
          _BrandField(
            controller: passwordController,
            icon: Icons.lock_outline,
            hint: '••••••••',
            obscureText: obscurePassword,
            onSubmitted: (_) => onSubmit(),
            suffix: IconButton(
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _LoginBrand.mutedText,
                size: 20,
              ),
              tooltip: obscurePassword ? 'Show password' : 'Hide password',
              onPressed: onToggleObscure,
            ),
          ),
          if (errorText != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              errorText!,
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _LoginBrand.blue,
                disabledBackgroundColor: _LoginBrand.blue.withValues(
                  alpha: 0.6,
                ),
                foregroundColor: _LoginBrand.yellow,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child:
                  isSubmitting
                      ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _LoginBrand.yellow,
                        ),
                      )
                      : Text(
                        'Log in',
                        style: GoogleFonts.fredoka(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandLabel extends StatelessWidget {
  const _BrandLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.nunito(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF5B6270),
      ),
    );
  }
}

class _BrandField extends StatelessWidget {
  const _BrandField({
    required this.controller,
    required this.icon,
    required this.hint,
    this.obscureText = false,
    this.suffix,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscureText;
  final Widget? suffix;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: _LoginBrand.fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _LoginBrand.fieldBorder, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: _LoginBrand.blue),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              onSubmitted: onSubmitted,
              style: GoogleFonts.nunito(
                fontSize: 16,
                color: const Color(0xFF2A2E35),
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.nunito(
                  fontSize: 16,
                  color: _LoginBrand.mutedText,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isCollapsed: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}
