import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';

/// Header control shared by the Grade 4 guided lessons. It leaves the lesson
/// route without changing the activity state or the existing progress writes.
class LessonBackButton extends StatelessWidget {
  const LessonBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    key: const ValueKey<String>('lesson_back_button'),
    tooltip: 'Back to lessons',
    onPressed: () {
      final NavigatorState navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        context.go(AppRoutes.studentLessons);
      }
    },
    icon: const Icon(Icons.arrow_back_rounded),
    style: IconButton.styleFrom(
      minimumSize: const Size(52, 52),
      focusColor: AppColors.primary.withValues(alpha: .18),
    ),
  );
}
