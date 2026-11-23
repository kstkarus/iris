import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_args.dart';
import 'package:iris/features/player/presentation/pages/player_source_page.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

import '../../../../helpers/fake_player_repository.dart';
import '../../../../helpers/fake_watch_progress_repository.dart';
import '../../../../helpers/memory_online_quality_preferences.dart';
import '../../../../helpers/test_window.dart';
import '../../player_source_test_fixtures.dart';

void main() {
  testWidgets(
    'grid shows both watch and download states and presets select only new files',
    (tester) async {
      setTestWindowSize(tester, TestWindowSizes.phone);
      final fixture = ReleaseDownloadsFixture(
        files: testReleaseFiles(14),
        downloads: [
          testReleaseDownload(3, DownloadStatus.completed),
          testReleaseDownload(4, DownloadStatus.downloading),
          testReleaseDownload(5, DownloadStatus.queued),
          testReleaseDownload(6, DownloadStatus.paused),
          testReleaseDownload(7, DownloadStatus.failed),
        ],
      );
      final page = await _openRelease(
        tester,
        fixture,
        history: [_progress(1, 1440), _progress(2, 1440), _progress(3, 300)],
      );
      expect(find.bySemanticsLabel('Episode 01, Watched'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Episode 03, Stopped at 5:00 of 24:00, Downloaded',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Episode 04, Unwatched, Downloading · 48%'),
        findsOneWidget,
      );
      expect(_text('Stopped at 5:00 of 24:00'), findsOneWidget);
      expect(_text('Downloaded'), findsOneWidget);
      expect(_glyph(PixelGlyph.file), findsOneWidget);
      expect(_glyph(PixelGlyph.pause), findsOneWidget);
      expect(_glyph(PixelGlyph.markWarning), findsOneWidget);

      await tester.longPress(_episode(8));
      await tester.pumpAndSettle();
      expect(page.ready.selected, {8});
      for (final index in [3, 4, 5, 6, 7]) {
        await tester.tap(_episode(index));
      }
      expect(page.ready.selected, {8});
      expect(page.opened, isEmpty);

      Future<void> choose(String label) async {
        await tester.tap(_text('Select'));
        await tester.pumpAndSettle();
        await tester.tap(_text(label));
        await tester.pumpAndSettle();
      }

      await choose('Next 5 episodes');
      expect(page.ready.selected, {8, 9, 10, 11, 12});
      await choose('Unwatched');
      expect(page.ready.selected, {8, 9, 10, 11, 12, 13, 14});
      await choose('Select all');
      expect(page.ready.selected, {1, 2, 8, 9, 10, 11, 12, 13, 14});
      await choose('Deselect all');
      expect(page.ready.selected, isEmpty);
      expect(
        tester.widget<FilledButton>(_button('Select episodes')).onPressed,
        isNull,
      );
      expect(fixture.inventoryActions, 0);
    },
  );

  testWidgets(
    'selection in the list keeps its row size and clears a newly queued file',
    (tester) async {
      setTestWindowSize(tester, TestWindowSizes.phone);
      final fixture = ReleaseDownloadsFixture(
        files: testReleaseFiles(6, named: true),
        downloads: [
          testReleaseDownload(2, DownloadStatus.downloading),
          testReleaseDownload(3, DownloadStatus.paused),
          testReleaseDownload(4, DownloadStatus.failed),
        ],
      );
      final page = await _openRelease(
        tester,
        fixture,
        history: [_progress(1, 1440)],
      );
      expect(_text('Story of episode 1'), findsOneWidget);
      expect(
        find.textContaining('Downloading · 48%', findRichText: true),
        findsOneWidget,
      );
      expect(_text('Paused'), findsOneWidget);
      expect(_text('Failed'), findsOneWidget);
      final firstRow = tester.getSize(_episode(1));
      expect(_glyph(PixelGlyph.check), findsOneWidget);

      await tester.longPress(_episode(1));
      await tester.pumpAndSettle();
      expect(page.ready.selected, {1});
      expect(tester.getSize(_episode(1)), firstRow);
      expect(_glyph(PixelGlyph.check), findsNothing);
      final semantics = tester.getSemantics(
        find.bySemanticsLabel('Episode 01, Story of episode 1, Watched'),
      );
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );

      fixture.update(testReleaseDownload(1, DownloadStatus.queued));
      await tester.pumpAndSettle();
      expect(page.ready.selected, isEmpty);
      expect(find.textContaining('Queued', findRichText: true), findsOneWidget);
      expect(
        tester.widget<FilledButton>(_button('Select episodes')).onPressed,
        isNull,
      );
    },
  );

  testWidgets(
    'Back and Escape leave selection and keep the episode scroll offset',
    (tester) async {
      setTestWindowSize(tester, const Size(390, 550));
      final page = await _openRelease(
        tester,
        ReleaseDownloadsFixture(files: testReleaseFiles(36, named: true)),
      );
      await tester.scrollUntilVisible(_episode(14), 360);
      final scroll = tester.state<ScrollableState>(find.byType(Scrollable));
      final offset = scroll.position.pixels;
      expect(offset, greaterThan(0));

      for (final useEscape in [false, true]) {
        await tester.longPress(_episode(14));
        await tester.pumpAndSettle();
        expect(page.ready.selected, {14});
        if (useEscape) {
          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(page.ready.selecting, isFalse);
        expect(find.byType(PlayerSourcePage), findsOneWidget);
        expect(scroll.position.pixels, offset);
      }
    },
  );

  testWidgets(
    'failed batch keeps those episodes selected and can retry with pinned quality',
    (tester) async {
      setTestWindowSize(tester, TestWindowSizes.phone);
      final preferences = MemoryOnlineQualityPreferences(
        downloading: 720,
        watching: 480,
      );
      final fixture = ReleaseDownloadsFixture(
        files: testReleaseFiles(3),
        qualities: [1080, 720, 480],
      )..reject.add(2);
      final page = await _openRelease(
        tester,
        fixture,
        preferences: preferences,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Download'));
      await tester.pumpAndSettle();
      await tester.tap(_text('720p'));
      await tester.pumpAndSettle();
      expect(_text('Download quality'), findsOneWidget);
      await tester.tap(_text('1080p'));
      await tester.pumpAndSettle();
      expect(preferences.downloading, 1080);
      expect(preferences.watching, 480);

      await tester.tap(_episode(1));
      await tester.tap(_episode(2));
      await tester.pumpAndSettle();
      await tester.tap(_button('Download 2 episodes'));
      await tester.pumpAndSettle();
      expect(page.ready.selected, {2});
      expect(_text('Couldn’t add to the queue. Try again.'), findsOneWidget);

      fixture.reject.clear();
      await tester.tap(_button('Download 1 episode'));
      await tester.pumpAndSettle();
      expect(page.ready.selecting, isFalse);
      expect(fixture.enqueued.map((entry) => (entry.index, entry.quality)), [
        (1, 1080),
        (2, 1080),
      ]);
    },
  );

  for (final width in [390.0, 600.0, 1280.0]) {
    testWidgets('download controls remain reachable at width $width', (
      tester,
    ) async {
      setTestWindowSize(tester, Size(width, 844));
      if (width == 600) {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      final page = await _openRelease(
        tester,
        ReleaseDownloadsFixture(
          files: testReleaseFiles(12),
          qualities: [1080, 720],
        ),
        selectDownloads: true,
      );
      await tester.tap(_episode(1));
      await tester.pumpAndSettle();
      final button = _button('Download 1 episode');
      final buttonRect = tester.getRect(button);
      final tileRect = tester.getRect(_episode(1));
      if (width >= 840) {
        expect(buttonRect.bottom, lessThan(tileRect.top));
        expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
      } else {
        expect(buttonRect.top, greaterThan(tileRect.bottom));
        expect(find.byTooltip('Cancel'), findsOneWidget);
      }
      expect(_text('Auto'), findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(page.ready.selecting, isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Back can leave while the release keeps adding a batch', (
    tester,
  ) async {
    final gate = Completer<void>();
    final fixture = ReleaseDownloadsFixture(files: testReleaseFiles(2))
      ..enqueueGate = gate.future;
    final page = await _openRelease(tester, fixture, selectDownloads: true);
    await tester.tap(_episode(1));
    await tester.tap(_episode(2));
    await tester.pumpAndSettle();
    await tester.tap(_button('Download 2 episodes'));
    await tester.pump();
    expect(page.ready.addingBatch, isTrue);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(_text('Sources landing'), findsOneWidget);
    expect(fixture.disposed, isEmpty);
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PlayerSourcePage, skipOffstage: false), findsNothing);
    expect(fixture.enqueued.map((entry) => entry.index), [1, 2]);
    expect(fixture.disposed, ['release']);
  });

  testWidgets('a finished single file offers to watch again', (tester) async {
    final page = await _openRelease(
      tester,
      ReleaseDownloadsFixture(files: testReleaseFiles(1, named: true)),
      history: [_progress(1, 1440)],
    );
    await tester.tap(_button('Watch again'));
    await tester.pumpAndSettle();
    expect(page.opened.single.source.fileIndex, 1);
  });

  testWidgets(
    'one online file shows its watch progress, local quality and Downloads link',
    (tester) async {
      setTestWindowSize(tester, TestWindowSizes.phone);
      final fixture = ReleaseDownloadsFixture(
        files: testReleaseFiles(1, named: true),
        qualities: [1080, 720],
      );
      final page = await _openRelease(
        tester,
        fixture,
        locale: const Locale('ru'),
        history: [_progress(1, 600)],
      );
      expect(page.opened, isEmpty);
      expect(_button('Продолжить'), findsOneWidget);
      expect(_text('до 1080p'), findsOneWidget);
      expect(find.bySemanticsLabel('до 1080p'), findsOneWidget);
      expect(_text('Авто'), findsOneWidget);
      expect(find.byType(SegmentedBar), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Скачать'));
      await tester.pumpAndSettle();
      expect(fixture.enqueued.single.index, 1);
      expect(_text('В очереди'), findsOneWidget);
      for (final (status, label) in [
        (DownloadStatus.downloading, '48 %'),
        (DownloadStatus.paused, 'На паузе'),
        (DownloadStatus.failed, 'Ошибка'),
        (DownloadStatus.completed, 'Скачано'),
      ]) {
        fixture.update(
          testReleaseDownload(
            1,
            status,
            totalBytes: status == DownloadStatus.completed ? 1524713390 : 100,
            videoHeight: status == DownloadStatus.completed ? 720 : null,
          ),
        );
        await tester.pumpAndSettle();
        expect(_text(label), findsOneWidget);
        expect(find.byType(SegmentedBar), findsOneWidget);
      }
      expect(_text('1,42 ГБ'), findsOneWidget);
      expect(_text('720p'), findsOneWidget);
      await tester.tap(_text('В загрузки'));
      await tester.pumpAndSettle();
      expect(_text('Downloads landing'), findsOneWidget);
    },
  );

  testWidgets(
    'a single torrent is playable from its card and Back returns to it',
    (tester) async {
      final page = await _openRelease(
        tester,
        ReleaseDownloadsFixture(
          files: const [
            DownloadableFile(
              index: 5,
              name: 'Feature Film.mkv',
              relativePath: 'Feature Film.mkv',
              size: 4294967296,
            ),
          ],
        ),
        online: false,
        selectDownloads: true,
      );
      expect(page.opened, isEmpty);
      expect(_text('Feature Film'), findsOneWidget);
      expect(_text('4.00 GB'), findsOneWidget);
      await tester.tap(_button('Watch'));
      await tester.pumpAndSettle();
      expect(page.opened.single.source.fileIndex, 5);
      expect(page.opened.single.playFromRelease, isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(_button('Watch'), findsOneWidget);
    },
  );

  testWidgets('only an explicit history index opens the player immediately', (
    tester,
  ) async {
    final page = await _openRelease(
      tester,
      ReleaseDownloadsFixture(files: testReleaseFiles(28)),
      autoOpenFileIndex: 8,
    );
    expect(page.opened.single.source.fileIndex, 8);
    expect(page.opened.single.source.files, hasLength(28));
    expect(page.opened.single.source.nextFile?.index, 9);
  });
}

Finder _episode(int index) => find.byKey(ValueKey('player_episode_$index'));
Finder _button(String label) => find.widgetWithText(FilledButton, label);
Finder _text(String text) => find.text(text, findRichText: true);
Finder _glyph(PixelGlyph glyph) => find.byWidgetPredicate(
  (widget) => widget is PixelIcon && widget.glyph == glyph,
);

WatchProgress _progress(int index, int seconds) => WatchProgress(
  torrentKey: sourceProgressKey(testReleaseLink),
  fileIndex: index,
  fileName: '$index',
  magnet: testReleaseLink,
  sourceTitle: 'AniLibria',
  position: Duration(seconds: seconds),
  duration: const Duration(minutes: 24),
  updatedAt: DateTime(2026, 1, index),
  animeId: '52991',
  animeTitle: 'Frieren',
);

class _ReleasePageFixture {
  _ReleasePageFixture(this.cubit);

  final PlayerSourceCubit cubit;
  final opened = <AnimePlayerArgs>[];
  PlayerSourceReady get ready => cubit.state as PlayerSourceReady;
}

Future<_ReleasePageFixture> _openRelease(
  WidgetTester tester,
  ReleaseDownloadsFixture downloads, {
  bool online = true,
  bool selectDownloads = false,
  int? autoOpenFileIndex,
  Locale locale = const Locale('en'),
  List<WatchProgress> history = const [],
  MemoryOnlineQualityPreferences? preferences,
}) async {
  final args = testReleaseArgs(
    online: online,
    selectDownloads: selectDownloads,
    autoOpenFileIndex: autoOpenFileIndex,
  );
  final cubit = PlayerSourceCubit(
    args: args,
    downloadsRepository: downloads,
    playerRepository: StubPlayerRepository(),
    qualityPreferences: preferences,
  );
  final page = _ReleasePageFixture(cubit);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('Sources landing')),
      ),
      GoRoute(
        path: '/release',
        name: 'release',
        builder: (_, _) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => cubit..loadSource()),
            BlocProvider(
              create: (_) => WatchProgressCubit(
                repository: FixedWatchProgressRepository(history),
              )..load(),
            ),
          ],
          child: PlayerSourcePage(args: args),
        ),
      ),
      GoRoute(
        path: '/player',
        name: 'player',
        builder: (_, state) {
          page.opened.add(state.extra! as AnimePlayerArgs);
          return Scaffold(appBar: AppBar(title: const Text('Playing')));
        },
      ),
      GoRoute(
        path: '/downloads',
        name: 'downloads',
        builder: (_, _) => const Scaffold(body: Text('Downloads landing')),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(() => downloads.closeFixture().ignore());
  await tester.pumpWidget(
    MaterialApp.router(
      theme: buildAppTheme(brightness: Brightness.dark),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  router.pushNamed('release');
  await tester.pumpAndSettle();
  return page;
}
