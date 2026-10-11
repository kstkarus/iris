import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/shared/storage/json_list_preference.dart';

void main() {
  Future<JsonListPreference<int>> preference(String? stored) async {
    SharedPreferences.setMockInitialValues({'numbers': ?stored});
    return JsonListPreference<int>(
      await SharedPreferences.getInstance(),
      'numbers',
      decode: (json) =>
          json is Map && json['n'] is int ? json['n'] as int : null,
      encode: (n) => {'n': n},
      logName: 'test',
      corruptedMessage: 'corrupted',
    );
  }

  test('reads nothing when nothing is stored', () async {
    expect((await preference(null)).read(), isEmpty);
  });

  test('skips entries that do not decode', () async {
    final numbers = await preference('[{"n":1},{"n":"x"},2,{"n":3}]');

    expect(numbers.read(), [1, 3]);
  });

  test('reads storage that is not a JSON list as empty', () async {
    expect((await preference('{"n":1}')).read(), isEmpty);
    expect((await preference('not json')).read(), isEmpty);
  });

  test('writes one JSON array', () async {
    final numbers = await preference(null);

    await numbers.write([4, 5]);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('numbers'), '[{"n":4},{"n":5}]');
    expect(numbers.read(), [4, 5]);
  });
}
