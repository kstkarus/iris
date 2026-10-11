import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/search_all.dart';

void main() {
  Future<List<int>> search(String query) async => switch (query) {
    'odd' => [1, 3],
    'even' => [2, 4],
    'down' => throw StateError('down'),
    _ => throw ArgumentError(query),
  };

  test('returns what every query found and kept, in query order', () async {
    expect(await searchAll(['odd', 'even'], search, keep: (item) => item > 1), [
      3,
      2,
      4,
    ]);
  });

  test('a failed query does not hide what the others kept', () async {
    expect(await searchAll(['down', 'odd'], search, keep: (_) => true), [1, 3]);
  });

  test('throws the first failure when nothing was kept', () async {
    await expectLater(
      searchAll(['odd', 'down', 'other'], search, keep: (item) => item > 5),
      throwsA(isA<StateError>()),
    );
  });

  test('nothing kept and nothing failed is just nothing', () async {
    expect(await searchAll(['odd'], search, keep: (item) => item > 5), isEmpty);
  });
}
