import 'mdas_lesson_content.dart';

enum MdasCardKind { bundle, group, number, operation }

enum MdasTargetKind { tray, newGroup, fact, priority }

enum MdasStep { choose, result }

class MdasCard {
  const MdasCard(
    this.kind, {
    this.id = -1,
    this.number = -1,
    this.operation = '',
  });
  final MdasCardKind kind;
  final int id;
  final int number;
  final String operation;
  String get identity => '$kind:$id:$number:$operation';
}

class MdasTarget {
  const MdasTarget(this.kind, {this.id = -1, this.row = -1});
  final MdasTargetKind kind;
  final int id;
  final int row;
  String get identity => '$kind:$id:$row';
}

class MdasFeedback {
  const MdasFeedback(this.text, {required this.correct});
  final String text;
  final bool correct;
}

class MdasActivity {
  MdasActivity(this.spec) : expression = List<Object>.of(spec.expression);
  final MdasTaskSpec spec;
  final Set<int> placedBundles = <int>{};
  final Set<int> filledTrays = <int>{};
  int groupsMade = 0;
  final Map<int, int> facts = <int, int>{};
  final Map<int, String> priorities = <int, String>{};
  List<Object> expression;
  final List<String> history = <String>[];
  MdasStep step = MdasStep.choose;
  int? selectedOperation;
  int? answer;
  bool done = false;
  int hints = 0;
  MdasFeedback? feedback;

  int get remainingObjects => spec.a - groupsMade * spec.b;
  int get runningTotal => placedBundles.length * spec.a;
  int get expectedAnswer => mdasCalculate(spec.a, spec.operation, spec.b);
  int get activeOperation => mdasFirstOperation(expression);
  int get activeResult => mdasCalculate(
    expression[activeOperation - 1] as int,
    expression[activeOperation] as String,
    expression[activeOperation + 1] as int,
  );
}

class MdasLessonState {
  int phase = 0;
  final List<int> indices = List<int>.filled(7, 0);
  late final List<List<MdasActivity>> tasks =
      mdasTasks
          .map(
            (List<MdasTaskSpec> specs) => specs.map(MdasActivity.new).toList(),
          )
          .toList();
  MdasCard? selectedCard;
  bool recap = false;
  bool finished = false;

  MdasActivity get current => tasks[phase][indices[phase]];
  int get practiceCompleted =>
      tasks[6].where((MdasActivity task) => task.done).length;
  bool get practiceDone => practiceCompleted == tasks[6].length;
  bool phaseUnlocked(int target) =>
      target == 0 ||
      tasks
          .take(target)
          .every(
            (List<MdasActivity> phaseTasks) =>
                phaseTasks.every((MdasActivity task) => task.done),
          );

  bool navigate(int target) {
    if (target < 0 || target > 6 || !phaseUnlocked(target)) return false;
    phase = target;
    selectedCard = null;
    return true;
  }

  void select(MdasCard card) {
    selectedCard = selectedCard?.identity == card.identity ? null : card;
  }

  bool next() {
    if (recap || !current.done) return false;
    selectedCard = null;
    if (indices[phase] < tasks[phase].length - 1) {
      indices[phase]++;
    } else if (phase < 6) {
      phase++;
    } else if (practiceDone) {
      recap = true;
    }
    return true;
  }

  bool previous() {
    selectedCard = null;
    if (recap) {
      recap = false;
      return true;
    }
    if (indices[phase] > 0) {
      indices[phase]--;
      return true;
    }
    if (phase > 0) {
      phase--;
      return true;
    }
    return false;
  }

  void reviewPractice() {
    phase = 6;
    indices[6] = 0;
    recap = false;
    selectedCard = null;
  }

  bool drop(MdasCard card, MdasTarget target) {
    selectedCard = null;
    if (recap || current.done) return false;
    final MdasActivity task = current;
    switch (task.spec.type) {
      case MdasTaskType.multiply:
        if (card.kind != MdasCardKind.bundle ||
            target.kind != MdasTargetKind.tray) {
          return _wrong(task, 'Place one equal group into a tray.');
        }
        if (card.id < 0 ||
            card.id >= task.spec.b ||
            target.id < 0 ||
            target.id >= task.spec.b ||
            task.placedBundles.contains(card.id) ||
            task.filledTrays.contains(target.id)) {
          return false;
        }
        task.placedBundles.add(card.id);
        task.filledTrays.add(target.id);
        task.done = task.placedBundles.length == task.spec.b;
        return _right(
          task,
          task.done
              ? 'You built ${task.spec.b} groups of ${task.spec.a}. The total is ${task.spec.a * task.spec.b}.'
              : '${task.placedBundles.length} groups placed. Total so far: ${task.runningTotal}.',
        );
      case MdasTaskType.divide:
        if (card.kind != MdasCardKind.group ||
            target.kind != MdasTargetKind.newGroup) {
          return _wrong(
            task,
            'Move the outlined group of ${task.spec.b} objects into the blue box.',
          );
        }
        if (card.id != task.groupsMade ||
            task.groupsMade >= task.spec.a ~/ task.spec.b) {
          return false;
        }
        task.groupsMade++;
        task.done = task.groupsMade == task.spec.a ~/ task.spec.b;
        return _right(
          task,
          task.done
              ? '${task.groupsMade} equal groups of ${task.spec.b}. ${task.spec.a} ÷ ${task.spec.b} = ${task.groupsMade}.'
              : 'One more group of ${task.spec.b}. ${task.remainingObjects} objects remain.',
        );
      case MdasTaskType.facts:
        if (card.kind != MdasCardKind.number ||
            target.kind != MdasTargetKind.fact) {
          return _wrong(task, 'Use a number card to fill an equation.');
        }
        if (target.id < 0 ||
            target.id >= 12 ||
            task.facts.containsKey(target.id)) {
          return false;
        }
        final List<int> expected = <int>[
          6,
          4,
          24,
          4,
          6,
          24,
          24,
          6,
          4,
          24,
          4,
          6,
        ];
        if (card.number != expected[target.id]) {
          return _wrong(
            task,
            target.id >= 6 && target.id % 3 == 0
                ? 'For division, start with the total.'
                : 'Use the same groups and total. Check the picture.',
          );
        }
        task.facts[target.id] = card.number;
        task.done = task.facts.length == 12;
        return _right(
          task,
          task.done
              ? 'Multiplication and division describe the same groups and total.'
              : 'Correct. Complete the related equations.',
        );
      case MdasTaskType.priority:
        if (card.kind != MdasCardKind.operation ||
            target.kind != MdasTargetKind.priority) {
          return _wrong(task, 'Place an operation in a priority row.');
        }
        if (target.id < 0 ||
            target.id >= 4 ||
            task.priorities.containsKey(target.id) ||
            task.priorities.containsValue(card.operation)) {
          return false;
        }
        final int expectedRow =
            card.operation == '×' || card.operation == '÷' ? 0 : 1;
        if (!<String>{'×', '÷', '+', '−'}.contains(card.operation) ||
            target.row != expectedRow ||
            target.id ~/ 2 != expectedRow) {
          return _wrong(
            task,
            'Solve × and ÷ first. Then solve + and −. Each pair has equal priority.',
          );
        }
        task.priorities[target.id] = card.operation;
        task.done = task.priorities.length == 4;
        return _right(
          task,
          task.done
              ? 'Equal priority within each row. Work from left to right.'
              : 'Correct row. These operations share priority.',
        );
      case MdasTaskType.first ||
          MdasTaskType.solve ||
          MdasTaskType.story ||
          MdasTaskType.answer:
        return false;
    }
  }

  bool chooseOperation(int index) {
    final MdasActivity task = current;
    if (recap ||
        task.done ||
        (task.spec.type != MdasTaskType.first &&
            task.spec.type != MdasTaskType.solve) ||
        task.step != MdasStep.choose ||
        index < 1 ||
        index >= task.expression.length ||
        index.isEven) {
      return false;
    }
    final int correctIndex = task.activeOperation;
    if (index != correctIndex) {
      final bool high = task.expression.any(
        (Object token) => token == '×' || token == '÷',
      );
      return _wrong(
        task,
        high && (task.expression[index] == '+' || task.expression[index] == '−')
            ? 'Multiplication and division come before addition and subtraction.'
            : 'These operations have equal priority. Start with the one on the left.',
      );
    }
    task.selectedOperation = index;
    final String part = _part(task.expression, index);
    if (task.spec.type == MdasTaskType.first) {
      task.done = true;
      return _right(
        task,
        'Start with $part. Equal priority means work left to right.',
      );
    }
    task.step = MdasStep.result;
    return _right(task, 'Correct operation. Find $part.');
  }

  bool chooseStoryOperation(String operation) {
    final MdasActivity task = current;
    if (recap ||
        task.done ||
        task.spec.type != MdasTaskType.story ||
        task.step != MdasStep.choose) {
      return false;
    }
    if (operation != task.spec.operation) {
      return _wrong(
        task,
        task.spec.operation == '×'
            ? 'You know the boxes and the amount in each. Find the total.'
            : 'The total is shared equally among seven students.',
      );
    }
    task.selectedOperation = 1;
    task.step = MdasStep.result;
    return _right(
      task,
      operation == '×'
          ? 'Multiply to find the total mangoes.'
          : 'Divide to find how many pencils each student receives.',
    );
  }

  bool chooseAnswer(int value) {
    final MdasActivity task = current;
    if (recap || task.done) return false;
    if (task.spec.type == MdasTaskType.solve) {
      if (task.step != MdasStep.result) return false;
      final int index = task.activeOperation;
      final int expected = task.activeResult;
      if (value != expected) {
        return _wrong(
          task,
          'The operation is correct. Check ${_part(task.expression, index)} again.',
        );
      }
      task.history.add('${_part(task.expression, index)} = $expected');
      task.expression.replaceRange(index - 1, index + 2, <Object>[expected]);
      task.selectedOperation = null;
      task.step = MdasStep.choose;
      task.done = task.expression.length == 1;
      return _right(
        task,
        task.done
            ? 'The final answer is $expected.'
            : 'Correct. Only the solved part changed. Choose the next operation.',
      );
    }
    if (task.spec.type != MdasTaskType.answer &&
        task.spec.type != MdasTaskType.story) {
      return false;
    }
    if (task.spec.type == MdasTaskType.story && task.step != MdasStep.result) {
      return false;
    }
    if (value != task.expectedAnswer) {
      return _wrong(
        task,
        task.spec.operation == '×'
            ? 'Count ${task.spec.b} groups of ${task.spec.a}, or multiply.'
            : 'Find the number that gives ${task.spec.a} when multiplied by ${task.spec.b}.',
      );
    }
    task.answer = value;
    task.done = true;
    return _right(
      task,
      '${task.spec.a} ${task.spec.operation} ${task.spec.b} = $value'
      '${task.spec.type == MdasTaskType.story
          ? task.spec.operation == '×'
              ? ' mangoes in all.'
              : ' pencils each.'
          : '.'}',
    );
  }

  void requestHint() {
    final MdasActivity task = current;
    task.hints++;
    task.feedback = MdasFeedback(hintFor(task), correct: false);
  }

  String hintFor(MdasActivity task) => switch (task.spec.type) {
    MdasTaskType.multiply =>
      'Count the groups. Every group contains ${task.spec.a} objects.',
    MdasTaskType.divide =>
      'Drag the outlined group of ${task.spec.b} objects into the blue box.',
    MdasTaskType.facts => 'For division, start with the total, 24.',
    MdasTaskType.priority =>
      '× and ÷ go first. + and − go next. Work left to right within each pair.',
    MdasTaskType.first || MdasTaskType.solve =>
      'Solve × and ÷ from left to right, then + and − from left to right.',
    MdasTaskType.story || MdasTaskType.answer =>
      task.spec.operation == '×'
          ? 'Multiply the number of groups by the amount in each group.'
          : 'Find the number that gives ${task.spec.a} when multiplied by ${task.spec.b}.',
  };

  bool _wrong(MdasActivity task, String text) {
    task.feedback = MdasFeedback(text, correct: false);
    return false;
  }

  bool _right(MdasActivity task, String text) {
    task.feedback = MdasFeedback(text, correct: true);
    return true;
  }

  String _part(List<Object> expression, int index) =>
      '${expression[index - 1]} ${expression[index]} ${expression[index + 1]}';
}
