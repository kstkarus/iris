import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/utils/watched_first.dart';

void main() {
  test('watched items come first, each group in its own order', () {
    expect(watchedFirst([1, 2, 3, 4, 5], (item) => item.isEven), [
      2,
      4,
      1,
      3,
      5,
    ]);
  });
}
