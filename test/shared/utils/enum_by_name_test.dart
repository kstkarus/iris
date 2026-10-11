import 'package:flutter_test/flutter_test.dart';
import 'package:iris/shared/utils/enum_by_name.dart';

enum _Mode { first, second }

void main() {
  test('finds the value by its name', () {
    expect(enumByName(_Mode.values, 'second', _Mode.first), _Mode.second);
  });

  test('falls back on a missing or unknown name', () {
    expect(enumByName(_Mode.values, null, _Mode.second), _Mode.second);
    expect(enumByName(_Mode.values, 'third', _Mode.second), _Mode.second);
  });

  test('throws on a value that is not a string', () {
    expect(() => enumByName(_Mode.values, 1, _Mode.first), throwsA(anything));
  });
}
