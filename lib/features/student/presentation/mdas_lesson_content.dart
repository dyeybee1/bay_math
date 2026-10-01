import '../../../core/models/content_source_type.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/section.dart';

/// The built-in seed generates its UUID, so use its stable Grade 4 metadata.
bool isMdasLesson(Lesson lesson) =>
    lesson.sourceType == ContentSourceType.builtIn &&
    lesson.gradeLevel == GradeLevel.grade4 &&
    lesson.title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ==
        'multiplication, division, and mdas';

const List<String> mdasPhases = <String>[
  'Equal groups',
  'Division',
  'Related facts',
  'MDAS order',
  'Solve steps',
  'Word problems',
  'Practice',
];

enum MdasTaskType {
  multiply,
  divide,
  facts,
  priority,
  first,
  solve,
  story,
  answer,
}

class MdasTaskSpec {
  const MdasTaskSpec(
    this.type, {
    this.a = 0,
    this.b = 0,
    this.operation = '',
    this.expression = const <Object>[],
  });
  final MdasTaskType type;
  final int a;
  final int b;
  final String operation;
  final List<Object> expression;
}

const List<List<MdasTaskSpec>> mdasTasks = <List<MdasTaskSpec>>[
  <MdasTaskSpec>[
    MdasTaskSpec(MdasTaskType.multiply, a: 6, b: 4),
    MdasTaskSpec(MdasTaskType.multiply, a: 7, b: 8),
    MdasTaskSpec(MdasTaskType.multiply, a: 9, b: 6),
  ],
  <MdasTaskSpec>[
    MdasTaskSpec(MdasTaskType.divide, a: 24, b: 6),
    MdasTaskSpec(MdasTaskType.divide, a: 45, b: 9),
    MdasTaskSpec(MdasTaskType.divide, a: 64, b: 8),
  ],
  <MdasTaskSpec>[MdasTaskSpec(MdasTaskType.facts, a: 6, b: 4)],
  <MdasTaskSpec>[
    MdasTaskSpec(MdasTaskType.priority),
    MdasTaskSpec(MdasTaskType.first, expression: <Object>[8, '×', 3, '+', 6]),
    MdasTaskSpec(MdasTaskType.first, expression: <Object>[24, '÷', 6, '×', 2]),
    MdasTaskSpec(MdasTaskType.first, expression: <Object>[20, '−', 6, '+', 2]),
  ],
  <MdasTaskSpec>[
    MdasTaskSpec(MdasTaskType.solve, expression: <Object>[8, '×', 3, '+', 6]),
    MdasTaskSpec(MdasTaskType.solve, expression: <Object>[24, '÷', 6, '×', 2]),
    MdasTaskSpec(MdasTaskType.solve, expression: <Object>[20, '−', 6, '+', 2]),
  ],
  <MdasTaskSpec>[
    MdasTaskSpec(MdasTaskType.story, a: 8, b: 12, operation: '×'),
    MdasTaskSpec(MdasTaskType.story, a: 56, b: 7, operation: '÷'),
  ],
  <MdasTaskSpec>[
    MdasTaskSpec(MdasTaskType.answer, a: 5, b: 7, operation: '×'),
    MdasTaskSpec(MdasTaskType.answer, a: 36, b: 6, operation: '÷'),
    MdasTaskSpec(MdasTaskType.solve, expression: <Object>[18, '÷', 3, '×', 2]),
    MdasTaskSpec(MdasTaskType.solve, expression: <Object>[15, '−', 4, '+', 3]),
  ],
];

int mdasCalculate(int a, String operation, int b) => switch (operation) {
  '×' => a * b,
  '÷' => a ~/ b,
  '+' => a + b,
  '−' => a - b,
  _ => throw ArgumentError.value(operation, 'operation'),
};

/// Multiplication and division share a level; addition and subtraction share
/// the next level. The first operator in the relevant level wins.
int mdasFirstOperation(List<Object> expression) {
  for (int i = 1; i < expression.length; i += 2) {
    if (expression[i] == '×' || expression[i] == '÷') return i;
  }
  return 1;
}

String mdasExpression(List<Object> expression) => expression.join(' ');
