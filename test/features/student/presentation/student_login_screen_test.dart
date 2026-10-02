import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:instructional_math_app/app/router/app_routes.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/student.dart';
import 'package:instructional_math_app/core/models/student_session.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/student_auth_repository.dart';
import 'package:instructional_math_app/core/repositories/student_profile_repository.dart';
import 'package:instructional_math_app/features/student/presentation/student_login_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_login_hero.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final SupabaseClient _testClient = SupabaseClient(
  'https://example.test',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

final StudentSession _session = StudentSession(
  accessToken: 'test-token',
  expiresAt: DateTime.utc(2099),
  studentId: 'student-1',
);

class _Auth extends StudentAuthRepository {
  _Auth() : super(_testClient);

  int calls = 0;
  String? username;
  String? password;
  Future<StudentSession> Function()? respond;

  @override
  Future<StudentSession> signIn({
    required String username,
    required String password,
  }) {
    calls++;
    this.username = username;
    this.password = password;
    return respond?.call() ?? Future<StudentSession>.value(_session);
  }
}

class _Profile extends StudentProfileRepository {
  _Profile({this.avatarId, this.hold}) : super(_testClient);

  final String? avatarId;
  final Completer<void>? hold;
  int calls = 0;

  @override
  Future<Student> fetchOwnProfile() async {
    calls++;
    if (hold != null) await hold!.future;
    return Student(
      id: 'student-1',
      username: 'learner',
      fullName: 'Learner',
      createdBy: 'teacher-1',
      status: StudentStatus.active,
      bestEndlessStreak: 0,
      avatarId: avatarId,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
  }
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required _Auth auth,
  _Profile? profile,
  Size size = const Size(1024, 768),
  bool reducedMotion = true,
  Duration initialPump = const Duration(milliseconds: 400),
  void Function(String)? onDestination,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final GoRouter router = GoRouter(
    initialLocation: AppRoutes.studentLogin,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.studentLogin,
        builder:
            (BuildContext context, GoRouterState state) =>
                const StudentLoginScreen(),
      ),
      for (final String path in <String>[
        AppRoutes.studentHome,
        AppRoutes.studentAvatarSelect,
      ])
        GoRoute(
          path: path,
          builder: (BuildContext context, GoRouterState state) {
            onDestination?.call(path);
            return Scaffold(body: Text(path));
          },
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        studentAuthRepositoryProvider.overrideWith((Ref ref) => auth),
        studentProfileRepositoryProvider.overrideWith((Ref ref) => profile),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder:
            (BuildContext context, Widget? child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reducedMotion),
              child: child!,
            ),
      ),
    ),
  );
  await tester.pump(initialPump);
}

Future<({Uint8List pixels, int width, int height})> _heroFrame(
  WidgetTester tester,
) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('student_hero_canvas')),
      );
  return (await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 1);
    final ByteData data =
        (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final result = (
      pixels: data.buffer.asUint8List(),
      width: image.width,
      height: image.height,
    );
    image.dispose();
    return result;
  }))!;
}

Future<void> _saveHeroFrame(
  WidgetTester tester,
  String name, {
  Key boundaryKey = const Key('student_hero_canvas'),
}) async {
  final RenderRepaintBoundary boundary = tester
      .renderObject<RenderRepaintBoundary>(find.byKey(boundaryKey));
  await tester.runAsync(() async {
    final ui.Image image = await boundary.toImage(pixelRatio: 1);
    final ByteData data =
        (await image.toByteData(format: ui.ImageByteFormat.png))!;
    image.dispose();
    final Directory directory = Directory('build/student_login_visuals');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(data.buffer.asUint8List());
  });
}

int _changedLowerPixels(
  ({Uint8List pixels, int width, int height}) first,
  ({Uint8List pixels, int width, int height}) second,
) {
  expect(second.width, first.width);
  expect(second.height, first.height);
  int changed = 0;
  for (int y = (first.height * .7).round(); y < first.height; y++) {
    for (int x = 0; x < first.width; x++) {
      final int at = (y * first.width + x) * 4;
      final int delta =
          (first.pixels[at] - second.pixels[at]).abs() +
          (first.pixels[at + 1] - second.pixels[at + 1]).abs() +
          (first.pixels[at + 2] - second.pixels[at + 2]).abs();
      if (delta > 25) changed++;
    }
  }
  return changed;
}

Future<void> _enterCredentials(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const Key('student_username_input')),
    ' learner ',
  );
  await tester.enterText(
    find.byKey(const Key('student_password_input')),
    'secret  ',
  );
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('required fields focus the first missing input', (
    WidgetTester tester,
  ) async {
    final _Auth auth = _Auth();
    await _pumpLogin(tester, auth: auth);
    await tester.tap(find.byKey(const Key('student_login_submit')));
    await tester.pump();

    expect(find.text('Enter your username.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('student_username_input')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    expect(auth.calls, 0);

    await tester.enterText(
      find.byKey(const Key('student_username_input')),
      'learner',
    );
    await tester.tap(find.byKey(const Key('student_login_submit')));
    await tester.pump();
    expect(find.text('Enter your username.'), findsNothing);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('password reveal preserves exact value and cursor', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(tester, auth: _Auth());
    final Finder input = find.byKey(const Key('student_password_input'));
    await tester.enterText(input, '  keep spaces  ');
    await tester.showKeyboard(input);
    final TextField before = tester.widget<TextField>(input);
    before.controller!.selection = const TextSelection.collapsed(offset: 3);

    await tester.tap(find.byKey(const Key('student_password_visibility')));
    await tester.pump();
    final TextField after = tester.widget<TextField>(input);
    expect(after.obscureText, isFalse);
    expect(after.controller!.text, '  keep spaces  ');
    expect(after.controller!.selection.baseOffset, 3);
    expect(after.focusNode!.hasFocus, isTrue);
  });

  testWidgets('password eye transition is visible with motion enabled', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(tester, auth: _Auth(), reducedMotion: false);
    await tester.tap(find.byKey(const Key('student_password_visibility')));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });

  testWidgets('loading prevents duplicate requests and shows real phases', (
    WidgetTester tester,
  ) async {
    final Completer<StudentSession> pending = Completer<StudentSession>();
    final _Auth auth = _Auth()..respond = () => pending.future;
    final List<String> destinations = <String>[];
    await _pumpLogin(
      tester,
      auth: auth,
      profile: _Profile(avatarId: 'owl'),
      onDestination: destinations.add,
    );
    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('student_login_submit')));
    await tester.pump();
    expect(find.text('Checking your details…'), findsWidgets);
    expect(find.text('Signing in…'), findsOneWidget);
    expect(auth.calls, 1);
    expect(auth.username, 'learner');
    expect(auth.password, 'secret  ');
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('student_login_submit')))
          .onPressed,
      isNull,
    );

    pending.complete(_session);
    await tester.pump();
    await tester.pump();
    expect(auth.calls, 1);
    await tester.pump();
    expect(destinations, <String>[AppRoutes.studentHome]);
  });

  testWidgets(
    'invalid credentials and network failures have distinct messages',
    (WidgetTester tester) async {
      final _Auth auth =
          _Auth()
            ..respond =
                () => Future<StudentSession>.error(
                  const ValidationFailure('invalid_credentials'),
                );
      await _pumpLogin(tester, auth: auth);
      await _enterCredentials(tester);
      await tester.tap(find.byKey(const Key('student_login_submit')));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('Check your username and password, then try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);

      auth.respond = () => Future<StudentSession>.error(const NetworkFailure());
      await tester.tap(find.byKey(const Key('student_login_submit')));
      await tester.pump();
      await tester.pump();
      expect(
        find.text(
          'We couldn’t connect. Check your internet connection and try again.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Check your username and password, then try again.'),
        findsNothing,
      );
    },
  );

  testWidgets('preparation appears only during the real profile read', (
    WidgetTester tester,
  ) async {
    final Completer<void> profileRead = Completer<void>();
    final _Profile profile = _Profile(avatarId: 'owl', hold: profileRead);
    final List<String> destinations = <String>[];
    await _pumpLogin(
      tester,
      auth: _Auth(),
      profile: profile,
      reducedMotion: false,
      onDestination: destinations.add,
    );
    await _enterCredentials(tester);
    await tester.tap(find.byKey(const Key('student_login_submit')));
    await tester.pump();
    expect(profile.calls, 1);
    expect(find.text('Preparing your learning space…'), findsWidgets);
    expect(find.text('Preparing…'), findsOneWidget);
    expect(destinations, isEmpty);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    expect(
      tester
          .widget<Transform>(
            find.byKey(const Key('student_login_accepted_scale')),
          )
          .transform
          .entry(0, 0),
      greaterThan(.1),
    );

    profileRead.complete();
    await tester.pump();
    await tester.pump();
    expect(destinations, <String>[AppRoutes.studentHome]);
  });

  testWidgets('avatar destination, responsive rebuild, and reduced motion', (
    WidgetTester tester,
  ) async {
    final _Auth auth = _Auth();
    final List<String> destinations = <String>[];
    await _pumpLogin(
      tester,
      auth: auth,
      profile: _Profile(),
      size: const Size(1024, 600),
      onDestination: destinations.add,
    );
    expect(find.byKey(const Key('student_motion_toggle')), findsNothing);
    await _enterCredentials(tester);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('student_username_input')))
          .controller!
          .text,
      ' learner ',
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('student_password_input')))
          .controller!
          .text,
      'secret  ',
    );
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('student_login_submit')));
    await tester.tap(find.byKey(const Key('student_login_submit')));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(destinations, <String>[AppRoutes.studentAvatarSelect]);
  });

  testWidgets('tablet, portrait, and keyboard-open layouts do not overflow', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(tester, auth: _Auth(), size: const Size(1024, 600));
    for (final Size size in <Size>[
      const Size(1024, 600),
      const Size(1024, 768),
      const Size(1280, 800),
      const Size(768, 1024),
      const Size(390, 844),
      const Size(320, 568),
    ]) {
      tester.view.physicalSize = size;
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'layout at $size');
      expect(find.byKey(const Key('student_login_submit')), findsOneWidget);
    }
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('student_login_submit')));
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
  });

  testWidgets('page entrance reveals its heading within 450 ms', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(
      tester,
      auth: _Auth(),
      reducedMotion: false,
      initialPump: Duration.zero,
    );
    final Finder heading = find.byKey(const Key('student_login_heading'));
    final Finder headingOpacity = find.ancestor(
      of: heading,
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(headingOpacity.first).opacity, lessThan(.5));
    await tester.pump(const Duration(milliseconds: 450));
    expect(
      tester.widget<Opacity>(headingOpacity.first).opacity,
      closeTo(1, .01),
    );
  });

  testWidgets('hero graph changes rendered frames, then settles', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(440, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: RepaintBoundary(
          key: Key('student_hero_full'),
          child: StudentLoginHero(
            compact: false,
            short: true,
            phase: StudentLoginStage.idle,
            motionEnabled: true,
            allowParallax: false,
          ),
        ),
      ),
    );
    await tester.pump(Duration.zero);
    final initial = await _heroFrame(tester);
    if (const bool.fromEnvironment('CAPTURE_STUDENT_HERO')) {
      await _saveHeroFrame(tester, 'hero_initial');
    }
    final Offset logoPosition = tester.getTopLeft(
      find.byKey(const Key('student_login_logo')),
    );

    await tester.pump(const Duration(milliseconds: 450));
    final halfway = await _heroFrame(tester);
    if (const bool.fromEnvironment('CAPTURE_STUDENT_HERO')) {
      await _saveHeroFrame(tester, 'hero_450ms');
    }
    expect(_changedLowerPixels(initial, halfway), greaterThan(70));

    await tester.pump(const Duration(milliseconds: 500));
    final drawn = await _heroFrame(tester);
    expect(_changedLowerPixels(halfway, drawn), greaterThan(50));
    expect(
      tester.getTopLeft(find.byKey(const Key('student_login_logo'))),
      logoPosition,
    );
    final Image logo = tester.widget<Image>(
      find.byKey(const Key('student_login_logo')),
    );
    expect(logo.fit, BoxFit.contain);
    expect(
      (logo.image as AssetImage).assetName,
      'assets/images/baymath_logo_for_login.png',
    );

    await tester.pump(const Duration(milliseconds: 900));
    final settled = await _heroFrame(tester);
    if (const bool.fromEnvironment('CAPTURE_STUDENT_HERO')) {
      await _saveHeroFrame(tester, 'hero_settled');
      await _saveHeroFrame(
        tester,
        'hero_full',
        boundaryKey: const Key('student_hero_full'),
      );
    }
    await tester.pump(const Duration(seconds: 1));
    final still = await _heroFrame(tester);
    expect(_changedLowerPixels(settled, still), 0);
    expect(find.byKey(const Key('student_motion_toggle')), findsNothing);
  });

  testWidgets('hero uses a static complete graph with reduced motion', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(440, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: StudentLoginHero(
          compact: false,
          short: true,
          phase: StudentLoginStage.idle,
          motionEnabled: false,
          allowParallax: false,
        ),
      ),
    );
    final first = await _heroFrame(tester);
    await tester.pump(const Duration(seconds: 2));
    final later = await _heroFrame(tester);
    expect(_changedLowerPixels(first, later), 0);
  });

  testWidgets('focus stays at the field and typing acknowledges once', (
    WidgetTester tester,
  ) async {
    await _pumpLogin(tester, auth: _Auth(), reducedMotion: false);
    final Finder username = find.byKey(const Key('student_username_input'));
    await tester.tap(username);
    await tester.pump(const Duration(milliseconds: 170));
    expect(find.text('Start with your username'), findsNothing);
    expect(find.textContaining('password stays private'), findsNothing);
    final AnimatedContainer border = tester.widget<AnimatedContainer>(
      find.byKey(const Key('student_username_border')),
    );
    expect(
      (border.decoration! as BoxDecoration).border!.top.color,
      const Color(0xFF245FDB),
    );

    await tester.enterText(username, 'l');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final Transform firstAck = tester.widget<Transform>(
      find.byKey(const Key('student_username_ack')),
    );
    expect(firstAck.transform.entry(0, 0), greaterThan(1.05));
    await tester.pump(const Duration(milliseconds: 260));
    await tester.enterText(username, 'le');
    await tester.pump(const Duration(milliseconds: 100));
    final Transform secondKey = tester.widget<Transform>(
      find.byKey(const Key('student_username_ack')),
    );
    expect(secondKey.transform.entry(0, 0), closeTo(1, .001));
  });

  testWidgets(
    'reduced motion keeps the hero static and field feedback visible',
    (WidgetTester tester) async {
      await _pumpLogin(tester, auth: _Auth(), reducedMotion: true);
      expect(
        tester
            .widget<AnimatedContainer>(
              find.byKey(const Key('student_username_border')),
            )
            .duration,
        Duration.zero,
      );
      expect(find.byKey(const Key('student_motion_toggle')), findsNothing);
      await tester.tap(find.byKey(const Key('student_username_input')));
      await tester.pump();
      expect(
        (tester
                    .widget<AnimatedContainer>(
                      find.byKey(const Key('student_username_border')),
                    )
                    .decoration!
                as BoxDecoration)
            .border!
            .top
            .color,
        const Color(0xFF245FDB),
      );
    },
  );

  testWidgets(
    'Enter submits and pending completion after disposal is ignored',
    (WidgetTester tester) async {
      final Completer<StudentSession> pending = Completer<StudentSession>();
      final _Auth auth = _Auth()..respond = () => pending.future;
      await _pumpLogin(tester, auth: auth);
      await _enterCredentials(tester);
      await tester.showKeyboard(
        find.byKey(const Key('student_password_input')),
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(auth.calls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete(_session);
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
