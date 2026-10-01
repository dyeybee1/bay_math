import '../../../core/models/content_source_type.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/section.dart';

/// The seeded lesson has a generated ID, so match its stable metadata.
bool isPlaceValueLesson(Lesson lesson) =>
    lesson.sourceType == ContentSourceType.builtIn &&
    lesson.gradeLevel == GradeLevel.grade4 &&
    lesson.title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase() ==
        'place value of whole numbers';

const List<String> placeValuePhases = <String>[
  'Explore',
  'Place & value',
  'Standard form',
  'Expanded form',
  'Same digits',
  'Practice',
];
const List<String> placeValueNames = <String>[
  'Millions',
  'Hundred thousands',
  'Ten thousands',
  'Thousands',
  'Hundreds',
  'Tens',
  'Ones',
];
const List<int> placeValueUnits = <int>[
  1000000,
  100000,
  10000,
  1000,
  100,
  10,
  1,
];

enum PlaceTaskType { align, identify, standard, expanded, reverse, repeat }

class PlaceTaskSpec {
  const PlaceTaskSpec(this.type, this.number, {this.highlight = -1});
  final PlaceTaskType type;
  final int number;

  /// Index from the first written digit, so repeated digits stay distinct.
  final int highlight;
}

const List<List<PlaceTaskSpec>> placeValueTasks = <List<PlaceTaskSpec>>[
  <PlaceTaskSpec>[],
  <PlaceTaskSpec>[
    PlaceTaskSpec(PlaceTaskType.align, 528946),
    PlaceTaskSpec(PlaceTaskType.identify, 528946, highlight: 2),
    PlaceTaskSpec(PlaceTaskType.identify, 673148, highlight: 1),
    PlaceTaskSpec(PlaceTaskType.identify, 304952, highlight: 3),
  ],
  <PlaceTaskSpec>[
    PlaceTaskSpec(PlaceTaskType.standard, 618392),
    PlaceTaskSpec(PlaceTaskType.standard, 304005),
    PlaceTaskSpec(PlaceTaskType.standard, 1000000),
  ],
  <PlaceTaskSpec>[
    PlaceTaskSpec(PlaceTaskType.expanded, 618392),
    PlaceTaskSpec(PlaceTaskType.expanded, 304952),
    PlaceTaskSpec(PlaceTaskType.reverse, 365479),
  ],
  <PlaceTaskSpec>[PlaceTaskSpec(PlaceTaskType.repeat, 442187)],
  <PlaceTaskSpec>[
    PlaceTaskSpec(PlaceTaskType.identify, 741265, highlight: 4),
    PlaceTaskSpec(PlaceTaskType.standard, 206015),
    PlaceTaskSpec(PlaceTaskType.expanded, 507030),
    PlaceTaskSpec(PlaceTaskType.repeat, 665201),
  ],
];

const Map<int, String> placeValueWords = <int, String>{
  618392: 'Six hundred eighteen thousand, three hundred ninety-two',
  304005: 'Three hundred four thousand, five',
  1000000: 'One million',
  206015: 'Two hundred six thousand, fifteen',
  528946: 'Five hundred twenty-eight thousand, nine hundred forty-six',
};

String placeFormat(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);

List<int> placeDigits(int number) =>
    number.toString().padLeft(7, '0').split('').map(int.parse).toList();

List<int> placePositions(int number) => List<int>.generate(
  number.toString().length,
  (int i) => 7 - number.toString().length + i,
);

List<int> placeExpandedTerms(int number, {bool includeZeros = true}) {
  final List<int> digits = placeDigits(number);
  return placePositions(number)
      .map((int column) => digits[column] * placeValueUnits[column])
      .where((int value) => includeZeros || value != 0)
      .toList();
}
