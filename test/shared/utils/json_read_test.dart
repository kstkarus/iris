import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/json_read.dart';

void main() {
  test('jsonMap falls back to an empty map', () {
    expect(jsonMap({'a': 1}), {'a': 1});
    expect(jsonMap('a'), isEmpty);
    expect(jsonMap(null), isEmpty);
  });

  test('jsonString falls back to an empty string', () {
    expect(jsonString('a'), 'a');
    expect(jsonString(1), '');
    expect(jsonString(null), '');
  });

  test('jsonNum and jsonInt fall back to zero', () {
    expect(jsonNum(8.5), 8.5);
    expect(jsonNum('8'), 0);
    expect(jsonInt(12), 12);
    expect(jsonInt(12.9), 12);
    expect(jsonInt('12'), 0);
    expect(jsonInt(null), 0);
  });

  test('jsonIntOrNull also reads strings', () {
    expect(jsonIntOrNull(12), 12);
    expect(jsonIntOrNull(12.9), 12);
    expect(jsonIntOrNull('12'), 12);
    expect(jsonIntOrNull('x'), isNull);
    expect(jsonIntOrNull(null), isNull);
  });
}
