import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/saved_torrents/data/repositories/shared_preferences_saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';

const _magnet =
    'magnet:?xt=urn:btih:065c4691de84f964e143103b3bd0de17be5bfd0a&dn=A';

void main() {
  late SharedPreferencesSavedTorrentsRepository repository;
  late SavedTorrentsCubit cubit;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SharedPreferencesSavedTorrentsRepository(
      await SharedPreferences.getInstance(),
    );
    cubit = SavedTorrentsCubit(
      repository: repository,
      highlightDuration: const Duration(milliseconds: 20),
    )..load();
  });

  tearDown(() async {
    await cubit.close();
    await repository.close();
  });

  test('loads, highlights an added torrent and clears the highlight', () async {
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isLoading, isFalse);

    final result = await cubit.add(magnet: _magnet);
    await Future<void>.delayed(Duration.zero);

    expect(result, isA<SaveTorrentAdded>());
    expect(cubit.state.torrents, hasLength(1));
    expect(
      cubit.state.highlightedInfoHash,
      '065c4691de84f964e143103b3bd0de17be5bfd0a',
    );

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(cubit.state.highlightedInfoHash, isNull);
  });

  test('highlights the existing entry for a duplicate', () async {
    await cubit.add(magnet: _magnet);
    await Future<void>.delayed(const Duration(milliseconds: 40));

    final result = await cubit.add(magnet: _magnet);

    expect(result, isA<SaveTorrentDuplicate>());
    expect(cubit.state.highlightedInfoHash, isNotNull);
  });

  test('does not highlight anything for an invalid link', () async {
    final result = await cubit.add(magnet: 'not a magnet');

    expect(result, isA<SaveTorrentInvalidMagnet>());
    expect(cubit.state.highlightedInfoHash, isNull);
  });
}
