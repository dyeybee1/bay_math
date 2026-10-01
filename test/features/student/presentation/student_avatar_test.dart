import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:instructional_math_app/features/student/widgets/student_avatar.dart';

void main() {
  testWidgets('renders the saved catalog avatar when available', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StudentAvatar(fullName: 'Alex Rivera', avatarId: 'robot'),
        ),
      ),
    );

    expect(find.byIcon(Icons.smart_toy), findsOneWidget);
    expect(find.text('AR'), findsNothing);
  });

  testWidgets('falls back to initials for a missing or unknown avatar', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: <Widget>[
              StudentAvatar(fullName: 'Alex Rivera'),
              StudentAvatar(fullName: 'Sam', avatarId: 'retired-avatar'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('AR'), findsOneWidget);
    expect(find.text('SA'), findsOneWidget);
  });
}
