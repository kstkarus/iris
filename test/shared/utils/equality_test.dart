import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/equality.dart';

void main() {
  test('sameList compares elements in order', () {
    expect(sameList([1, 2], [1, 2]), isTrue);
    expect(sameList([1, 2], [2, 1]), isFalse);
    expect(sameList([1], [1, 2]), isFalse);
    expect(sameList(<int>[], <int>[]), isTrue);
  });

  test('sameSet ignores order', () {
    expect(sameSet({1, 2}, {2, 1}), isTrue);
    expect(sameSet({1, 2}, {1, 3}), isFalse);
    expect(sameSet({1}, {1, 2}), isFalse);
  });

  test('sameMap compares keys and values', () {
    expect(sameMap({'a': '1', 'b': '2'}, {'b': '2', 'a': '1'}), isTrue);
    expect(sameMap({'a': '1'}, {'a': '2'}), isFalse);
    expect(sameMap({'a': '1'}, {'b': '1'}), isFalse);
    expect(sameMap<String, String?>({'a': null}, {'b': null}), isFalse);
    expect(sameMap({'a': '1'}, {'a': '1', 'b': '2'}), isFalse);
  });
}
