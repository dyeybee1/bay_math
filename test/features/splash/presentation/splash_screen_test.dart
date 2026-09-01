import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/features/splash/presentation/splash_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BayMath splash presentation', () {
    testWidgets('fits supported phone, tablet, laptop, and desktop sizes', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final Size size in <Size>[
        const Size(320, 568),
        const Size(360, 640),
        const Size(768, 1024),
        const Size(1024, 700),
        const Size(1920, 1080),
      ]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        await tester.pumpWidget(_testApp());
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.byKey(const Key('baymath_splash_screen')), findsOneWidget);
        expect(find.byKey(const Key('splash_brand_panel')), findsOneWidget);
        expect(find.byKey(const Key('splash_baymath_logo')), findsOneWidget);
        expect(find.byKey(const Key('splash_loading_status')), findsOneWidget);
        expect(find.text('Preparing your learning space'), findsOneWidget);
        expect(find.byIcon(Icons.calculate_outlined), findsNothing);
        expect(tester.takeException(), isNull, reason: 'viewport: $size');
      }
    });

    testWidgets('keeps the official logo and loading treatment responsive', (
      WidgetTester tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 640);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_testApp());
      await tester.pump(const Duration(milliseconds: 600));

      final Size panelSize = tester.getSize(
        find.byKey(const Key('splash_brand_panel')),
      );
      final Size logoSize = tester.getSize(
        find.byKey(const Key('splash_baymath_logo')),
      );
      expect(panelSize.width, lessThanOrEqualTo(360));
      expect(logoSize.width, lessThanOrEqualTo(panelSize.width));
      expect(logoSize.width, greaterThan(0));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('honors reduced motion without changing its content', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SplashScreen(),
          ),
        ),
      );
      await tester.pump();

      final Opacity opacity = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacity.opacity, 1);
      expect(find.byKey(const Key('splash_baymath_logo')), findsOneWidget);
      expect(find.text('Preparing your learning space'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

Widget _testApp() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const SplashScreen(),
  );
}
