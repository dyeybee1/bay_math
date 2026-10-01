import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:instructional_math_app/app/theme/app_theme.dart';
import 'package:instructional_math_app/core/errors/app_failure.dart';
import 'package:instructional_math_app/core/models/school.dart';
import 'package:instructional_math_app/core/models/school_year.dart';
import 'package:instructional_math_app/core/providers/supabase_providers.dart';
import 'package:instructional_math_app/core/repositories/school_years_repository.dart';
import 'package:instructional_math_app/core/widgets/widgets.dart';
import 'package:instructional_math_app/features/admin/presentation/school_years_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Administrator School Year closure confirmation', () {
    testWidgets('Close button opens the destructive confirmation dialog', (
      WidgetTester tester,
    ) async {
      final _FakeSchoolYearsRepository repository =
          _FakeSchoolYearsRepository();
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();

      await _openCloseDialog(tester);

      expect(find.text('Close School Year?'), findsOneWidget);
      expect(
        find.textContaining(
          'Are you sure you want to close School Year 2026–2027?',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('cannot be undone'), findsOneWidget);
      expect(find.text('Type CLOSE to confirm.'), findsOneWidget);
      expect(repository.closeCalls, 0);
    });

    testWidgets('Cancel closes the dialog without closing the school year', (
      WidgetTester tester,
    ) async {
      final _FakeSchoolYearsRepository repository =
          _FakeSchoolYearsRepository();
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await _openCloseDialog(tester);

      await tester.tap(find.byKey(const Key('cancel_close_school_year')));
      await tester.pumpAndSettle();

      expect(find.text('Close School Year?'), findsNothing);
      expect(repository.closeCalls, 0);
      expect(repository.years.single.status, SchoolYearStatus.active);
    });

    testWidgets('final Close button is disabled until exact CLOSE is typed', (
      WidgetTester tester,
    ) async {
      final _FakeSchoolYearsRepository repository =
          _FakeSchoolYearsRepository();
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await _openCloseDialog(tester);

      expect(_confirmButton(tester).onPressed, isNull);

      await tester.enterText(_confirmationField(), 'close');
      await tester.pump();
      expect(_confirmButton(tester).onPressed, isNull);

      await tester.enterText(_confirmationField(), 'CLOSE ');
      await tester.pump();
      expect(_confirmButton(tester).onPressed, isNull);

      await tester.enterText(_confirmationField(), 'CLOSE');
      await tester.pump();
      expect(_confirmButton(tester).onPressed, isNotNull);
    });

    testWidgets('wrong confirmation and Enter do not issue a close request', (
      WidgetTester tester,
    ) async {
      final _FakeSchoolYearsRepository repository =
          _FakeSchoolYearsRepository();
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await _openCloseDialog(tester);

      await tester.enterText(_confirmationField(), 'CLOS');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(repository.closeCalls, 0);
      expect(find.text('Close School Year?'), findsOneWidget);
    });

    testWidgets('outside click and Escape never confirm closure', (
      WidgetTester tester,
    ) async {
      final _FakeSchoolYearsRepository repository =
          _FakeSchoolYearsRepository();
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await _openCloseDialog(tester);

      await tester.tapAt(const Offset(2, 2));
      await tester.pump();
      expect(find.text('Close School Year?'), findsOneWidget);
      expect(repository.closeCalls, 0);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(repository.closeCalls, 0);
    });

    testWidgets('correct confirmation issues the close request only once', (
      WidgetTester tester,
    ) async {
      final Completer<void> closeCompleter = Completer<void>();
      final _FakeSchoolYearsRepository repository = _FakeSchoolYearsRepository(
        closeCompleter: closeCompleter,
      );
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await _openCloseDialog(tester);
      await tester.enterText(_confirmationField(), 'CLOSE');
      await tester.pump();

      final Finder confirm = find.byKey(const Key('confirm_close_school_year'));
      await tester.tap(confirm);
      await tester.tap(confirm);
      await tester.pump();

      expect(repository.closeCalls, 1);
      expect(_confirmButton(tester).isLoading, isTrue);
      expect(_confirmButton(tester).onPressed, isNull);

      closeCompleter.complete();
      await tester.pumpAndSettle();
      expect(repository.closeCalls, 1);
    });

    testWidgets('successful closure refreshes the list and shows success', (
      WidgetTester tester,
    ) async {
      final _FakeSchoolYearsRepository repository =
          _FakeSchoolYearsRepository();
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      expect(repository.fetchCalls, 1);

      await _openCloseDialog(tester);
      await tester.enterText(_confirmationField(), 'CLOSE');
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm_close_school_year')));
      await tester.pumpAndSettle();

      expect(repository.closeCalls, 1);
      expect(repository.fetchCalls, 2);
      expect(repository.years.single.status, SchoolYearStatus.closed);
      expect(find.text('Close School Year?'), findsNothing);
      expect(
        find.text('School Year 2026–2027 has been closed successfully.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('close_school_year_school-year')),
        findsNothing,
      );
    });

    testWidgets('failed closure keeps the dialog open and state unchanged', (
      WidgetTester tester,
    ) async {
      final _FakeSchoolYearsRepository repository = _FakeSchoolYearsRepository(
        closeFailure: const ServerFailure(
          'The school year could not be closed. Please try again.',
        ),
      );
      await tester.pumpWidget(_testApp(repository));
      await tester.pumpAndSettle();
      await _openCloseDialog(tester);
      await tester.enterText(_confirmationField(), 'CLOSE');
      await tester.pump();
      await tester.tap(find.byKey(const Key('confirm_close_school_year')));
      await tester.pumpAndSettle();

      expect(repository.closeCalls, 1);
      expect(repository.fetchCalls, 1);
      expect(repository.years.single.status, SchoolYearStatus.active);
      expect(find.text('Close School Year?'), findsOneWidget);
      expect(
        find.text('The school year could not be closed. Please try again.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('close_school_year_error')), findsOneWidget);
      expect(_confirmButton(tester).isLoading, isFalse);
      expect(_confirmButton(tester).onPressed, isNotNull);
      expect(find.textContaining('has been closed successfully'), findsNothing);
    });
  });
}

Future<void> _openCloseDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('close_school_year_school-year')));
  await tester.pumpAndSettle();
}

Finder _confirmationField() => find.descendant(
  of: find.byKey(const Key('close_school_year_confirmation_field')),
  matching: find.byType(TextField),
);

AppButton _confirmButton(WidgetTester tester) => tester.widget<AppButton>(
  find.byKey(const Key('confirm_close_school_year')),
);

Widget _testApp(_FakeSchoolYearsRepository repository) {
  return ProviderScope(
    overrides: [
      defaultSchoolProvider.overrideWith((Ref ref) async => _school),
      schoolYearsRepositoryProvider.overrideWithValue(repository),
      schoolYearsListProvider.overrideWith((Ref ref) => repository.fetchAll()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(body: SchoolYearsScreen()),
    ),
  );
}

final DateTime _now = DateTime.utc(2026, 9, 16);

final School _school = School(
  id: 'school',
  name: 'BayMath Academy',
  createdAt: _now,
  updatedAt: _now,
);

SchoolYear _activeYear() => SchoolYear(
  id: 'school-year',
  schoolId: _school.id,
  label: '2026–2027',
  startDate: DateTime.utc(2026, 6),
  endDate: DateTime.utc(2027, 4),
  isCurrent: true,
  status: SchoolYearStatus.active,
  createdAt: _now,
  updatedAt: _now,
);

final SupabaseClient _testClient = SupabaseClient(
  'http://localhost',
  'test-anon-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

class _FakeSchoolYearsRepository extends SchoolYearsRepository {
  _FakeSchoolYearsRepository({this.closeCompleter, this.closeFailure})
    : years = <SchoolYear>[_activeYear()],
      super(_testClient);

  final Completer<void>? closeCompleter;
  final AppFailure? closeFailure;
  final List<SchoolYear> years;

  int fetchCalls = 0;
  int closeCalls = 0;

  @override
  Future<List<SchoolYear>> fetchAll() async {
    fetchCalls += 1;
    return List<SchoolYear>.of(years);
  }

  @override
  Future<void> close(String yearId) async {
    closeCalls += 1;
    if (closeCompleter != null) await closeCompleter!.future;
    if (closeFailure != null) throw closeFailure!;

    final int index = years.indexWhere((SchoolYear year) => year.id == yearId);
    final SchoolYear year = years[index];
    years[index] = SchoolYear(
      id: year.id,
      schoolId: year.schoolId,
      label: year.label,
      startDate: year.startDate,
      endDate: year.endDate,
      isCurrent: false,
      status: SchoolYearStatus.closed,
      createdAt: year.createdAt,
      updatedAt: _now,
    );
  }
}
