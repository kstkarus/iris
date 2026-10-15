import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/downloads/presentation/pages/download_selection_page.dart';
import 'package:iris/shared/widgets/segmented_choice.dart';

import '../../../../helpers/memory_online_quality_preferences.dart';
import '../../../../helpers/test_app.dart';

const _online = DownloadSelectionArgs(
  animeId: '52991',
  animeTitle: 'Frieren',
  sourceTitle: 'AniLibria',
  magnet: 'online:anilibria/9542?anime=52991',
);

void main() {
  Future<MemoryOnlineQualityPreferences> pump(
    WidgetTester tester, {
    DownloadSelectionArgs args = _online,
    List<int> qualities = const [1080, 720, 480],
  }) async {
    final preferences = MemoryOnlineQualityPreferences(downloading: 720);
    await tester.pumpWidget(
      testApp(
        BlocProvider(
          create: (_) => DownloadSelectionCubit(
            args: args,
            repository: _EpisodesRepository(qualities),
            qualityPreferences: preferences,
          )..load(),
          child: DownloadSelectionPage(args: args, onWatch: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return preferences;
  }

  SegmentedChoice<int?> choice(WidgetTester tester) =>
      tester.widget<SegmentedChoice<int?>>(
        find.byKey(const Key('download_quality_choice')),
      );

  testWidgets('quality choices expose no tap action while a batch is queued', (
    tester,
  ) async {
    final repository = _GatedEpisodesRepository();
    final cubit = DownloadSelectionCubit(args: _online, repository: repository);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      testApp(
        BlocProvider(
          create: (_) => cubit..load(),
          child: DownloadSelectionPage(args: _online, onWatch: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final batch = cubit.downloadAll();
    await tester.pump();
    await tester.pump();
    try {
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('480p'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isFalse,
      );
    } finally {
      repository.gate.complete();
      await batch;
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('480p'))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
    }
  });

  testWidgets('a completed episode can be watched from the download picker', (
    tester,
  ) async {
    var watched = 0;
    await tester.pumpWidget(
      testApp(
        BlocProvider(
          create: (_) => DownloadSelectionCubit(
            args: _online,
            repository: MockDownloadsRepository(),
          )..load(),
          child: DownloadSelectionPage(
            args: _online,
            onWatch: (_) => watched++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('download_file_button_0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('download_file_watch_0')));
    expect(watched, 1);
  });

  testWidgets('an online release is downloaded by episode, in a quality '
      'chosen over the list', (tester) async {
    final preferences = await pump(tester);

    expect(find.text('Download episodes'), findsOneWidget);
    expect(find.text('Quality'), findsOneWidget);
    for (final label in ['Auto', '1080p', '720p', '480p']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(choice(tester).selected, 720);
    // An episode's size is not known before it loads.
    expect(find.text('0 B'), findsNothing);

    await tester.tap(find.text('480p'));
    await tester.pump();
    expect(choice(tester).selected, 480);
    expect(preferences.downloading, 480);
  });

  testWidgets('episodes are queued one tap each, and the screen stays and '
      'shows how each goes', (tester) async {
    final repository = _LoadingRepository();
    await tester.pumpWidget(
      testApp(
        BlocProvider(
          create: (_) =>
              DownloadSelectionCubit(args: _online, repository: repository)
                ..load(),
          child: DownloadSelectionPage(args: _online, onWatch: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('download_file_button_1')));
    await tester.pumpAndSettle();
    expect(find.text('Download episodes'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('download_file_progress_1')),
      findsOneWidget,
    );
    expect(find.text('Queued'), findsOneWidget);

    await tester.tap(find.text('02'));
    await tester.pumpAndSettle();
    expect(repository.queued, [1, 2]);

    // Loading, its size not known yet: no share to tell.
    repository.load(2, 0);
    await tester.pumpAndSettle();
    expect(find.text('Downloading'), findsOneWidget);

    // An episode's size is a guess until it is done, and a guess outgrown
    // is not done.
    repository.load(1, 0.42);
    await tester.pumpAndSettle();
    expect(find.text('~100.0 MB · Downloading · 42%'), findsOneWidget);
    repository.load(1, 1.2, done: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Downloading · 99%'), findsOneWidget);

    repository.load(1, 1);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('download_file_watch_1')), findsOneWidget);
    expect(find.text('100.0 MB · Done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a release whose qualities are unknown offers no choice', (
    tester,
  ) async {
    await pump(tester, qualities: const []);

    expect(find.text('01'), findsOneWidget);
    expect(find.text('Quality'), findsNothing);
  });
}

class _EpisodesRepository extends MockDownloadsRepository {
  _EpisodesRepository(this.qualities);

  final List<int> qualities;

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    return PreparedDownloadSource(
      sourceToken: 'online',
      files: const [
        DownloadableFile(index: 1, name: '01', relativePath: '', size: 0),
        DownloadableFile(index: 2, name: '02', relativePath: '', size: 0),
      ],
      qualities: qualities,
    );
  }
}

class _GatedEpisodesRepository extends _EpisodesRepository {
  _GatedEpisodesRepository() : super(const [1080, 720, 480]);
  final gate = Completer<void>();

  @override
  Stream<Map<int, DownloadItem>> watchSourceDownloads({
    required String magnet,
  }) => Stream.value(const {});

  @override
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
    String posterUrl = '',
    int? quality,
  }) async {
    await gate.future;
    return super.enqueueDownload(
      source: source,
      file: file,
      animeId: animeId,
      animeTitle: animeTitle,
      sourceTitle: sourceTitle,
      posterUrl: posterUrl,
      quality: quality,
    );
  }
}

/// Two episodes whose downloads a test moves along.
class _LoadingRepository extends _EpisodesRepository {
  _LoadingRepository() : super(const []);

  final queued = <int>[];
  final _downloads = <int, DownloadItem>{};
  final _changes = StreamController<Map<int, DownloadItem>>.broadcast();

  @override
  Stream<Map<int, DownloadItem>> watchSourceDownloads({
    required String magnet,
  }) async* {
    yield Map.of(_downloads);
    yield* _changes.stream;
  }

  @override
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
    String posterUrl = '',
    int? quality,
  }) async {
    queued.add(file.index);
    final item = DownloadItem(
      id: 'episode-${file.index}',
      animeId: animeId,
      animeTitle: animeTitle,
      posterUrl: posterUrl,
      sourceTitle: sourceTitle,
      magnet: _online.magnet,
      fileIndex: file.index,
      fileName: file.name,
      relativePath: '',
      localPath: '',
      totalBytes: 0,
      downloadedBytes: 0,
      downloadRateBytesPerSecond: 0,
      peers: 0,
      status: DownloadStatus.queued,
      createdAt: DateTime(2026),
    );
    _set(item);
    return item;
  }

  /// Episode [index] has loaded [share] of its 100 MB, or is loading with
  /// no size yet at 0; all of it is done unless [done] says otherwise.
  void load(int index, double share, {bool? done}) {
    const total = 100 * 1024 * 1024;
    _set(
      _downloads[index]!.copyWith(
        totalBytes: share == 0 ? 0 : total,
        downloadedBytes: (total * share).round(),
        status: done ?? share >= 1
            ? DownloadStatus.completed
            : DownloadStatus.downloading,
      ),
    );
  }

  void _set(DownloadItem item) {
    _downloads[item.fileIndex] = item;
    _changes.add(Map.of(_downloads));
  }
}
