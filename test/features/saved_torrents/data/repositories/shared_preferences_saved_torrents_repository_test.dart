import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/saved_torrents/data/repositories/shared_preferences_saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';

const _anime = '1535';
const _other = '5114';
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

  Future<SaveTorrentResult> add(String magnet, {String anime = _anime}) =>
      repository.add(animeId: anime, magnet: magnet);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    now = DateTime.utc(2026, 10, 4, 12);
    repository = create();
  });

  tearDown(() => repository.close());

  test('adds a magnet to the anime and names it after dn', () async {
    final result = await add(_magnetA);

    expect(result, isA<SaveTorrentAdded>());
    final torrents = await repository.watchTorrents(_anime).first;
    expect(torrents.single.animeId, _anime);
    expect(torrents.single.infoHash, _hashA);
    expect(torrents.single.title, 'Death Note');
    expect(torrents.single.addedAt, now);
  });

  test('a link without a name goes by its hash', () async {
    await add(_magnetB);

    expect((await repository.watchTorrents(_anime).first).single.title, _hashB);
  });

  test('each anime has its own torrents, the same one in several', () async {
    await add(_magnetA);
    await add(_magnetB, anime: _other);

    expect(
      await add(_magnetA, anime: _other),
      isA<SaveTorrentAdded>(),
      reason: 'the user may add any torrent to any anime',
    );
    expect(
      (await repository.watchTorrents(_anime).first).map((t) => t.infoHash),
      [_hashA],
    );
    expect(
      (await repository.watchTorrents(_other).first).map((t) => t.infoHash),
      unorderedEquals([_hashA, _hashB]),
    );
  });

  test('rejects invalid links and keeps nothing', () async {
    final result = await add('https://example.com');

    expect(result, isA<SaveTorrentInvalidMagnet>());
    expect(await repository.watchTorrents(_anime).first, isEmpty);
  });

  test(
    'detects duplicates by info-hash regardless of trackers or case',
    () async {
      await add(_magnetA);

      final result = await add(
        'magnet:?xt=urn:btih:${_hashA.toUpperCase()}&tr=udp%3A%2F%2Fx',
      );

      expect(result, isA<SaveTorrentDuplicate>());
      expect((result as SaveTorrentDuplicate).existing.title, 'Death Note');
      expect(await repository.watchTorrents(_anime).first, hasLength(1));
    },
  );

  test('lists the most recently used torrent first', () async {
    await add(_magnetA);
    now = now.add(const Duration(minutes: 1));
    await add(_magnetB);
    var torrents = await repository.watchTorrents(_anime).first;
    expect(torrents.map((t) => t.infoHash), [_hashB, _hashA]);

    now = now.add(const Duration(minutes: 1));
    await repository.markOpened(torrents.last);

    torrents = await repository.watchTorrents(_anime).first;
    expect(torrents.map((t) => t.infoHash), [_hashA, _hashB]);
    expect(torrents.first.lastOpenedAt, now);
  });

  test('puts back a deleted torrent as it was', () async {
    await add(_magnetA);
    final saved = (await repository.watchTorrents(_anime).first).single;
    await repository.delete(saved);

    await repository.restore(saved);
    await repository.restore(saved);

    expect(await repository.watchTorrents(_anime).first, [saved]);
  });

  test('renames, ignores blank names and deletes', () async {
    await add(_magnetA);
    await add(_magnetA, anime: _other);
    final saved = (await repository.watchTorrents(_anime).first).single;

    await repository.rename(saved, 'Renamed');
    await repository.rename(saved, '  ');
    expect(
      (await repository.watchTorrents(_anime).first).single.title,
      'Renamed',
    );

    await repository.delete(saved);
    expect(await repository.watchTorrents(_anime).first, isEmpty);
    expect(
      (await repository.watchTorrents(_other).first).single.title,
      'Death Note',
      reason: 'the other anime keeps its copy',
    );
  });

  test('persists across repository instances', () async {
    await add(_magnetA);

    final reopened = create();
    addTearDown(reopened.close);

    final torrents = await reopened.watchTorrents(_anime).first;
    expect(torrents.single.magnet, _magnetA);
  });

  test("emits changes to the anime's watchers", () async {
    final emissions = repository.watchTorrents(_anime).take(2).toList();
    await Future<void>.delayed(Duration.zero);

    await add(_magnetA);

    final lists = await emissions;
    expect(lists.first, isEmpty);
    expect(lists.last.single.infoHash, _hashA);
  });

  test('survives corrupted storage and skips malformed entries', () async {
    await preferences.setString('saved_torrents.items', '{not json');
    expect(await repository.watchTorrents(_anime).first, isEmpty);

    await preferences.setString(
      'saved_torrents.items',
      '[{"animeId":"$_anime","infoHash":"$_hashA","magnet":"$_magnetA",'
          '"title":"Ok","addedAt":"2026-10-04T12:00:00.000Z"},{"oops":1}]',
    );
    final torrents = await repository.watchTorrents(_anime).first;
    expect(torrents.single.title, 'Ok');
  });

  test('lets go of torrents saved before they belonged to an anime', () async {
    await preferences.setString(
      'saved_torrents.items',
      '[{"infoHash":"$_hashA","magnet":"$_magnetA","title":"Old",'
          '"addedAt":"2026-10-04T12:00:00.000Z"}]',
    );

    expect(await add(_magnetA), isA<SaveTorrentAdded>());
    final stored = jsonDecode(preferences.getString('saved_torrents.items')!);
    expect((stored as List).single['animeId'], _anime);
  });

  group('torrents saved before hex and base32 were unified', () {
    const base32A = 'azoeneo6qt4wjykdca5txug6c67fx7ik';
    const base32MagnetA =
        'magnet:?xt=urn:btih:AZOENEO6QT4WJYKDCA5TXUG6C67FX7IK';

    Map<String, Object?> stored(String infoHash, String magnet, int day) => {
      'animeId': _anime,
      'infoHash': infoHash,
      'magnet': magnet,
      'title': 'Saved $day',
      'addedAt': DateTime.utc(2026, 9, day).toIso8601String(),
    };

    Future<void> storeRaw(List<Map<String, Object?>> items) async {
      SharedPreferences.setMockInitialValues({
        'saved_torrents.items': jsonEncode(items),
      });
      preferences = await SharedPreferences.getInstance();
      await repository.close();
      repository = create();
    }

    test('read with the hex key, so the same magnet is a duplicate', () async {
      await storeRaw([stored(base32A, base32MagnetA, 1)]);

      final torrents = await repository.watchTorrents(_anime).first;
      expect(torrents.single.infoHash, _hashA);
      expect(await add(base32MagnetA), isA<SaveTorrentDuplicate>());
      expect(await add(_magnetA), isA<SaveTorrentDuplicate>());
    });

    test('both spellings of one torrent show once, the first added', () async {
      await storeRaw([
        stored(base32A, base32MagnetA, 1),
        stored(_hashA, _magnetA, 2),
      ]);

      final torrents = await repository.watchTorrents(_anime).first;
      expect(torrents.single.title, 'Saved 1');
    });
  });
}
