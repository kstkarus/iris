import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';

import '../../../../helpers/memory_online_quality_preferences.dart';

const _args = DownloadSelectionArgs(
  animeId: '154587',
  animeTitle: 'Sousou no Frieren',
  sourceTitle: 'Release',
  magnet: 'magnet:?xt=urn:btih:test-selection',
);

void main() {
  test('closing during a preparation cancels it', () async {
    final repository = _DeferredPrepareRepository();
    final cubit = DownloadSelectionCubit(args: _args, repository: repository);

    unawaited(cubit.load());
    var isCancelled = false;
    unawaited(repository.cancellations.single!.then((_) => isCancelled = true));

    await cubit.close();
    await Future<void>.delayed(Duration.zero);

    expect(isCancelled, isTrue);
  });

  test('loading again cancels the preparation it replaces', () async {
    final repository = _DeferredPrepareRepository();
    final cubit = DownloadSelectionCubit(args: _args, repository: repository);

    unawaited(cubit.load());
    var firstCancelled = false;
    unawaited(
      repository.cancellations.single!.then((_) => firstCancelled = true),
    );

    unawaited(cubit.load());
    await Future<void>.delayed(Duration.zero);

    expect(firstCancelled, isTrue);
    expect(repository.cancellations, hasLength(2));
    await cubit.close();
  });

  group('an online release', () {
    const online = DownloadSelectionArgs(
      animeId: '52991',
      animeTitle: 'Frieren',
      sourceTitle: 'AniLibria',
      magnet: 'online:anilibria/9542?anime=52991',
    );

    Future<DownloadSelectionCubit> loaded(
      _QualityRepository repository,
      MemoryOnlineQualityPreferences preferences,
    ) async {
      final cubit = DownloadSelectionCubit(
        args: online,
        repository: repository,
        qualityPreferences: preferences,
      );
      addTearDown(cubit.close);
      await cubit.load();
      return cubit;
    }

    test('starts at the quality last chosen for downloads', () async {
      final cubit = await loaded(
        _QualityRepository(),
        MemoryOnlineQualityPreferences(downloading: 720, watching: 1080),
      );

      expect((cubit.state as DownloadSelectionReady).quality, 720);
    });

    test('starts at the closest quality the release has', () async {
      final cubit = await loaded(
        _QualityRepository(),
        MemoryOnlineQualityPreferences(downloading: 600),
      );

      expect((cubit.state as DownloadSelectionReady).quality, 480);
    });

    test('starts at Auto with no choice made yet', () async {
      final cubit = await loaded(
        _QualityRepository(),
        MemoryOnlineQualityPreferences(),
      );

      expect((cubit.state as DownloadSelectionReady).quality, isNull);
    });

    test('remembers a chosen quality and queues the episode in it', () async {
      final repository = _QualityRepository();
      final preferences = MemoryOnlineQualityPreferences(watching: 1080);
      final cubit = await loaded(repository, preferences);

      cubit.chooseQuality(480);
      await cubit.enqueue(_episode);

      expect(preferences.downloading, 480);
      expect(preferences.watching, 1080, reason: 'watching keeps its own');
      expect(repository.queuedQualities, [480]);
    });
  });
}

const _episode = DownloadableFile(
  index: 1,
  name: '01',
  relativePath: '',
  size: 0,
);

class _QualityRepository extends MockDownloadsRepository {
  final queuedQualities = <int?>[];

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    return const PreparedDownloadSource(
      sourceToken: 'online',
      files: [_episode],
      qualities: [1080, 720, 480],
    );
  }

  @override
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
    int? quality,
  }) {
    queuedQualities.add(quality);
    return super.enqueueDownload(
      source: source,
      file: file,
      animeId: animeId,
      animeTitle: animeTitle,
      sourceTitle: sourceTitle,
      quality: quality,
    );
  }
}

class _DeferredPrepareRepository extends MockDownloadsRepository {
  final List<Future<void>?> cancellations = [];

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    cancellations.add(cancelled);
    return Completer<PreparedDownloadSource>().future;
  }
}
