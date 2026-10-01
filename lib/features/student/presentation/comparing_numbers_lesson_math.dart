const List<String> _places = <String>[
  'Millions',
  'Hundred thousands',
  'Ten thousands',
  'Thousands',
  'Hundreds',
  'Tens',
  'Ones',
];

class ComparisonCase {
  const ComparisonCase(this.first, this.second);
  final int first;
  final int second;

  int get length =>
      first.toString().length > second.toString().length
          ? first.toString().length
          : second.toString().length;
  String get firstDigits => first.toString().padLeft(length, ' ');
  String get secondDigits => second.toString().padLeft(length, ' ');
  String place(int index) => _places[_places.length - length + index];

  int get decidingIndex {
    for (int i = 0; i < length; i++) {
      if (firstDigits[i] != secondDigits[i]) return i;
    }
    return -1;
  }

  String get symbol =>
      first > second
          ? '>'
          : first < second
          ? '<'
          : '=';

  String get explanation {
    if (first == second) return 'Every digit matches. The numbers are equal.';
    if (first.toString().length != second.toString().length) {
      return '${formatNumber(first)} has ${first.toString().length} digits. '
          '${formatNumber(second)} has ${second.toString().length} digits. '
          'The number with more digits is greater.';
    }
    final int i = decidingIndex;
    return 'At the ${place(i).toLowerCase()} place, ${firstDigits[i]} is '
        '${symbol == '>' ? 'greater' : 'less'} than ${secondDigits[i]}. '
        'This place decides the comparison.';
  }
}

String formatNumber(int value) {
  final String digits = value.toString();
  return digits.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (Match match) => ',',
  );
}
