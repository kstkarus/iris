import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/player/data/repositories/shared_preferences_track_preferences_repository.dart';
import 'package:iris/features/player/domain/entities/player_track_preferences.dart';

const _hex = '065c4691de84f964e143103b3bd0de17be5bfd0a';
const _base32 = 'azoeneo6qt4wjykdca5txug6c67fx7ik';

void main() {
  late SharedPreferences preferences;
  late SharedPreferencesTrackPreferencesRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = SharedPreferencesTrackPreferencesRepository(preferences);
  });

  const japanese = PlayerTrackPreferences(
    audio: PreferredTrack(language: 'jpn'),
  );

  test('loads what it saved', () async {
    await repository.save(torrentKey: _hex, preferences: japanese);

    final loaded = await repository.load(torrentKey: _hex);
    expect(loaded?.audio?.language, 'jpn');
  });

  test('finds a choice saved under the base32 key of the torrent', () async {
    await repository.save(torrentKey: _base32, preferences: japanese);

    final loaded = await repository.load(torrentKey: _hex);
    expect(loaded?.audio?.language, 'jpn');
  });

  test('does not take another torrent\'s choice', () async {
    await repository.save(torrentKey: _base32, preferences: japanese);

    expect(await repository.load(torrentKey: 'f' * 40), isNull);
  });
}
