import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/player/data/utils/stored_json.dart';

void main() {
  Future<String> read(Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
    final preferences = await SharedPreferences.getInstance();
    return readStoredJson(
      preferences,
      'key',
      fromJson: (json) => json['name'] as String,
      fallback: 'fallback',
    );
  }

  test('reads a stored object', () async {
    expect(await read({'key': '{"name":"saved"}'}), 'saved');
  });

  test('falls back when nothing or an empty string is stored', () async {
    expect(await read({}), 'fallback');
    expect(await read({'key': ''}), 'fallback');
  });

  test(
    'falls back on invalid JSON, a non-object, or a failing parse',
    () async {
      expect(await read({'key': '{'}), 'fallback');
      expect(await read({'key': '[1]'}), 'fallback');
      expect(await read({'key': '{"name":1}'}), 'fallback');
    },
  );

  test('writes what it reads back', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    await writeStoredJson(preferences, 'key', {'name': 'written'});

    expect(preferences.getString('key'), '{"name":"written"}');
  });
}
