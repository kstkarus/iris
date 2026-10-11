import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/data/repositories/combined_online_sources_repository.dart';
import 'package:iris/features/online_sources/domain/entities/online_episode.dart';
import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';

OnlineRelease _release(OnlineProvider provider, String id, String dub) =>
    OnlineRelease(provider: provider, id: id, dub: dub, episodes: const []);

void main() {
  final anilibria = _Provider([
    _release(OnlineProvider.anilibria, '9542', 'AniLibria'),
  ]);
  final yummy = _Provider([
    _release(OnlineProvider.yummyAnime, '10661:a', 'AniLibria'),
    _release(OnlineProvider.yummyAnime, '10661:b', 'AniDUB'),
  ]);

  CombinedOnlineSourcesRepository combined(_Provider first, _Provider second) =>
      CombinedOnlineSourcesRepository(
        providers: {
          OnlineProvider.anilibria: first,
          OnlineProvider.yummyAnime: second,
        },
      );

  test('an earlier provider dub hides the same dub of a later one', () async {
    final releases = await combined(
      anilibria,
      yummy,
    ).findReleases(shikimoriId: '52991', titles: const ['Frieren']);

    expect(
      [for (final r in releases) (r.provider, r.dub)],
      [
        (OnlineProvider.anilibria, 'AniLibria'),
        (OnlineProvider.yummyAnime, 'AniDUB'),
      ],
    );
  });

  test('a copy with more episodes wins over one cut short', () async {
    const episode = OnlineEpisode(id: 'e', number: 1);
    final releases = await combined(
      _Provider([_release(OnlineProvider.anilibria, '9542', 'AniLibria')]),
      _Provider([
        OnlineRelease(
          provider: OnlineProvider.yummyAnime,
          id: '10661:a',
          dub: 'AniLibria',
          episodes: const [episode],
        ),
        _release(OnlineProvider.yummyAnime, '10661:b', 'AniDUB'),
      ]),
    ).findReleases(shikimoriId: '52991', titles: const ['Frieren']);

    expect(
      [for (final r in releases) (r.provider, r.dub)],
      [
        (OnlineProvider.yummyAnime, 'AniLibria'),
        (OnlineProvider.yummyAnime, 'AniDUB'),
      ],
    );
  });

  test('a provider that fails does not hide the others', () async {
    final releases = await combined(
      _Provider.failing(),
      yummy,
    ).findReleases(shikimoriId: '52991', titles: const ['Frieren']);

    expect(releases, hasLength(2));
  });

  test('fails when nothing was found and a provider failed', () {
    expect(
      combined(
        _Provider.failing(),
        _Provider(const []),
      ).findReleases(shikimoriId: '52991', titles: const ['Frieren']),
      throwsA(isA<NetworkRequestException>()),
    );
  });

  test('shows a fast provider before a slow one answers', () async {
    final slow = _Provider.slow();
    final found = <List<String>>[];
    final done = Completer<void>();
    combined(slow, yummy)
        .watchReleases(shikimoriId: '52991', titles: const ['Frieren'])
        .listen(
          (releases) => found.add([for (final r in releases) r.id]),
          onDone: done.complete,
        );
    await pumpEventQueue();
    expect(found, [
      ['10661:a', '10661:b'],
    ]);

    slow.answer.complete(anilibria.releases);
    await done.future;
    // Merged in the providers' order, whichever answered first.
    expect(found.last, ['9542', '10661:b']);
  });

  test('a provider with nothing adds no step', () async {
    final found = await combined(
      _Provider(const []),
      yummy,
    ).watchReleases(shikimoriId: '52991', titles: const ['Frieren']).toList();

    expect(found, hasLength(1));
  });

  test('the search fails only after every provider answered', () async {
    final slow = _Provider.slow();
    final events = <Object>[];
    final done = Completer<void>();
    combined(_Provider.failing(), slow)
        .watchReleases(shikimoriId: '52991', titles: const ['Frieren'])
        .listen(events.add, onError: events.add, onDone: done.complete);
    await pumpEventQueue();
    expect(events, isEmpty);

    slow.answer.complete(const []);
    await done.future;
    expect(events.single, isA<NetworkRequestException>());
  });

  test('asks the release provider for releases and streams', () async {
    final repository = combined(anilibria, yummy);

    await repository.fetchRelease(
      provider: OnlineProvider.yummyAnime,
      id: '10661:b',
    );
    await repository.resolveStreams(
      provider: OnlineProvider.anilibria,
      episodeId: 'e1',
    );

    expect(yummy.calls, ['release 10661:b']);
    expect(anilibria.calls, ['streams e1']);
  });

  test('a provider that is not set up has nothing', () {
    expect(
      CombinedOnlineSourcesRepository(
        providers: {OnlineProvider.anilibria: anilibria},
      ).fetchRelease(provider: OnlineProvider.yummyAnime, id: '1'),
      throwsA(isA<ResourceNotFoundException>()),
    );
  });
}

class _Provider implements OnlineSourcesRepository {
  _Provider(this.releases) : fails = false;

  _Provider.failing() : releases = const [], fails = true;

  /// Answers when [answer] completes.
  _Provider.slow() : releases = const [], fails = false, slowAnswer = true;

  final List<OnlineRelease> releases;
  final bool fails;
  bool slowAnswer = false;
  final answer = Completer<List<OnlineRelease>>();
  final calls = <String>[];

  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) async {
    if (fails) throw const NetworkRequestException('offline');
    if (slowAnswer) return answer.future;
    return releases;
  }

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) async {
    calls.add('release $id');
    return releases.firstWhere((release) => release.id == id);
  }

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) async {
    calls.add('streams $episodeId');
    return const [];
  }
}
