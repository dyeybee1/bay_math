import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:instructional_math_app/app/router/app_routes.dart';
import 'package:instructional_math_app/app/theme/app_colors.dart';
import 'package:instructional_math_app/core/models/content_source_type.dart';
import 'package:instructional_math_app/core/models/lesson.dart';
import 'package:instructional_math_app/core/models/lesson_page.dart';
import 'package:instructional_math_app/core/models/section.dart';
import 'package:instructional_math_app/core/models/student_session.dart';
import 'package:instructional_math_app/core/providers/student_session_provider.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/lesson_progress_repository.dart';
import 'package:instructional_math_app/features/student/data/student_lessons_providers.dart';
import 'package:instructional_math_app/features/student/presentation/lesson_viewer_screen.dart';
import 'package:instructional_math_app/features/student/presentation/student_lessons_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _SavedProgress extends LessonProgressRepository {
  _SavedProgress()
    : super(
        SupabaseClient(
          'https://example.test',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  final Map<String, String> statuses = <String, String>{};

  @override
  Future<void> markInProgress({
    required String studentId,
    required String lessonId,
  }) async {
    statuses.putIfAbsent(lessonId, () => 'in_progress');
  }

  @override
  Future<Map<String, String>> fetchLessonStatuses() async =>
      Map<String, String>.of(statuses);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final String title in <String>[
    'Place Value of Whole Numbers',
    'Multiplication, Division, and MDAS',
    'Types of Fractions',
  ]) {
    testWidgets('$title returns to lessons from list and direct route', (
      WidgetTester tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 600);

      final Lesson lesson = Lesson(
        id: title,
        title: title,
        body: '',
        sourceType: ContentSourceType.builtIn,
        gradeLevel: GradeLevel.grade4,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final LessonPage page = LessonPage(
        id: 'page',
        lessonId: lesson.id,
        displayOrder: 0,
        title: title,
        body: 'Lesson content',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final _SavedProgress progress = _SavedProgress();
      final GoRouter router = GoRouter(
        initialLocation: AppRoutes.studentLessons,
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutes.studentLessons,
            builder:
                (BuildContext context, GoRouterState state) =>
                    const StudentLessonsScreen(),
          ),
          GoRoute(
            path: '/direct-lesson',
            builder:
                (BuildContext context, GoRouterState state) =>
                    LessonViewerScreen(lesson: lesson),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studentSessionProvider.overrideWith(
              (Ref ref) => StudentSession(
                accessToken: 'test-token',
                expiresAt: DateTime.utc(2100),
                studentId: 'student-1',
              ),
            ),
            lessonProgressRepositoryProvider.overrideWith(
              (Ref ref) => progress,
            ),
            studentVisibleLessonsProvider.overrideWith(
              (Ref ref) => Future<List<Lesson>>.value(<Lesson>[lesson]),
            ),
            studentLessonStatusesProvider.overrideWith(
              (Ref ref) => progress.fetchLessonStatuses(),
            ),
            lessonPagesProvider(lesson.id).overrideWith(
              (Ref ref) => Future<List<LessonPage>>.value(<LessonPage>[page]),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: router,
            theme: ThemeData(useMaterial3: true, colorScheme: AppColors.scheme),
            builder:
                (BuildContext context, Widget? child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(disableAnimations: true),
                  child: child!,
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Not started'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey<String>('lesson_tap_${lesson.id}')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back to lessons'), findsOneWidget);
      expect(find.byType(LessonViewerScreen), findsOneWidget);
      await tester.tap(find.byTooltip('Back to lessons'));
      await tester.pumpAndSettle();
      expect(find.byType(StudentLessonsScreen), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey<String>('lesson_tap_${lesson.id}')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back to lessons'), findsOneWidget);
      await tester.tap(find.byTooltip('Back to lessons'));
      await tester.pumpAndSettle();
      expect(find.text('In progress'), findsOneWidget);

      router.go('/direct-lesson');
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(360, 740);
      await tester.pumpAndSettle();
      expect(find.text('Turn your tablet sideways'), findsOneWidget);
      expect(find.byTooltip('Back to lessons'), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (title == 'Place Value of Whole Numbers') {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(
          tester.binding.focusManager.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<IconButton>(),
          isNotNull,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      } else {
        await tester.tap(find.byTooltip('Back to lessons'));
      }
      await tester.pumpAndSettle();
      expect(find.byType(StudentLessonsScreen), findsOneWidget);
      expect(find.text('In progress'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
