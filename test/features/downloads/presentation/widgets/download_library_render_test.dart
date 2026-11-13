import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/router/app_shell_page.dart';
import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/pages/download_manager_page.dart';
import 'package:iris/features/downloads/presentation/pages/download_title_page.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/downloads/presentation/pages/download_selection_page.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/shared/online/online_source_link.dart';
import '../../../../helpers/fake_watch_progress_repository.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/features/downloads/presentation/pages/download_queue_page.dart';

TextScaler _textScaler = TextScaler.noScaling;

const _mb = 1024 * 1024;

Future<void> _loadFonts() async {
  final mono = FontLoader('Medeo Mono')
    ..addFont(rootBundle.load('assets/fonts/MedeoMono-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/MedeoMono-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/MedeoMono-SemiBold.ttf'));
  final sans = FontLoader('Medeo Sans')
    ..addFont(rootBundle.load('assets/fonts/MedeoSans-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/MedeoSans-Medium.ttf'));
  await Future.wait([mono.load(), sans.load()]);
}

final _now = DateTime(2026, 10, 10, 20);

DownloadItem _item(
  int id,
  String anime,
  String file, {
  required DownloadStatus status,
  required int total,
  int? done,
  int rate = 0,
  int peers = 0,
  String? error,
}) => DownloadItem(
  id: 'd$id',
  animeId: anime == 'Cowboy Bebop 1998 BDRemux' ? '' : anime,
  animeTitle: anime,
  sourceTitle: '[SubsPlease] $anime · 1080p',
  magnet: 'magnet:?dn=$anime',
  fileIndex: id,
  fileName: file,
  relativePath: file,
  localPath: '/data/$file',
  totalBytes: total,
  downloadedBytes: done ?? total,
  downloadRateBytesPerSecond: rate,
  peers: peers,
  status: status,
  errorMessage: error,
  createdAt: _now.subtract(Duration(hours: id)),
  completedAt: status == DownloadStatus.completed
      ? _now.subtract(Duration(hours: id))
      : null,
);

final _downloads = [
  _item(
    8,
    'Sousou no Frieren 2nd Season',
    'Frieren - 04.mkv',
    status: DownloadStatus.completed,
    total: 1200 * _mb,
  ),
  _item(
    9,
    'Sousou no Frieren 2nd Season',
    'Frieren - 05.mkv',
    status: DownloadStatus.completed,
    total: 1250 * _mb,
  ),
  _item(
    1,
    'Sousou no Frieren 2nd Season',
    '[SubsPlease] Sousou no Frieren S2 - 06 (1080p) [5E2B1C9A].mkv',
    status: DownloadStatus.downloading,
    total: 1420 * _mb,
    done: 612 * _mb,
    rate: 4 * _mb + 300 * 1024,
    peers: 18,
  ),
  _item(
    2,
    'Sousou no Frieren 2nd Season',
    '[SubsPlease] Sousou no Frieren S2 - 07 (1080p) [9C0D2F11].mkv',
    status: DownloadStatus.queued,
    total: 1390 * _mb,
    done: 0,
  ),
  _item(
    3,
    'Dandadan 2nd Season',
    '[Erai-raws] Dandadan 2nd Season - 08 [1080p][Multiple Subtitle].mkv',
    status: DownloadStatus.paused,
    total: 1310 * _mb,
    done: 270 * _mb,
  ),
  _item(
    4,
    // From the Torrents tab: the torrent's own name stands for the anime.
    'Cowboy Bebop 1998 BDRemux',
    'Cowboy Bebop 1998 BDRemux/Cowboy Bebop - 05 - Ballad of Fallen Angels.mkv',
    status: DownloadStatus.failed,
    total: 4600 * _mb,
    done: 1200 * _mb,
    error: 'No space left on device',
  ),
  _item(
    5,
    'Kusuriya no Hitorigoto',
    'Kusuriya no Hitorigoto - 18 [BDRip 1080p x265 FLAC].mkv',
    status: DownloadStatus.completed,
    total: 820 * _mb,
  ),
  _item(
    6,
    'Kusuriya no Hitorigoto',
    'Kusuriya no Hitorigoto - 17 [BDRip 1080p x265 FLAC].mkv',
    status: DownloadStatus.completed,
    total: 790 * _mb,
  ),
  _item(
    7,
    'Shingeki no Kyojin: The Final Season',
    '[Judas] Shingeki no Kyojin - The Final Season Part 3 - 01 [BD 1080p][HEVC x265 10bit][Dual-Audio][Multi-Subs].mkv',
    status: DownloadStatus.completed,
    total: 2900 * _mb,
  ),
];

class _Downloads implements DownloadsRepository {
  _Downloads(this.items);

  final List<DownloadItem> items;

  @override
  Stream<List<DownloadItem>> watchDownloads() => Stream.value(items);

  @override
  Future<DownloadStorageUsage> calculateStorageUsage() async {
    return DownloadStorageUsage(cacheBytes: 2380 * _mb);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Widget _shell({
  required DownloadManagerCubit cubit,
  required Brightness brightness,
}) {
  late final GoRouter router;
  Widget placeholder(BuildContext context, GoRouterState state) =>
      const SizedBox.shrink();
  router = GoRouter(
    initialLocation: '/downloads',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            AppShellPage(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: placeholder)],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/downloads',
                builder: (context, state) => BlocProvider.value(
                  value: cubit,
                  child: DownloadManagerPage(
                    onWatch: (_) {},
                    onBrowseCatalog: () {},
                    onOpenTitle: (title) =>
                        router.pushNamed('title', extra: title),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'title',
                    name: 'title',
                    builder: (context, state) => BlocProvider.value(
                      value: cubit,
                      child: DownloadTitlePage(
                        title: state.extra as DownloadTitle,
                        onWatch: (_) {},
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: placeholder)],
          ),
        ],
      ),
      GoRoute(
        path: '/downloads/queue',
        name: 'download-queue',
        builder: (context, state) => BlocProvider.value(
          value: cubit,
          child: DownloadQueuePage(
            onOpenTitle: (title) => router.pushNamed('title', extra: title),
          ),
        ),
      ),
    ],
  );
  final history = WatchProgressCubit(
    repository: FixedWatchProgressRepository([
      WatchProgress(
        torrentKey: sourceProgressKey(_downloads.first.magnet),
        fileIndex: 8,
        fileName: 'Frieren - 04.mkv',
        magnet: _downloads.first.magnet,
        sourceTitle: 'Release',
        position: const Duration(minutes: 24),
        duration: const Duration(minutes: 24),
        updatedAt: _now,
      ),
      WatchProgress(
        torrentKey: sourceProgressKey(_downloads.first.magnet),
        fileIndex: 9,
        fileName: 'Frieren - 05.mkv',
        magnet: _downloads.first.magnet,
        sourceTitle: 'Release',
        position: const Duration(minutes: 12),
        duration: const Duration(minutes: 24),
        updatedAt: _now,
      ),
    ]),
  )..load();
  return BlocProvider(
    create: (_) => history,
    child: MaterialApp.router(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      theme: buildAppTheme(brightness: brightness),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: _textScaler),
        child: child!,
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('library, title, queue and files stay usable with large text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    _textScaler = const TextScaler.linear(2);
    final cubit = DownloadManagerCubit(repository: _Downloads(_downloads))
      ..load();
    try {
      await tester.pumpWidget(
        _shell(cubit: cubit, brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('download_title_anime:Sousou no Frieren 2nd Season'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_queue_open')));
      await tester.pumpAndSettle();
      final queue = find.byKey(const Key('download_queue_page'));
      expect(queue, findsOneWidget);
      await tester.tap(
        find.descendant(of: queue, matching: find.byType(BackButton)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_files_open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download_files_sheet')), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        _textScaler = TextScaler.noScaling;
      }
    }
  });

  testWidgets('season selection can queue a batch with large text', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(320, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    _textScaler = const TextScaler.linear(2);
    const args = DownloadSelectionArgs(
      animeId: '52991',
      animeTitle: 'Frieren',
      sourceTitle: 'AniLibria · Frieren',
      magnet: 'online:anilibria/9542?anime=52991',
    );
    final repository = _SeasonDownloads();
    final cubit = DownloadSelectionCubit(args: args, repository: repository)
      ..load();
    try {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          theme: buildAppTheme(brightness: Brightness.dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: _textScaler),
            child: child!,
          ),
          home: BlocProvider.value(
            value: cubit,
            child: DownloadSelectionPage(args: args, onWatch: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('01'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_selection_all')));
      await tester.pumpAndSettle();
      final download = find.byKey(const Key('download_selected'));
      await tester.ensureVisible(download);
      await tester.tap(download);
      await tester.pump();
      repository.queueGate.complete();
      await tester.pumpAndSettle();

      expect(repository.queued, [0, 1, 2]);
      expect(tester.takeException(), isNull);
    } finally {
      if (!repository.queueGate.isCompleted) repository.queueGate.complete();
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(cubit.close);
      } finally {
        debugDefaultTargetPlatformOverride = null;
        _textScaler = TextScaler.noScaling;
      }
    }
  });
}

class _SeasonDownloads extends MockDownloadsRepository {
  final queueGate = Completer<void>();
  final queued = <int>[];

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
    await queueGate.future;
    queued.add(file.index);
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

  @override
  Stream<Map<int, DownloadItem>> watchSourceDownloads({
    required String magnet,
  }) => Stream.value(const {});

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async => const PreparedDownloadSource(
    sourceToken: 'season',
    qualities: [1080, 720, 480],
    files: [
      DownloadableFile(index: 0, name: '01', relativePath: '', size: 0),
      DownloadableFile(index: 1, name: '02', relativePath: '', size: 0),
      DownloadableFile(index: 2, name: '03', relativePath: '', size: 0),
    ],
  );
}
