import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/router/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/models/student_session.dart';
import '../../../core/providers/student_session_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import 'student_login_hero.dart';

const Color _navy = Color(0xFF102D56);
const Color _ink = Color(0xFF16304F);
const Color _muted = Color(0xFF596E85);
const Color _blue = Color(0xFF245FDB);
const Color _gold = Color(0xFFFFCE64);
const Color _fieldBorder = Color(0xFFDBE4EE);
const Color _fieldBackground = Color(0xFFF7F9FC);
const Color _error = Color(0xFFAA3C30);

enum _LoginMessageKind { none, credentials, connection, other }

/// Student sign-in keeps the existing repository, session, and destination
/// decision. The surrounding widgets own only presentation and motion.
class StudentLoginScreen extends ConsumerStatefulWidget {
  const StudentLoginScreen({super.key});

  @override
  ConsumerState<StudentLoginScreen> createState() => _StudentLoginScreenState();
}

class _StudentLoginScreenState extends ConsumerState<StudentLoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode(debugLabel: 'Student username');
  final FocusNode _passwordFocus = FocusNode(debugLabel: 'Student password');
  final FocusNode _submitFocus = FocusNode(debugLabel: 'Student login button');
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  StudentLoginStage _stage = StudentLoginStage.idle;
  _LoginMessageKind _messageKind = _LoginMessageKind.none;
  String? _formMessage;
  bool _usernameMissing = false;
  bool _passwordMissing = false;
  bool _usernameHasText = false;
  bool _passwordHasText = false;
  bool _obscurePassword = true;
  bool _capsLock = false;
  bool _hoverButton = false;
  bool _pressButton = false;
  bool _submitting = false;
  bool _navigated = false;
  int _requestSerial = 0;
  int _usernameNudge = 0;
  int _passwordNudge = 0;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(_focusChanged);
    _passwordFocus.addListener(_focusChanged);
    _submitFocus.addListener(_focusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_reducedMotion) _entrance.forward(from: 0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _entrance.value = 1;
    }
  }

  @override
  void dispose() {
    _requestSerial++;
    _usernameFocus.removeListener(_focusChanged);
    _passwordFocus.removeListener(_focusChanged);
    _submitFocus.removeListener(_focusChanged);
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _submitFocus.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _entrance.dispose();
    super.dispose();
  }

  bool get _reducedMotion => MediaQuery.of(context).disableAnimations;
  bool get _motionEnabled => !_reducedMotion;

  void _settleEntrance() {
    if (_entrance.isAnimating) _entrance.value = 1;
  }

  void _focusChanged() {
    if (!mounted) return;
    _settleEntrance();
    final bool caps =
        _passwordFocus.hasFocus &&
        HardwareKeyboard.instance.lockModesEnabled.contains(
          KeyboardLockMode.capsLock,
        );
    setState(() => _capsLock = caps);
  }

  KeyEventResult _passwordKey(FocusNode node, KeyEvent event) {
    final bool caps = HardwareKeyboard.instance.lockModesEnabled.contains(
      KeyboardLockMode.capsLock,
    );
    if (caps != _capsLock) setState(() => _capsLock = caps);
    return KeyEventResult.ignored;
  }

  void _usernameChanged(String value) {
    final bool hasText = value.isNotEmpty;
    if (hasText != _usernameHasText ||
        _usernameMissing ||
        _formMessage != null) {
      setState(() {
        _usernameHasText = hasText;
        _usernameMissing = false;
        _clearFormMessage();
      });
    }
  }

  void _passwordChanged(String value) {
    final bool hasText = value.isNotEmpty;
    if (hasText != _passwordHasText ||
        _passwordMissing ||
        _formMessage != null) {
      setState(() {
        _passwordHasText = hasText;
        _passwordMissing = false;
        _clearFormMessage();
      });
    }
  }

  void _clearFormMessage() {
    _formMessage = null;
    _messageKind = _LoginMessageKind.none;
    if (_stage == StudentLoginStage.error) _stage = StudentLoginStage.idle;
  }

  void _togglePassword() {
    _settleEntrance();
    final TextSelection selection = _passwordController.selection;
    final bool hadFocus = _passwordFocus.hasFocus;
    setState(() => _obscurePassword = !_obscurePassword);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (selection.isValid) _passwordController.selection = selection;
      if (hadFocus) _passwordFocus.requestFocus();
    });
  }

  Future<void> _submit() async {
    if (_submitting || _navigated) return;
    _settleEntrance();
    final bool missingUsername = _usernameController.text.trim().isEmpty;
    final bool missingPassword = _passwordController.text.isEmpty;
    if (missingUsername || missingPassword) {
      setState(() {
        _usernameMissing = missingUsername;
        _passwordMissing = missingPassword;
        _clearFormMessage();
        if (missingUsername) _usernameNudge++;
        if (missingPassword) _passwordNudge++;
      });
      (missingUsername ? _usernameFocus : _passwordFocus).requestFocus();
      return;
    }

    FocusScope.of(context).unfocus();
    final int serial = ++_requestSerial;
    setState(() {
      _submitting = true;
      _stage = StudentLoginStage.checking;
      _clearFormMessage();
    });
    try {
      final StudentSession session = await ref
          .read(studentAuthRepositoryProvider)
          .signIn(
            username: _usernameController.text.trim(),
            password: _passwordController.text,
          );
      if (!mounted || serial != _requestSerial) return;

      // This profile read is the app's real post-login initialization. The
      // preparing message is visible only while that read is in progress.
      ref.read(studentSessionProvider.notifier).state = session;
      setState(() => _stage = StudentLoginStage.preparing);
      final String destination = await _postLoginDestination(ref);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _stage = StudentLoginStage.success;
        _submitting = false;
      });
      // Render the accepted state once, then use the existing destination.
      // No timer or artificial authentication progress is introduced.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || serial != _requestSerial || _navigated) return;
        _navigated = true;
        context.go(destination);
      });
    } on AppFailure catch (failure) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _submitting = false;
        _stage = StudentLoginStage.error;
        if (failure is NetworkFailure) {
          _messageKind = _LoginMessageKind.connection;
          _formMessage =
              'We couldn’t connect. Check your internet connection and try again.';
        } else if (failure is ValidationFailure) {
          _messageKind = _LoginMessageKind.credentials;
          _formMessage = 'Check your username and password, then try again.';
        } else {
          _messageKind = _LoginMessageKind.other;
          _formMessage = failure.message;
        }
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _submitting = false;
        _stage = StudentLoginStage.error;
        _messageKind = _LoginMessageKind.other;
        _formMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  /// Preserve the existing first-login avatar decision and fail-open home
  /// behavior if the profile read is unavailable after a valid sign-in.
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
    final Size size = MediaQuery.sizeOf(context);
    final bool keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bool wide = size.width >= 760 && size.width > size.height;
    final bool short = size.height < 690;
    final bool showHero = !keyboardOpen;
    final bool motionEnabled = _motionEnabled;

    return Scaffold(
      backgroundColor: const Color(0xFFEEF3F9),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  wide ? 24 : 16,
                  short || keyboardOpen ? 10 : 20,
                  wide ? 24 : 16,
                  keyboardOpen ? 12 : 24,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: showHero && wide ? 1140 : 520,
                      minHeight: showHero && wide ? 540 : 0,
                    ),
                    child: _loginCard(
                      wide: wide,
                      short: short,
                      showHero: showHero,
                      motionEnabled: motionEnabled,
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

  Widget _topBar() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: Row(
        children: <Widget>[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: _blue,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'BAYMATH · STUDENT',
              style: TextStyle(
                color: _muted,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _loginCard({
    required bool wide,
    required bool short,
    required bool showHero,
    required bool motionEnabled,
  }) {
    final Widget form = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? (short ? 30 : 48) : 24,
        vertical: wide ? (short ? 24 : 35) : 26,
      ),
      child: Center(child: _form(motionEnabled)),
    );
    final Widget content =
        wide && showHero
            ? IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    flex: 46,
                    child: StudentLoginHero(
                      compact: false,
                      short: short,
                      phase: _stage,
                      motionEnabled: motionEnabled,
                      allowParallax: motionEnabled,
                    ),
                  ),
                  Expanded(flex: 54, child: form),
                ],
              ),
            )
            : Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showHero)
                  StudentLoginHero(
                    compact: true,
                    short: short,
                    phase: _stage,
                    motionEnabled: motionEnabled,
                    allowParallax: false,
                  ),
                form,
              ],
            );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: Colors.white),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _navy.withValues(alpha: .08),
            blurRadius: 60,
            offset: const Offset(0, 18),
          ),
          BoxShadow(
            color: _navy.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  Widget _form(bool motionEnabled) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 430),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _EntranceItem(
          controller: _entrance,
          start: 0,
          enabled: motionEnabled,
          child: const Row(
            children: <Widget>[
              Icon(Icons.menu_book_outlined, color: _blue, size: 17),
              SizedBox(width: 7),
              Text(
                'STUDENT LOGIN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: _muted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        _EntranceItem(
          controller: _entrance,
          start: .10,
          enabled: motionEnabled,
          child: Text(
            key: const Key('student_login_heading'),
            'Welcome to BayMath.',
            style: GoogleFonts.nunito(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: _ink,
              height: 1.12,
            ),
          ),
        ),
        const SizedBox(height: 7),
        _EntranceItem(
          controller: _entrance,
          start: .17,
          enabled: motionEnabled,
          child: Text(
            'Your next lesson starts here.',
            style: GoogleFonts.nunito(fontSize: 15, color: _muted),
          ),
        ),
        const SizedBox(height: 22),
        _EntranceItem(
          controller: _entrance,
          start: .24,
          enabled: motionEnabled,
          child: _LoginField(
            key: const Key('student_username_field'),
            label: 'Username',
            hint: 'Enter your username',
            icon: Icons.person_outline_rounded,
            controller: _usernameController,
            focusNode: _usernameFocus,
            hasText: _usernameHasText,
            invalid: _usernameMissing,
            errorText: _usernameMissing ? 'Enter your username.' : null,
            nudgeSerial: _usernameNudge,
            motionEnabled: motionEnabled,
            onChanged: _usernameChanged,
            onSubmitted: (_) => _passwordFocus.requestFocus(),
            textInputAction: TextInputAction.next,
            autofillHints: const <String>[AutofillHints.username],
          ),
        ),
        const SizedBox(height: 14),
        _EntranceItem(
          controller: _entrance,
          start: .34,
          enabled: motionEnabled,
          child: Focus(
            onKeyEvent: _passwordKey,
            child: _LoginField(
              key: const Key('student_password_field'),
              label: 'Password',
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              controller: _passwordController,
              focusNode: _passwordFocus,
              hasText: _passwordHasText,
              invalid: _passwordMissing,
              errorText: _passwordMissing ? 'Enter your password.' : null,
              nudgeSerial: _passwordNudge,
              motionEnabled: motionEnabled,
              onChanged: _passwordChanged,
              onSubmitted: (_) => _submit(),
              textInputAction: TextInputAction.done,
              autofillHints: const <String>[AutofillHints.password],
              obscureText: _obscurePassword,
              suffix: TextButton.icon(
                key: const Key('student_password_visibility'),
                onPressed: _togglePassword,
                icon: AnimatedSwitcher(
                  duration:
                      motionEnabled
                          ? const Duration(milliseconds: 180)
                          : Duration.zero,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) =>
                          ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    key: ValueKey<bool>(_obscurePassword),
                    size: 19,
                  ),
                ),
                label: Text(_obscurePassword ? 'Show' : 'Hide'),
                style: TextButton.styleFrom(
                  minimumSize: const Size(82, 52),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  foregroundColor: _ink,
                ),
              ),
            ),
          ),
        ),
        if (_capsLock && _passwordFocus.hasFocus) ...<Widget>[
          const SizedBox(height: 7),
          Semantics(
            liveRegion: true,
            child: const Row(
              children: <Widget>[
                Icon(
                  Icons.keyboard_capslock_rounded,
                  color: Color(0xFF805815),
                  size: 17,
                ),
                SizedBox(width: 6),
                Text(
                  'Caps Lock is on',
                  style: TextStyle(color: Color(0xFF805815), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
        if (_formMessage != null) ...<Widget>[
          const SizedBox(height: 13),
          Semantics(
            liveRegion: true,
            child: Container(
              key: const Key('student_login_error'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    _messageKind == _LoginMessageKind.credentials
                        ? const Color(0xFFFFF3EF)
                        : const Color(0xFFFFF5E8),
                border: Border.all(
                  color:
                      _messageKind == _LoginMessageKind.credentials
                          ? const Color(0xFFE9C5BC)
                          : const Color(0xFFEBD3B3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _messageKind == _LoginMessageKind.connection
                        ? Icons.wifi_off_rounded
                        : Icons.info_outline_rounded,
                    color:
                        _messageKind == _LoginMessageKind.credentials
                            ? _error
                            : const Color(0xFF805815),
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _formMessage!,
                      style: const TextStyle(
                        color: Color(0xFF704516),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 21),
        _EntranceItem(
          controller: _entrance,
          start: .43,
          enabled: motionEnabled,
          child: _loginButton(motionEnabled),
        ),
        if (_stage == StudentLoginStage.checking ||
            _stage == StudentLoginStage.preparing) ...<Widget>[
          const SizedBox(height: 9),
          Semantics(
            liveRegion: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (_stage == StudentLoginStage.preparing) ...<Widget>[
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: 1),
                    duration:
                        motionEnabled
                            ? const Duration(milliseconds: 320)
                            : Duration.zero,
                    curve: Curves.easeOutBack,
                    builder:
                        (BuildContext context, double value, Widget? child) =>
                            Transform.scale(
                              key: const Key('student_login_accepted_scale'),
                              scale: value,
                              child: child,
                            ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF267553),
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _stage == StudentLoginStage.preparing
                      ? 'Preparing your learning space…'
                      : 'Checking your details…',
                  key: const Key('student_login_progress_text'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: _muted),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 19),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(Icons.help_outline_rounded, size: 17, color: _muted),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Need your login details? Ask your teacher.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _muted),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _loginButton(bool motionEnabled) {
    final bool busy = _submitting;
    final bool success = _stage == StudentLoginStage.success;
    final bool error = _stage == StudentLoginStage.error;
    final String label =
        success
            ? 'You’re in'
            : _stage == StudentLoginStage.preparing
            ? 'Preparing…'
            : _stage == StudentLoginStage.checking
            ? 'Signing in…'
            : error
            ? 'Try again'
            : 'Log in';
    return MouseRegion(
      onEnter: (_) => setState(() => _hoverButton = true),
      onExit: (_) => setState(() => _hoverButton = false),
      child: Listener(
        onPointerDown: (_) {
          if (motionEnabled) setState(() => _pressButton = true);
        },
        onPointerUp: (_) => setState(() => _pressButton = false),
        onPointerCancel: (_) => setState(() => _pressButton = false),
        child: AnimatedScale(
          scale: motionEnabled && _pressButton ? .99 : 1,
          duration:
              motionEnabled ? const Duration(milliseconds: 100) : Duration.zero,
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  FilledButton(
                    key: const Key('student_login_submit'),
                    focusNode: _submitFocus,
                    onPressed: busy || success ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          success
                              ? const Color(0xFF267553)
                              : error
                              ? const Color(0xFF365E96)
                              : _blue,
                      disabledBackgroundColor:
                          success
                              ? const Color(0xFF267553)
                              : const Color(0xFF386ACC),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                        side: BorderSide(
                          color:
                              _submitFocus.hasFocus
                                  ? _gold
                                  : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      splashFactory:
                          motionEnabled
                              ? InkRipple.splashFactory
                              : NoSplash.splashFactory,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (busy)
                          const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else if (success)
                          const Icon(Icons.check_rounded, size: 21)
                        else if (error)
                          const Icon(Icons.refresh_rounded, size: 20)
                        else
                          AnimatedSlide(
                            offset:
                                motionEnabled && _hoverButton
                                    ? const Offset(.14, 0)
                                    : Offset.zero,
                            duration:
                                motionEnabled
                                    ? const Duration(milliseconds: 160)
                                    : Duration.zero,
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              size: 21,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (busy)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: _gold,
                        backgroundColor: Color(0xFF386ACC),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EntranceItem extends StatelessWidget {
  const _EntranceItem({
    required this.controller,
    required this.start,
    required this.enabled,
    required this.child,
  });

  final AnimationController controller;
  final double start;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (BuildContext context, Widget? child) {
        final double t = ((controller.value - start) / (1 - start)).clamp(
          0.0,
          1.0,
        );
        final double eased = Curves.easeOutCubic.transform(t);
        return Opacity(
          opacity: .30 + .70 * eased,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - eased)),
            child: child,
          ),
        );
      },
    );
  }
}

class _LoginField extends StatefulWidget {
  const _LoginField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.controller,
    required this.focusNode,
    required this.hasText,
    required this.invalid,
    required this.errorText,
    required this.nudgeSerial,
    required this.motionEnabled,
    required this.onChanged,
    required this.onSubmitted,
    required this.textInputAction,
    required this.autofillHints,
    this.obscureText = false,
    this.suffix,
  });

  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasText;
  final bool invalid;
  final String? errorText;
  final int nudgeSerial;
  final bool motionEnabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final bool obscureText;
  final Widget? suffix;

  @override
  State<_LoginField> createState() => _LoginFieldState();
}

class _LoginFieldState extends State<_LoginField>
    with TickerProviderStateMixin {
  late final AnimationController _ack = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 230),
  );
  late final AnimationController _nudge = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 190),
  );

  @override
  void didUpdateWidget(covariant _LoginField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.motionEnabled) {
      _ack.stop();
      _nudge.stop();
      return;
    }
    if (!oldWidget.hasText && widget.hasText) _ack.forward(from: 0);
    if (oldWidget.nudgeSerial != widget.nudgeSerial) _nudge.forward(from: 0);
  }

  @override
  void dispose() {
    _ack.dispose();
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool focused = widget.focusNode.hasFocus;
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_ack, _nudge]),
      builder: (BuildContext context, Widget? child) {
        final double nudge =
            widget.motionEnabled
                ? math.sin(_nudge.value * math.pi * 2) * 3 * (1 - _nudge.value)
                : 0;
        return Transform.translate(offset: Offset(nudge, 0), child: child);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AnimatedDefaultTextStyle(
            duration:
                widget.motionEnabled
                    ? const Duration(milliseconds: 150)
                    : Duration.zero,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: focused ? _blue : _ink,
            ),
            child: Text(widget.label),
          ),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              AnimatedContainer(
                duration:
                    widget.motionEnabled
                        ? const Duration(milliseconds: 150)
                        : Duration.zero,
                width: 3,
                height: 56,
                margin: const EdgeInsets.only(right: 7),
                decoration: BoxDecoration(
                  color: focused ? _blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Expanded(
                child: AnimatedContainer(
                  key: Key('student_${widget.label.toLowerCase()}_border'),
                  duration:
                      widget.motionEnabled
                          ? const Duration(milliseconds: 150)
                          : Duration.zero,
                  height: 58,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color:
                        widget.invalid
                            ? const Color(0xFFFFF9F7)
                            : focused || widget.hasText
                            ? Colors.white
                            : _fieldBackground,
                    border: Border.all(
                      color:
                          widget.invalid
                              ? _error
                              : focused
                              ? _blue
                              : widget.hasText
                              ? const Color(0xFFBBCEE9)
                              : _fieldBorder,
                      width: focused || widget.invalid ? 2 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(13),
                    boxShadow:
                        focused
                            ? <BoxShadow>[
                              BoxShadow(
                                color: _blue.withValues(alpha: .08),
                                blurRadius: 0,
                                spreadRadius: 4,
                              ),
                            ]
                            : null,
                  ),
                  child: Row(
                    children: <Widget>[
                      AnimatedBuilder(
                        animation: _ack,
                        builder:
                            (
                              BuildContext context,
                              Widget? child,
                            ) => Transform.scale(
                              key: Key(
                                'student_${widget.label.toLowerCase()}_ack',
                              ),
                              scale:
                                  widget.motionEnabled
                                      ? 1 + .13 * math.sin(_ack.value * math.pi)
                                      : 1,
                              child: Transform.translate(
                                offset: Offset(
                                  0,
                                  widget.motionEnabled
                                      ? -2 * math.sin(_ack.value * math.pi)
                                      : 0,
                                ),
                                child: child,
                              ),
                            ),
                        child: AnimatedScale(
                          scale: focused && widget.motionEnabled ? 1.07 : 1,
                          duration:
                              widget.motionEnabled
                                  ? const Duration(milliseconds: 150)
                                  : Duration.zero,
                          child: Icon(
                            widget.icon,
                            size: 20,
                            color: focused ? _blue : const Color(0xFF7086A3),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Semantics(
                          label: widget.label,
                          textField: true,
                          child: TextField(
                            key: Key(
                              'student_${widget.label.toLowerCase()}_input',
                            ),
                            controller: widget.controller,
                            focusNode: widget.focusNode,
                            obscureText: widget.obscureText,
                            autocorrect: false,
                            enableSuggestions: false,
                            textCapitalization: TextCapitalization.none,
                            textInputAction: widget.textInputAction,
                            autofillHints: widget.autofillHints,
                            onChanged: widget.onChanged,
                            onSubmitted: widget.onSubmitted,
                            style: const TextStyle(fontSize: 16, color: _ink),
                            decoration: InputDecoration(
                              hintText: widget.hint,
                              hintStyle: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF77879C),
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              isCollapsed: true,
                            ),
                          ),
                        ),
                      ),
                      if (widget.suffix != null) widget.suffix!,
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (widget.errorText != null) ...<Widget>[
            const SizedBox(height: 6),
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline_rounded,
                      color: _error,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.errorText!,
                      style: const TextStyle(color: _error, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
