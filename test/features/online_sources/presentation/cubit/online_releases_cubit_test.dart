import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/online_sources/domain/entities/online_provider.dart';
import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';
import 'package:iris/features/online_sources/domain/repositories/online_sources_repository.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_cubit.dart';
import 'package:iris/features/online_sources/presentation/cubit/online_releases_state.dart';

const _release = OnlineRelease(
  provider: OnlineProvider.anilibria,
  id: '9542',
  title: 'Фрирен',
  dub: 'AniLibria',
  episodes: [],
);

void main() {
  Future<List<OnlineReleasesState>> load(_Sources sources) async {
    final cubit = OnlineReleasesCubit(
      shikimoriId: '52991',
      titles: const ['Frieren', 'Sousou no Frieren'],
      repository: sources,
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
    final sources = _Sources(const [_release]);

    expect(await load(sources), const [
      OnlineReleasesLoading(),
      OnlineReleasesLoaded([_release]),
    ]);
    expect(sources.asked, ['52991: Frieren, Sousou no Frieren']);
  });

  test('is empty when no server has the anime', () async {
    expect(await load(_Sources(const [])), const [
      OnlineReleasesLoading(),
      OnlineReleasesEmpty(),
    ]);
  });

  test('fails when the search fails', () async {
    expect(await load(_Sources(const [], fail: true)), const [
      OnlineReleasesLoading(),
      OnlineReleasesFailure(),
    ]);
  });
}

class _Sources implements OnlineSourcesRepository {
  _Sources(this.releases, {this.fail = false});

  final List<OnlineRelease> releases;
  final bool fail;
  final asked = <String>[];

  @override
  Future<List<OnlineRelease>> findReleases({
    required String shikimoriId,
    required List<String> titles,
  }) async {
    asked.add('$shikimoriId: ${titles.join(', ')}');
    if (fail) throw StateError('offline');
    return releases;
  }

  @override
  Future<OnlineRelease> fetchRelease({
    required OnlineProvider provider,
    required String id,
  }) => throw UnimplementedError();

  @override
  Future<List<OnlineStream>> resolveStreams({
    required OnlineProvider provider,
    required String episodeId,
  }) => throw UnimplementedError();
}
