// Renders the real library and episode widgets with offline fixtures.
// PNGs are saved under .dart_tool/download-library-renders.
import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as path;

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
import 'package:iris/shared/widgets/dither_transition.dart';

TextScaler _textScaler = TextScaler.noScaling;

const _captureKey = Key('downloads_render_root');
const _phone = Size(390, 844);
const _desktop = Size(1440, 900);
const _mb = 1024 * 1024;

Future<void> _loadFonts() async {
  final mono = FontLoader('Geist Mono')
    ..addFont(rootBundle.load('assets/fonts/GeistMono-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/GeistMono-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/GeistMono-SemiBold.ttf'));
  final sans = FontLoader('Geist')
    ..addFont(rootBundle.load('assets/fonts/Geist-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/Geist-Medium.ttf'));
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
    final bytes = items.fold<int>(0, (sum, item) => sum + item.downloadedBytes);
    return DownloadStorageUsage(
      downloadsBytes: bytes,
      cacheBytes: 2380 * _mb,
      totalBytes: bytes + 2380 * _mb,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
        path.join(
          Directory.current.path,
          '.dart_tool',
          'download-library-renders',
          '$name.png',
        ),
      );
      file.parent.createSync(recursive: true);
      file.writeAsBytesSync(bytes!.buffer.asUint8List());
      debugPrint('RENDER ${file.absolute.path}');
    } finally {
      image.dispose();
    }
  });
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
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: placeholder)],
          ),
        ],
      ),
      GoRoute(
        path: '/downloads/title',
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
  return RepaintBoundary(
    key: _captureKey,
    child: BlocProvider(
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
    ),
  );
}

void main() {
  setUpAll(_loadFonts);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<void> render(
    WidgetTester tester,
    String name, {
    required Size size,
    Brightness brightness = Brightness.dark,
    List<DownloadItem>? items,
    bool details = false,
    double scale = 1,
    TargetPlatform platform = TargetPlatform.android,
  }) async {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
    _textScaler = TextScaler.linear(scale);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = size.width > 900
        ? TargetPlatform.windows
        : platform;

    final cubit = DownloadManagerCubit(
      repository: _Downloads(items ?? _downloads),
    )..load();
    await tester.pumpWidget(_shell(cubit: cubit, brightness: brightness));
    await tester.pumpAndSettle();
    if (details) {
      await tester.tap(
        find.byKey(
          const ValueKey('download_title_anime:Sousou no Frieren 2nd Season'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await _capture(tester, name);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(cubit.close);
    debugDefaultTargetPlatformOverride = null;
  }

  testWidgets('library and title episodes render without overflow', (
    tester,
  ) async {
    for (final config in [
      ('phone', _phone, Brightness.dark, 1.0),
      ('desktop', _desktop, Brightness.dark, 1.0),
      ('tablet', const Size(834, 1100), Brightness.light, 1.0),
      ('large_text', const Size(320, 900), Brightness.dark, 2.0),
      ('ios_light', _phone, Brightness.light, 1.0),
    ]) {
      await render(
        tester,
        'library_${config.$1}',
        size: config.$2,
        brightness: config.$3,
        scale: config.$4,
        platform: config.$1 == 'ios_light'
            ? TargetPlatform.iOS
            : TargetPlatform.android,
      );
      await render(
        tester,
        'episodes_${config.$1}',
        size: config.$2,
        brightness: config.$3,
        scale: config.$4,
        platform: config.$1 == 'ios_light'
            ? TargetPlatform.iOS
            : TargetPlatform.android,
        details: true,
      );
    }
    await render(tester, 'library_empty', size: _phone, items: []);
  });
  testWidgets('season download controls render on phone and desktop', (
    tester,
  ) async {
    for (final config in [
      ('phone', _phone, 1.0),
      ('desktop', _desktop, 1.0),
      ('large_text', const Size(320, 900), 2.0),
    ]) {
      tester.view
        ..physicalSize = config.$2
        ..devicePixelRatio = 1;
      _textScaler = TextScaler.linear(config.$3);
      debugDefaultTargetPlatformOverride = config.$2.width > 900
          ? TargetPlatform.windows
          : TargetPlatform.android;
      const args = DownloadSelectionArgs(
        animeId: '52991',
        animeTitle: 'Frieren',
        sourceTitle: 'AniLibria · Frieren',
        magnet: 'online:anilibria/9542?anime=52991',
      );
      final cubit = DownloadSelectionCubit(
        args: args,
        repository: _SeasonDownloads(),
      )..load();
      await tester.pumpWidget(
        RepaintBoundary(
          key: _captureKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
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
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download_all')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _capture(tester, 'selection_${config.$1}');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(cubit.close);
      tester.view.reset();
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
    'title insertion and deletion render in the existing dither style',
    (tester) async {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      _textScaler = TextScaler.noScaling;
      tester.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final repository = _LiveDownloads([_downloads.first]);
      final cubit = DownloadManagerCubit(repository: repository)..load();
      await tester.pumpWidget(
        _shell(cubit: cubit, brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();
      await _capture(tester, 'library_motion_initial');
      repository.push([_downloads.first, _downloads[4]]);
      await tester.pump();
      await tester.pump();
      await tester.pump(DitherTransition.duration * 1.5);
      expect(
        tester
            .widgetList<BayerMasked>(find.byType(BayerMasked))
            .any((mask) => mask.open > 0 && mask.open < 16),
        isTrue,
      );
      await _capture(tester, 'library_motion_insert');
      await tester.pumpAndSettle();
      repository.push([_downloads[4]]);
      await tester.pump();
      await tester.pump();
      await tester.pump(DitherTransition.duration ~/ 2);
      await _capture(tester, 'library_motion_remove');
      await tester.pumpAndSettle();
      repository.push([]);
      await tester.pumpAndSettle();
      await _capture(tester, 'library_motion_empty');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(cubit.close);
      await tester.runAsync(repository.changes.close);
      debugDefaultTargetPlatformOverride = null;
    },
  );
}

class _LiveDownloads extends _Downloads {
  _LiveDownloads(super.items);
  late final StreamController<List<DownloadItem>> changes =
      StreamController<List<DownloadItem>>.broadcast(
        onListen: () => changes.add(List.of(items)),
      );

  void push(List<DownloadItem> next) {
    items
      ..clear()
      ..addAll(next);
    changes.add(List.of(items));
  }

  @override
  Stream<List<DownloadItem>> watchDownloads() => changes.stream;
}

class _SeasonDownloads extends MockDownloadsRepository {
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
