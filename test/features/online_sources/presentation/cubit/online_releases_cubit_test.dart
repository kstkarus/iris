import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/repositories/online_releases_search.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';

const _release = OnlineRelease(
  provider: OnlineProvider.anilibria,
  id: '9542',
  dub: 'AniLibria',
  episodes: [],
);

const _dub = OnlineRelease(
  provider: OnlineProvider.yummyAnime,
  id: '10661:AniDUB',
  dub: 'AniDUB',
  episodes: [],
);

void main() {
  Future<List<OnlineReleasesState>> load(_Search search) async {
    final cubit = OnlineReleasesCubit(
      shikimoriId: '52991',
      titles: const ['Frieren', 'Sousou no Frieren'],
      search: search,
    );
    final states = <OnlineReleasesState>[];
    final subscription = cubit.stream.listen(states.add);
    await cubit.load();
    // The stream delivers the last state a microtask later.
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    await cubit.close();
    return states;
  }

  test('looks the anime up by its id and titles', () async {
    final search = _Search(const [
      [_release],
    ]);

    expect(await load(search), const [
      OnlineReleasesLoading(),
      OnlineReleasesLoaded([_release], searching: true),
      OnlineReleasesLoaded([_release]),
    ]);
    expect(search.asked, ['52991: Frieren, Sousou no Frieren']);
  });

  test('shows each server as it answers', () async {
    expect(
      await load(
        _Search(const [
          [_release],
          [_release, _dub],
        ]),
      ),
      const [
        OnlineReleasesLoading(),
        OnlineReleasesLoaded([_release], searching: true),
        OnlineReleasesLoaded([_release, _dub], searching: true),
        OnlineReleasesLoaded([_release, _dub]),
      ],
    );
  });

  test('is empty when no server has the anime', () async {
    expect(await load(_Search(const [])), const [
      OnlineReleasesLoading(),
      OnlineReleasesEmpty(),
    ]);
  });

  test('fails when the search fails', () async {
    expect(await load(_Search(const [], fail: true)), const [
      OnlineReleasesLoading(),
      OnlineReleasesFailure(),
    ]);
  });
}

class _Search implements OnlineReleasesSearch {
  _Search(this.answers, {this.fail = false});

  /// What the search gives, step by step.
  final List<List<OnlineRelease>> answers;
  final bool fail;
  final asked = <String>[];

  @override
  Stream<List<OnlineRelease>> watchReleases({
    required String shikimoriId,
    required List<String> titles,
  }) async* {
    asked.add('$shikimoriId: ${titles.join(', ')}');
    if (fail) throw StateError('offline');
    yield* Stream.fromIterable(answers);
  }
}
