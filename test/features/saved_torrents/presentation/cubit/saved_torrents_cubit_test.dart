import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/saved_torrents/data/repositories/shared_preferences_saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';

const _magnet =
    'magnet:?xt=urn:btih:065c4691de84f964e143103b3bd0de17be5bfd0a&dn=A';

const _highlight = Duration(seconds: 2);

/// Runs [body] against a loaded cubit whose highlight timer is on fake time.
void _withCubit(void Function(FakeAsync async, SavedTorrentsCubit cubit) body) {
  fakeAsync((async) {
    SharedPreferences.setMockInitialValues({});
    late SharedPreferencesSavedTorrentsRepository repository;
    late SavedTorrentsCubit cubit;
    SharedPreferences.getInstance().then((preferences) {
      repository = SharedPreferencesSavedTorrentsRepository(preferences);
      cubit = SavedTorrentsCubit(
        animeId: '1535',
        repository: repository,
        highlightDuration: _highlight,
      )..load();
    });
    async.flushMicrotasks();

    body(async, cubit);

    cubit.close();
    repository.close();
    async.flushMicrotasks();
  });
}

SaveTorrentResult? _add(FakeAsync async, SavedTorrentsCubit cubit, String m) {
  SaveTorrentResult? result;
  cubit.add(m).then((value) => result = value);
  async.flushMicrotasks();
  return result;
}

void main() {
  test('loads, highlights an added torrent and clears the highlight', () {
    _withCubit((async, cubit) {
      expect(cubit.state.isLoading, isFalse);

      expect(_add(async, cubit, _magnet), isA<SaveTorrentAdded>());
      expect(cubit.state.torrents, hasLength(1));
      expect(
        cubit.state.highlightedInfoHash,
        '065c4691de84f964e143103b3bd0de17be5bfd0a',
      );

      async.elapse(_highlight);
      expect(cubit.state.highlightedInfoHash, isNull);
    });
  });

  test('highlights the existing entry for a duplicate', () {
    _withCubit((async, cubit) {
      _add(async, cubit, _magnet);
      async.elapse(_highlight);
      expect(cubit.state.highlightedInfoHash, isNull);

      expect(_add(async, cubit, _magnet), isA<SaveTorrentDuplicate>());
      expect(cubit.state.highlightedInfoHash, isNotNull);
    });
  });

  test('does not highlight anything for an invalid link', () {
    _withCubit((async, cubit) {
      expect(
        _add(async, cubit, 'not a magnet'),
        isA<SaveTorrentInvalidMagnet>(),
      );
      expect(cubit.state.highlightedInfoHash, isNull);
    });
  });
}
