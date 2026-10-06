import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/saved_torrents/data/repositories/shared_preferences_saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';

const _hashA = '065c4691de84f964e143103b3bd0de17be5bfd0a';
const _hashB = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _magnetA = 'magnet:?xt=urn:btih:$_hashA&dn=Death%20Note';
const _magnetB = 'magnet:?xt=urn:btih:$_hashB';

void main() {
  late SharedPreferences preferences;
  late DateTime now;
  late SharedPreferencesSavedTorrentsRepository repository;

  SharedPreferencesSavedTorrentsRepository create() {
    return SharedPreferencesSavedTorrentsRepository(
      preferences,
      now: () => now,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 10, 4, 12);
    repository = create();
  });

  tearDown(() => repository.close());

  test('saves a magnet and names it after dn', () async {
    final result = await repository.add(magnet: _magnetA);

    expect(result, isA<SaveTorrentAdded>());
    final torrents = await repository.watchTorrents().first;
    expect(torrents.single.infoHash, _hashA);
    expect(torrents.single.title, 'Death Note');
    expect(torrents.single.addedAt, now);
  });

  test('prefers the user title and falls back to the hash', () async {
    await repository.add(magnet: _magnetA, title: '  Тетрадь  ');
    await repository.add(magnet: _magnetB, title: '   ');

    final titles = {
      for (final torrent in await repository.watchTorrents().first)
        torrent.infoHash: torrent.title,
    };
    expect(titles, {_hashA: 'Тетрадь', _hashB: _hashB});
  });

  test('rejects invalid links and keeps nothing', () async {
    final result = await repository.add(magnet: 'https://example.com');

    expect(result, isA<SaveTorrentInvalidMagnet>());
    expect(await repository.watchTorrents().first, isEmpty);
  });

  test(
    'detects duplicates by info-hash regardless of trackers or case',
    () async {
      await repository.add(magnet: _magnetA, title: 'First');

      final result = await repository.add(
        magnet: 'magnet:?xt=urn:btih:${_hashA.toUpperCase()}&tr=udp%3A%2F%2Fx',
        title: 'Second',
      );

      expect(result, isA<SaveTorrentDuplicate>());
      expect((result as SaveTorrentDuplicate).existing.title, 'First');
      expect(await repository.watchTorrents().first, hasLength(1));
    },
  );

  test('lists the most recently used torrent first', () async {
    await repository.add(magnet: _magnetA);
    now = now.add(const Duration(minutes: 1));
    await repository.add(magnet: _magnetB);
    expect((await repository.watchTorrents().first).map((t) => t.infoHash), [
      _hashB,
      _hashA,
    ]);

    now = now.add(const Duration(minutes: 1));
    await repository.markOpened(infoHash: _hashA);

    final torrents = await repository.watchTorrents().first;
    expect(torrents.map((t) => t.infoHash), [_hashA, _hashB]);
    expect(torrents.first.lastOpenedAt, now);
  });

  test('renames, ignores blank names and deletes', () async {
    await repository.add(magnet: _magnetA);

    await repository.rename(infoHash: _hashA, title: 'Renamed');
    await repository.rename(infoHash: _hashA, title: '  ');
    expect((await repository.watchTorrents().first).single.title, 'Renamed');

    await repository.delete(infoHash: _hashA);
    expect(await repository.watchTorrents().first, isEmpty);
  });

  test('persists across repository instances', () async {
    await repository.add(magnet: _magnetA, title: 'Kept');

    final reopened = create();
    addTearDown(reopened.close);

    final torrents = await reopened.watchTorrents().first;
    expect(torrents.single.title, 'Kept');
    expect(torrents.single.magnet, _magnetA);
  });

  test('emits changes to watchers', () async {
    final emissions = repository.watchTorrents().take(2).toList();
    await Future<void>.delayed(Duration.zero);

    await repository.add(magnet: _magnetA);

    final lists = await emissions;
    expect(lists.first, isEmpty);
    expect(lists.last.single.infoHash, _hashA);
  });

  test('survives corrupted storage and skips malformed entries', () async {
    await preferences.setString('saved_torrents.items', '{not json');
    expect(await repository.watchTorrents().first, isEmpty);

    await preferences.setString(
      'saved_torrents.items',
      '[{"infoHash":"$_hashA","magnet":"$_magnetA","title":"Ok",'
          '"addedAt":"2026-10-04T12:00:00.000Z"},{"oops":1}]',
    );
    final torrents = await repository.watchTorrents().first;
    expect(torrents.single.title, 'Ok');
  });
}
