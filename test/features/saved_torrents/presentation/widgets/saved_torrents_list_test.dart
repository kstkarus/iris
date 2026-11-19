import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/saved_torrents_list.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

import '../../../../helpers/test_app.dart';

const _magnet =
    'magnet:?xt=urn:btih:065c4691de84f964e143103b3bd0de17be5bfd0a'
    '&dn=Frieren%20BD';

void main() {
  testWidgets('smoothly transitions status height across watch states', (
    tester,
  ) async {
    final progressRepo = _MutableWatchProgressRepository();
    await _pumpList(tester, progressRepo);

    final unwatchedHeight = tester
        .getSize(find.byKey(const Key('saved_torrent_watch_button')))
        .height;
    expect(find.byType(SegmentedBar), findsNothing);

    progressRepo.emit([
      WatchProgress(
        torrentKey: torrentKeyFromMagnet(_magnet),
        fileIndex: 0,
        fileName: '03.mkv',
        magnet: _magnet,
        sourceTitle: 'Frieren BD',
        position: const Duration(minutes: 6),
        duration: const Duration(minutes: 24),
        updatedAt: DateTime.utc(2026, 10, 12),
      ),
    ]);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    final midHeight = tester
        .getSize(find.byKey(const Key('saved_torrent_watch_button')))
        .height;
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    final watchingHeight = tester
        .getSize(find.byKey(const Key('saved_torrent_watch_button')))
        .height;
    expect(find.byType(SegmentedBar), findsOneWidget);
    expect(watchingHeight, greaterThan(unwatchedHeight));
    expect(midHeight, greaterThanOrEqualTo(unwatchedHeight));
    expect(midHeight, lessThanOrEqualTo(watchingHeight));

    progressRepo.emit([
      WatchProgress(
        torrentKey: torrentKeyFromMagnet(_magnet),
        fileIndex: 0,
        fileName: '03.mkv',
        magnet: _magnet,
        sourceTitle: 'Frieren BD',
        position: const Duration(minutes: 24),
        duration: const Duration(minutes: 24),
        updatedAt: DateTime.utc(2026, 10, 12),
      ),
    ]);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(find.byType(SegmentedBar), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const Key('saved_torrent_watch_button')))
          .height,
      lessThan(watchingHeight),
    );
  });

  testWidgets('status mode swap completes immediately with reduced motion', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    final progressRepo = _MutableWatchProgressRepository();
    await _pumpList(tester, progressRepo);

    progressRepo.emit([
      WatchProgress(
        torrentKey: torrentKeyFromMagnet(_magnet),
        fileIndex: 0,
        fileName: '03.mkv',
        magnet: _magnet,
        sourceTitle: 'Frieren BD',
        position: const Duration(minutes: 6),
        duration: const Duration(minutes: 24),
        updatedAt: DateTime.utc(2026, 10, 12),
      ),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.byType(SegmentedBar), findsOneWidget);
  });
}

Future<void> _pumpList(
  WidgetTester tester,
  _MutableWatchProgressRepository progressRepo,
) async {
  final saved = SavedTorrentsCubit(
    animeId: '52991',
    repository: _FakeSavedTorrentsRepository(),
  )..load();
  final history = WatchProgressCubit(repository: progressRepo)..load();
  addTearDown(progressRepo.close);
  addTearDown(saved.close);
  addTearDown(history.close);

  await tester.pumpWidget(
    testApp(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: saved),
          BlocProvider.value(value: history),
        ],
        child: Scaffold(
          body: SavedTorrentsList(
            onWatch: (torrent, {autoOpenFileIndex}) {},
            onDownload: (torrent) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 100),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

class _MutableWatchProgressRepository implements WatchProgressRepository {
  late final StreamController<List<WatchProgress>> _controller =
      StreamController<List<WatchProgress>>.broadcast(
        onListen: () => _controller.add(const []),
      );

  void emit(List<WatchProgress> items) => _controller.add(items);

  Future<void> close() => _controller.close();

  @override
  Stream<List<WatchProgress>> watchAll() => _controller.stream;

  @override
  Future<WatchProgress?> find({
    required String torrentKey,
    required int fileIndex,
  }) async => null;

  @override
  Future<void> save(WatchProgress progress) async {}

  @override
  Future<void> dismissFromContinueWatching(WatchProgress progress) async {}

  @override
  Future<void> removeTorrent({required String torrentKey}) async {}
}

class _FakeSavedTorrentsRepository implements SavedTorrentsRepository {
  @override
  Stream<List<SavedTorrent>> watchTorrents(String animeId) => Stream.value([
    SavedTorrent(
      animeId: animeId,
      infoHash: torrentKeyFromMagnet(_magnet),
      magnet: _magnet,
      title: 'Frieren BD',
      addedAt: DateTime.utc(2026, 10, 12),
    ),
  ]);

  @override
  Future<SaveTorrentResult> add({
    required String animeId,
    required String magnet,
  }) => throw UnimplementedError();

  @override
  Future<void> rename(SavedTorrent torrent, String title) async {}

  @override
  Future<void> markOpened(SavedTorrent torrent) async {}

  @override
  Future<void> delete(SavedTorrent torrent) async {}

  @override
  Future<void> restore(SavedTorrent torrent) async {}
}
