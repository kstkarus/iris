import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/entities/watch_progress/data/shared_preferences_watch_progress_repository.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';

WatchProgress _progress({
  String torrentKey = 'abc',
  int fileIndex = 0,
  int positionSeconds = 120,
  int durationSeconds = 1440,
  int minute = 0,
  String animeId = '',
}) {
  return WatchProgress(
    torrentKey: torrentKey,
    fileIndex: fileIndex,
    fileName: 'Episode ${fileIndex + 1}.mkv',
    magnet: 'magnet:?xt=urn:btih:$torrentKey',
    sourceTitle: 'Release $torrentKey',
    position: Duration(seconds: positionSeconds),
    duration: Duration(seconds: durationSeconds),
    updatedAt: DateTime.utc(2026, 10, 4, 12, minute),
    animeId: animeId,
    animeTitle: animeId.isEmpty ? '' : 'Anime $animeId',
  );
}

void main() {
  late SharedPreferences preferences;
  late SharedPreferencesWatchProgressRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = SharedPreferencesWatchProgressRepository(preferences);
  });

  tearDown(() => repository.close());

  test('saves, replaces and finds a file record', () async {
    await repository.save(_progress(positionSeconds: 60));
    await repository.save(_progress(positionSeconds: 300, minute: 1));

    final found = await repository.find(torrentKey: 'abc', fileIndex: 0);
    expect(found?.position, const Duration(seconds: 300));
    expect(await repository.watchAll().first, hasLength(1));
    expect(await repository.find(torrentKey: 'abc', fileIndex: 1), isNull);
  });

  test('lists the most recent first and persists across instances', () async {
    await repository.save(_progress(fileIndex: 0, minute: 1));
    await repository.save(
      _progress(torrentKey: 'def', minute: 3, animeId: '42'),
    );
    await repository.save(_progress(fileIndex: 1, minute: 2));

    final reopened = SharedPreferencesWatchProgressRepository(preferences);
    addTearDown(reopened.close);
    final items = await reopened.watchAll().first;

    expect(items.map((item) => item.id), ['def:0', 'abc:1', 'abc:0']);
    expect(items.first.animeTitle, 'Anime 42');
    expect(items.first.duration, const Duration(seconds: 1440));
  });

  test('removes every record of a torrent and notifies watchers', () async {
    await repository.save(_progress(fileIndex: 0));
    await repository.save(_progress(fileIndex: 1));
    await repository.save(_progress(torrentKey: 'def'));
    final emissions = repository.watchAll().take(2).toList();
    await Future<void>.delayed(Duration.zero);

    await repository.removeTorrent(torrentKey: 'abc');

    final lists = await emissions;
    expect(lists.last.map((item) => item.torrentKey), ['def']);
  });

  test('drops the oldest records beyond the limit', () async {
    final limited = SharedPreferencesWatchProgressRepository(
      preferences,
      maxEntries: 2,
    );
    addTearDown(limited.close);

    for (var minute = 0; minute < 3; minute++) {
      await limited.save(_progress(fileIndex: minute, minute: minute));
    }

    final items = await limited.watchAll().first;
    expect(items.map((item) => item.fileIndex), [2, 1]);
  });

  test('survives corrupted storage and skips malformed entries', () async {
    await preferences.setString('watch_progress.items', '{oops');
    final corrupted = SharedPreferencesWatchProgressRepository(preferences);
    addTearDown(corrupted.close);
    expect(await corrupted.watchAll().first, isEmpty);

    await preferences.setString(
      'watch_progress.items',
      '[{"torrentKey":"abc","fileIndex":0,"positionMs":1000,'
          '"durationMs":2000,"updatedAt":"2026-10-04T12:00:00.000Z"},'
          '{"torrentKey":1}]',
    );
    final partial = SharedPreferencesWatchProgressRepository(preferences);
    addTearDown(partial.close);
    final items = await partial.watchAll().first;
    expect(items.single.fileName, '');
    expect(items.single.fraction, 0.5);
  });

  group('WatchProgress', () {
    test('counts the last tenth as watched and resumes only midway', () {
      expect(_progress(positionSeconds: 5).resumePosition, isNull);
      expect(
        _progress(positionSeconds: 600).resumePosition,
        const Duration(seconds: 600),
      );
      final finished = _progress(positionSeconds: 1300);
      expect(finished.isFinished, isTrue);
      expect(finished.resumePosition, isNull);
      expect(
        _progress(positionSeconds: 0, durationSeconds: 0).isFinished,
        isFalse,
      );
    });

    test('latestPerTorrent keeps the newest record of each torrent', () {
      final latest = latestPerTorrent([
        _progress(fileIndex: 0, minute: 1),
        _progress(fileIndex: 1, minute: 5),
        _progress(torrentKey: 'def', minute: 3),
      ]);
      expect(latest.map((item) => item.id), ['abc:1', 'def:0']);
    });
  });
}
