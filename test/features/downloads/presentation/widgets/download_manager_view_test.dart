import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/downloads/presentation/pages/download_manager_page.dart';
import 'package:iris/features/downloads/presentation/pages/download_title_page.dart';
import 'package:iris/features/downloads/presentation/pages/download_selection_page.dart';
import 'package:iris/features/downloads/presentation/widgets/download_title_widgets.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/focusable_list_row.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';
import '../../../../helpers/fake_watch_progress_repository.dart';

void main() {
  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('library keeps storage in its menu on ${entry.key}', (
      tester,
    ) async {
      await _withTargetPlatform(
        entry.value.width >= 900
            ? TargetPlatform.windows
            : TargetPlatform.android,
        () async {
          setTestWindowSize(tester, entry.value);
          final repository = await _repositoryWithDownloads(count: 3);

          await _pumpApp(
            tester,
            BlocProvider(
              create: (_) =>
                  DownloadManagerCubit(repository: repository)..load(),
              child: DownloadManagerPage(
                onOpenTitle: (_) {},
                onWatch: (_) {},
                onBrowseCatalog: () {},
              ),
            ),
          );

          expect(find.text('APP STORAGE'), findsNothing);
          if (entry.value.width >= 900) {
            await tester.tap(
              find.byKey(const ValueKey('download_title_anime:5114')),
            );
          }
          await tester.tap(
            find.byKey(
              Key(
                entry.value.width >= 900
                    ? 'download_title_menu'
                    : 'download_library_menu',
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('download_storage_open')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('download_storage_dialog')),
            findsOneWidget,
          );
          expect(find.text('APP STORAGE'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    });

    testWidgets('download manager empty state fits on ${entry.key}', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      setTestWindowSize(tester, entry.value);

      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) =>
              DownloadManagerCubit(repository: MockDownloadsRepository())
                ..load(),
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );

      expect(
        find.text('Download episodes from an anime’s page to watch offline.'),
        findsOneWidget,
      );
      expect(find.text('No downloads yet'), findsOneWidget);
      expect(
        tester
            .getSemantics(find.text('No downloads yet'))
            .flagsCollection
            .isHeader,
        isTrue,
      );
      expect(find.text('0 titles'), findsNothing);
      expect(find.byType(SegmentedRule), findsNothing);
      expect(find.text('Browse the catalog'), findsOneWidget);
      await tester.tap(find.byKey(const Key('download_library_menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_storage_open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download_storage_dialog')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });

    testWidgets('download selection keeps to the page frame on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);
      const args = DownloadSelectionArgs(
        animeId: '5114',
        animeTitle: 'Fullmetal Alchemist: Brotherhood',
        sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
        magnet: 'magnet:?xt=urn:btih:mock',
      );

      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadSelectionCubit(
            args: args,
            repository: MockDownloadsRepository(),
          )..load(),
          child: DownloadSelectionPage(args: args, onWatch: (_) {}),
        ),
      );

      final row = tester.getRect(
        find.ancestor(
          of: find.text('episode-01'),
          matching: find.byType(InkWell),
        ),
      );
      expect(find.text('episode-01'), findsOneWidget);
      expect(row.width, lessThanOrEqualTo(AdaptiveContentWidth.page));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the library opens one title containing all its episodes', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.android, () async {
      final repository = await _repositoryWithDownloads(count: 3);
      DownloadTitle? opened;
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(repository: repository)..load(),
          child: DownloadManagerPage(
            onWatch: (_) {},
            onBrowseCatalog: () {},
            onOpenTitle: (title) => opened = title,
          ),
        ),
      );
      expect(
        find.text('Fullmetal Alchemist: Brotherhood'),
        findsAtLeastNWidgets(1),
      );
      expect(find.text('episode-00'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('download_title_anime:5114')));
      expect(opened?.items, hasLength(3));
    });
  });

  testWidgets('gallery title appears once when its poster is missing', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.android, () async {
      final item = _libraryDownload(
        id: 'missing-poster-1',
        animeId: 'missing-poster',
        animeTitle: 'Missing poster title',
        fileName: 'Missing poster title - 01.mkv',
        status: DownloadStatus.completed,
        createdAt: DateTime(2026, 10, 10),
      ).copyWith(posterUrl: '');
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(
            repository: _ScriptedDownloadsRepository([item]),
          )..load(),
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );

      expect(find.text('Missing poster title'), findsOneWidget);
    });
  });

  testWidgets('gallery captions keep their geometry and expose full activity', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.android, () async {
      setTestWindowSize(tester, const Size(390, 844));
      final short = _libraryDownload(
        id: 'short-1',
        animeId: 'short',
        animeTitle: 'Short',
        fileName: 'Short - 01.mkv',
        status: DownloadStatus.completed,
        createdAt: DateTime(2026, 10, 10),
      );
      final long = _libraryDownload(
        id: 'long-1',
        animeId: 'long',
        animeTitle: 'A Very Long Anime Title That Wraps Across Two Lines',
        fileName: 'Long - 01.mkv',
        status: DownloadStatus.queued,
        createdAt: DateTime(2026, 10, 9),
      );
      final repository = _ScriptedDownloadsRepository([short, long]);
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(repository: repository)..load(),
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );

      const shortCard = ValueKey('download_title_anime:short');
      const longCard = ValueKey('download_title_anime:long');
      const shortCount = ValueKey('download_title_count_anime:short');
      const longCount = ValueKey('download_title_count_anime:long');

      double countTop(Key card, Key count) {
        final countRect = tester.getRect(find.byKey(count));
        final posterRect = tester.getRect(
          find.descendant(
            of: find.byKey(card),
            matching: find.byType(DownloadTitlePoster),
          ),
        );
        return countRect.top - posterRect.bottom;
      }

      final initialShortOffset = countTop(shortCard, shortCount);
      final initialLongOffset = countTop(longCard, longCount);
      expect(initialShortOffset, closeTo(initialLongOffset, 0.1));
      expect(
        find.descendant(
          of: find.byKey(shortCard),
          matching: find.byType(PixelIcon),
        ),
        findsNothing,
        reason: 'completed titles already show readiness in the count',
      );

      repository.push([
        short,
        long.copyWith(status: DownloadStatus.downloading),
      ]);
      await tester.pumpAndSettle();
      expect(countTop(shortCard, shortCount), closeTo(initialShortOffset, 0.1));
      expect(countTop(longCard, longCount), closeTo(initialLongOffset, 0.1));

      final failedEpisode = _libraryDownload(
        id: 'long-2',
        animeId: 'long',
        animeTitle: long.animeTitle,
        fileName: 'Long - 02.mkv',
        status: DownloadStatus.failed,
        createdAt: DateTime(2026, 10, 8),
      );
      repository.push([
        short,
        long.copyWith(status: DownloadStatus.downloading),
        failedEpisode,
      ]);
      await tester.pumpAndSettle();

      final longBadge = find.descendant(
        of: find.byKey(longCard),
        matching: find.byType(PixelIcon),
      );
      expect(tester.widget<PixelIcon>(longBadge).glyph, PixelGlyph.close);
      expect(countTop(shortCard, shortCount), closeTo(initialShortOffset, 0.1));
      expect(countTop(longCard, longCount), closeTo(initialLongOffset, 0.1));
      final semanticsData = tester
          .getSemantics(find.byKey(longCard))
          .getSemanticsData();
      final semanticsLabel = semanticsData.label;
      expect(
        RegExp(RegExp.escape(long.animeTitle)).allMatches(semanticsLabel),
        hasLength(1),
      );
      expect(
        RegExp('0 of 2 episodes').allMatches(semanticsLabel),
        hasLength(1),
      );
      expect(semanticsLabel, contains('Downloading: 1 · Failed: 1'));
      expect(semanticsData.flagsCollection.isButton, isTrue);
      expect(semanticsData.hasAction(SemanticsAction.tap), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Windows keeps its selected title by key across list changes', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.windows, () async {
      setTestWindowSize(tester, const Size(1440, 1000));
      final alpha = _libraryDownload(
        id: 'alpha-1',
        animeId: 'alpha',
        animeTitle: 'Alpha',
        fileName: 'Alpha - 01.mkv',
        status: DownloadStatus.completed,
        createdAt: DateTime(2026, 10, 10),
      ).copyWith(posterUrl: '');
      final beta = _libraryDownload(
        id: 'beta-1',
        animeId: 'beta',
        animeTitle: 'Beta',
        fileName: 'Beta - 01.mkv',
        status: DownloadStatus.paused,
        createdAt: DateTime(2026, 10, 9),
      );
      final repository = _ScriptedDownloadsRepository([alpha, beta]);
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(repository: repository)..load(),
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );

      final alphaKey = const ValueKey('download_title_anime:alpha');
      final betaKey = const ValueKey('download_title_anime:beta');
      await tester.tap(find.byKey(alphaKey));
      await tester.pumpAndSettle();
      expect(find.byType(DownloadTitleIdentity), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(DownloadTitleIdentity),
          matching: find.text('Alpha'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(DownloadPosterOption),
          matching: find.text('Alpha'),
        ),
        findsOneWidget,
      );
      expect(find.byType(DownloadPosterOption), findsNWidgets(2));
      expect(
        find.byKey(const ValueKey('download_episodes_list_anime:alpha')),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.byKey(alphaKey))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );

      // Beta becomes active and moves ahead of Alpha in the library ordering.
      repository.push([
        alpha,
        beta.copyWith(status: DownloadStatus.downloading),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(DownloadTitleIdentity),
          matching: find.text('Alpha'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .getSemantics(find.byKey(alphaKey))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      expect(
        tester
            .getSemantics(find.byKey(betaKey))
            .getSemanticsData()
            .flagsCollection
            .isSelected,
        Tristate.isFalse,
      );

      repository.push([
        alpha.copyWith(downloadedBytes: 1),
        beta.copyWith(status: DownloadStatus.downloading),
      ]);
      await tester.pumpAndSettle();
      repository.push([alpha.copyWith(downloadedBytes: 1)]);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(DownloadTitleIdentity),
          matching: find.text('Alpha'),
        ),
        findsOneWidget,
      );
      expect(find.byType(DownloadTitleIdentity), findsOneWidget);
    });
  });

  testWidgets('Windows poster and episode lists scroll independently', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.windows, () async {
      setTestWindowSize(tester, const Size(1440, 700));
      final items = <DownloadItem>[];
      for (var title = 0; title < 12; title++) {
        final animeId = 'show-$title';
        final titleName = 'Show $title';
        final date = DateTime(2026, 10, 1, title);
        if (title == 11) {
          for (var episode = 1; episode <= 12; episode++) {
            final fileName =
                '$titleName - ${episode.toString().padLeft(2, '0')}.mkv';
            items.add(
              _libraryDownload(
                id: '$animeId-$episode',
                animeId: animeId,
                animeTitle: titleName,
                fileName: fileName,
                status: DownloadStatus.completed,
                createdAt: date,
              ).copyWith(fileIndex: episode - 1),
            );
          }
        } else {
          items.add(
            _libraryDownload(
              id: '$animeId-1',
              animeId: animeId,
              animeTitle: titleName,
              fileName: '$titleName - 01.mkv',
              status: DownloadStatus.completed,
              createdAt: date,
            ),
          );
        }
      }
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(
            repository: _ScriptedDownloadsRepository(items),
          )..load(),
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey('download_title_anime:show-11')),
      );
      await tester.pumpAndSettle();

      final posterScroll = find.descendant(
        of: find.byKey(const Key('download_poster_list')),
        matching: find.byType(Scrollable),
      );
      final episodeScroll = find.descendant(
        of: find.byKey(const ValueKey('download_episodes_list_anime:show-11')),
        matching: find.byType(Scrollable),
      );
      expect(posterScroll, findsOneWidget);
      expect(episodeScroll, findsOneWidget);
      final posterPosition = tester
          .state<ScrollableState>(posterScroll)
          .position;
      final episodePosition = tester
          .state<ScrollableState>(episodeScroll)
          .position;

      await tester.drag(episodeScroll, const Offset(0, -420));
      await tester.pumpAndSettle();
      final episodeOffset = episodePosition.pixels;
      expect(episodeOffset, greaterThan(0));
      await tester.drag(posterScroll, const Offset(0, -420));
      await tester.pumpAndSettle();
      expect(posterPosition.pixels, greaterThan(0));
      expect(episodePosition.pixels, episodeOffset);
    });
  });

  testWidgets('phone title header collapses, stays pinned, and restores', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.android, () async {
      setTestWindowSize(tester, const Size(390, 844));
      final items = [
        for (var episode = 1; episode <= 20; episode++)
          _libraryDownload(
            id: 'header-$episode',
            animeId: 'header',
            animeTitle: 'A title with a long identity',
            fileName: 'Episode $episode.mkv',
            status: DownloadStatus.completed,
            createdAt: DateTime(2026, 10, 1, episode),
          ),
      ];
      final title = downloadTitles(items).single;
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(
            repository: _ScriptedDownloadsRepository(items),
          )..load(),
          child: DownloadTitlePage(title: title, onWatch: (_) {}),
        ),
      );

      const listKey = ValueKey('download_episodes_list_anime:header');
      const expandedKey = Key('download_header_expanded_identity');
      const compactKey = Key('download_header_compact_identity');
      expect(find.byKey(expandedKey), findsOneWidget);
      expect(find.byKey(compactKey), findsNothing);
      final scrollable = find.descendant(
        of: find.byKey(listKey),
        matching: find.byType(Scrollable),
      );
      for (var step = 0; step < 5; step++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pumpAndSettle();
      }

      expect(find.byKey(expandedKey), findsNothing);
      expect(find.byKey(compactKey), findsOneWidget);
      for (var step = 0; step < 2; step++) {
        await tester.drag(scrollable, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(compactKey), findsOneWidget);

      await tester.fling(scrollable, const Offset(0, 1400), 4000);
      await tester.pumpAndSettle();
      expect(find.byKey(compactKey), findsNothing);
      expect(find.byKey(expandedKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'phone title header survives resize, large text, and reduced motion',
    (tester) async {
      await _withTargetPlatform(TargetPlatform.android, () async {
        setTestWindowSize(tester, const Size(320, 844));
        tester.platformDispatcher.textScaleFactorTestValue = 2.5;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final item = _libraryDownload(
          id: 'resize-1',
          animeId: 'resize',
          animeTitle: 'A very long title that should wrap without overflow',
          fileName: 'Episode 01.mkv',
          status: DownloadStatus.completed,
          createdAt: DateTime(2026, 10, 1),
        );
        final title = downloadTitles([item]).single;
        await _pumpApp(
          tester,
          BlocProvider(
            create: (_) => DownloadManagerCubit(
              repository: _ScriptedDownloadsRepository([item]),
            )..load(),
            child: DownloadTitlePage(title: title, onWatch: (_) {}),
          ),
        );
        expect(
          find.byKey(const Key('download_header_expanded_identity')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        setTestWindowSize(tester, const Size(600, 844));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.hasRunningAnimations, isFalse);
      });
    },
  );

  testWidgets('phone title identity updates while its anime key stays stable', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.android, () async {
      setTestWindowSize(tester, const Size(390, 844));
      final item = _libraryDownload(
        id: 'identity-1',
        animeId: 'identity',
        animeTitle: 'Old title',
        fileName: 'Episode 01.mkv',
        status: DownloadStatus.completed,
        createdAt: DateTime(2026, 10, 1),
      );
      final repository = _ScriptedDownloadsRepository([item]);
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(repository: repository)..load(),
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            titleKey: 'anime:identity',
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );
      repository.push([item.copyWith(animeTitle: 'Updated title')]);
      await tester.pumpAndSettle();

      expect(find.text('Updated title'), findsOneWidget);
      expect(find.text('Old title'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('desktop title change resets to the remaining title', (
    tester,
  ) async {
    await _withTargetPlatform(TargetPlatform.windows, () async {
      setTestWindowSize(tester, const Size(1440, 900));
      final alpha = _libraryDownload(
        id: 'reset-alpha',
        animeId: 'reset-alpha',
        animeTitle: 'Alpha',
        fileName: 'Alpha - 01.mkv',
        status: DownloadStatus.completed,
        createdAt: DateTime(2026, 10, 1),
      );
      final beta = _libraryDownload(
        id: 'reset-beta',
        animeId: 'reset-beta',
        animeTitle: 'Beta',
        fileName: 'Beta - 01.mkv',
        status: DownloadStatus.completed,
        createdAt: DateTime(2026, 10, 2),
      );
      final repository = _ScriptedDownloadsRepository([alpha, beta]);
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(repository: repository)..load(),
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(DownloadTitleIdentity),
          matching: find.text('Beta'),
        ),
        findsOneWidget,
      );

      repository.push([alpha]);
      await tester.pumpAndSettle();

      expect(find.text('Beta'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(DownloadTitleIdentity),
          matching: find.text('Alpha'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('deleting a title asks once and removes all its episodes', (
    tester,
  ) async {
    final repository = await _repositoryWithDownloads(count: 3);
    const source = PreparedDownloadSource(
      sourceToken: 'other-source',
      files: [],
    );
    await repository.enqueueDownload(
      source: source,
      file: const DownloadableFile(
        index: 100,
        name: 'other.mkv',
        relativePath: 'other.mkv',
        size: 10,
      ),
      animeId: 'other-anime',
      animeTitle: 'Other title',
      sourceTitle: 'Other release',
    );
    final title = downloadTitles(
      await repository.watchDownloads().first,
    ).singleWhere((title) => title.key == 'anime:5114');
    await _pumpApp(
      tester,
      BlocProvider(
        create: (_) => DownloadManagerCubit(repository: repository)..load(),
        child: DownloadTitlePage(title: title, onWatch: (_) {}),
      ),
    );
    await tester.tap(find.byKey(const Key('download_title_menu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('download_title_delete_all')), findsOneWidget);

    await tester.tap(find.byKey(const Key('download_title_delete_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await repository.watchDownloads().first, hasLength(4));
    await tester.tap(find.byKey(const Key('download_title_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('download_title_delete_all')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    final remaining = await repository.watchDownloads().first;
    expect(remaining, hasLength(1));
    expect(remaining.single.animeId, 'other-anime');
  });

  testWidgets('a row names the episode and its buttons name the row', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = await _repositoryWithDownloads(count: 1);
    await repository.pause(id: 'mock-0');
    await _pumpApp(
      tester,
      BlocProvider(
        create: (_) => DownloadManagerCubit(repository: repository)..load(),
        child: DownloadManagerPage(
          onOpenTitle: (_) {},
          titleKey: 'anime:5114',
          onWatch: (_) {},
          onBrowseCatalog: () {},
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp('^Resume: Fullmetal Alchemist: Brotherhood, '),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('download_action_mock-0')), findsOneWidget);
    expect(find.byKey(const Key('download_delete')), findsNothing);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.customSemanticsActions?.keys.any(
                  (action) => action.label == 'More actions',
                ) ==
                true,
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('an empty list leads to the catalog', (tester) async {
    var opened = 0;
    await _pumpApp(
      tester,
      BlocProvider(
        create: (_) =>
            DownloadManagerCubit(repository: MockDownloadsRepository())..load(),
        child: DownloadManagerPage(
          onOpenTitle: (_) {},
          onWatch: (_) {},
          onBrowseCatalog: () => opened++,
        ),
      ),
    );

    await tester.tap(find.text('Browse the catalog'));
    expect(opened, 1);
  });

  group('a row', () {
    DownloadItem download({
      DownloadStatus status = DownloadStatus.downloading,
      int downloaded = 300 * 1024 * 1024,
      int rate = 1024 * 1024,
      int peers = 3,
      int total = 600 * 1024 * 1024,
      String magnet = 'magnet:?xt=urn:btih:frieren',
      String? error,
      int? quality,
      int? videoHeight,
    }) => DownloadItem(
      id: 'frieren-6',
      animeId: '52991',
      animeTitle: 'Frieren',
      sourceTitle: 'Frieren batch',
      magnet: magnet,
      fileIndex: 5,
      fileName: 'Frieren - 06.mkv',
      relativePath: 'Frieren - 06.mkv',
      localPath: 'Frieren - 06.mkv',
      totalBytes: total,
      downloadedBytes: downloaded,
      downloadRateBytesPerSecond: rate,
      peers: peers,
      status: status,
      createdAt: DateTime(2026, 10, 10),
      errorMessage: error,
      quality: quality,
      videoHeight: videoHeight,
    );

    Future<_ScriptedDownloadsRepository> pump(
      WidgetTester tester,
      DownloadItem item,
    ) async {
      final repository = _ScriptedDownloadsRepository([item]);
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(repository: repository)..load(),
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            titleKey: downloadTitleKey(item),
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );
      return repository;
    }

    Future<void> openStatus(WidgetTester tester) async {
      await tester.longPress(find.text('Episode 06'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('download_status')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download_status_dialog')), findsOneWidget);
    }

    Finder statusText(String text) => find.descendant(
      of: find.byKey(const Key('download_status_dialog')),
      matching: find.textContaining(text),
    );

    testWidgets('multiple releases retain their headings', (tester) async {
      final first = download().copyWith(
        id: 'first-release',
        magnet: 'magnet:?xt=urn:btih:first-release',
        sourceTitle: 'First release',
      );
      final second = download().copyWith(
        id: 'second-release',
        fileIndex: 6,
        fileName: 'Frieren - 07.mkv',
        magnet: 'magnet:?xt=urn:btih:second-release',
        sourceTitle: 'Second release',
      );
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(
            repository: _ScriptedDownloadsRepository([first, second]),
          )..load(),
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            titleKey: 'anime:52991',
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );

      expect(find.textContaining('FIRST RELEASE'), findsOneWidget);
      expect(find.textContaining('SECOND RELEASE'), findsOneWidget);
    });

    testWidgets('shows known heights per episode when a release disagrees', (
      tester,
    ) async {
      await _withTargetPlatform(TargetPlatform.android, () async {
        final first = download(quality: 1440, videoHeight: 1080);
        final second = first.copyWith(
          id: 'frieren-7',
          fileIndex: 6,
          fileName: 'Frieren - 07.mkv',
          videoHeight: 720,
          quality: 1440,
        );
        final unknown = first.copyWith(
          id: 'frieren-8',
          fileIndex: 7,
          fileName: 'Frieren - 08.mkv',
          videoHeight: null,
        );
        await _pumpApp(
          tester,
          BlocProvider(
            create: (_) => DownloadManagerCubit(
              repository: _ScriptedDownloadsRepository([
                first,
                second,
                unknown,
              ]),
            )..load(),
            child: DownloadManagerPage(
              onOpenTitle: (_) {},
              titleKey: 'anime:52991',
              onWatch: (_) {},
              onBrowseCatalog: () {},
            ),
          ),
        );

        expect(find.text('1080p'), findsOneWidget);
        expect(find.text('720p'), findsOneWidget);
        expect(find.text('1440p'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    Finder rowFor(WidgetTester tester, String id) => find.ancestor(
      of: find.byKey(Key('download_action_$id')),
      matching: find.byType(FocusableListRow),
    );

    testWidgets('download rows keep a stable 48px action at large text', (
      tester,
    ) async {
      await _withTargetPlatform(TargetPlatform.android, () async {
        setTestWindowSize(tester, const Size(390, 844));
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final initial = download(
          status: DownloadStatus.completed,
          downloaded: 600 * 1024 * 1024,
        );
        final repository = await pump(tester, initial);
        final action = find.byKey(const Key('download_action_frieren-6'));
        final row = rowFor(tester, initial.id);
        final initialRowRect = tester.getRect(row);
        final initialActionRect = tester.getRect(action);
        final episodeName = find.descendant(
          of: row,
          matching: find.text('Episode 06'),
        );

        expect(initialRowRect.height, 64);
        expect(initialActionRect.size, const Size(48, 48));
        expect(
          tester.getRect(episodeName).left,
          closeTo(initialRowRect.left, .1),
        );
        expect(
          find.descendant(of: row, matching: find.byType(BayerMasked)),
          findsNothing,
        );
        expect(
          find.descendant(of: row, matching: find.byType(SegmentedBar)),
          findsNothing,
        );

        for (final status in const [
          DownloadStatus.downloading,
          DownloadStatus.queued,
          DownloadStatus.paused,
          DownloadStatus.failed,
          DownloadStatus.completed,
        ]) {
          final updated = initial.copyWith(
            status: status,
            downloadedBytes: status == DownloadStatus.completed
                ? initial.totalBytes
                : 300 * 1024 * 1024,
            errorMessage: status == DownloadStatus.failed
                ? 'No space left on device'
                : null,
          );
          repository.push([updated]);
          await tester.pumpAndSettle();

          expect(tester.getRect(row).size, initialRowRect.size);
          expect(tester.getRect(action).size, const Size(48, 48));
          if (status != DownloadStatus.completed) {
            final trailingLabel = find.descendant(
              of: row,
              matching: find.text(
                status == DownloadStatus.downloading
                    ? '50%'
                    : switch (status) {
                        DownloadStatus.queued => 'Queued',
                        DownloadStatus.paused => 'Paused',
                        DownloadStatus.failed => 'Failed',
                        _ => throw StateError('Unexpected active status'),
                      },
              ),
            );
            expect(
              tester.getRect(trailingLabel).right,
              closeTo(tester.getRect(action).left - 8, .1),
              reason: '$status detail should align before the fixed action',
            );
          }
          expect(
            find.descendant(of: row, matching: find.byType(BayerMasked)),
            findsNothing,
          );
          expect(
            find.descendant(of: row, matching: find.byType(SegmentedBar)),
            findsNothing,
          );
          if (status == DownloadStatus.downloading) {
            expect(
              find.descendant(of: row, matching: find.text('50%')),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: row,
                matching: find.textContaining('300.0 MB / 600.0 MB'),
              ),
              findsNothing,
            );
          }
        }

        final downloading = initial.copyWith(
          status: DownloadStatus.downloading,
          downloadedBytes: 300 * 1024 * 1024,
        );
        repository.push([downloading]);
        await tester.pumpAndSettle();
        final beforeProgressUpdate = tester.getRect(row);
        repository.push([
          downloading.copyWith(downloadedBytes: 400 * 1024 * 1024),
        ]);
        await tester.pump();

        expect(
          find.descendant(of: row, matching: find.byType(BayerMasked)),
          findsNothing,
        );
        expect(tester.getRect(row), beforeProgressUpdate);
        expect(tester.getRect(action), initialActionRect);
      });
    });

    testWidgets('a long watch position fits a narrow row at large text', (
      tester,
    ) async {
      await _withTargetPlatform(TargetPlatform.android, () async {
        setTestWindowSize(tester, const Size(280, 844));
        tester.platformDispatcher.textScaleFactorTestValue = 3.2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.runAsync(
          () =>
              (FontLoader('Geist Mono')..addFont(
                    rootBundle.load('assets/fonts/GeistMono-Regular.ttf'),
                  ))
                  .load(),
        );
        final item = download(
          status: DownloadStatus.paused,
        ).copyWith(fileName: List.filled(8, 'Long unmatched filename ').join());
        final repository = _ScriptedDownloadsRepository([item]);
        final progress = WatchProgress(
          torrentKey: sourceProgressKey(item.magnet),
          fileIndex: item.fileIndex,
          fileName: item.fileName,
          magnet: item.magnet,
          sourceTitle: item.sourceTitle,
          position: const Duration(hours: 10),
          duration: const Duration(hours: 24),
          updatedAt: DateTime(2026, 10, 10),
        );
        await tester.pumpWidget(
          testApp(
            MultiBlocProvider(
              providers: [
                BlocProvider(
                  create: (_) =>
                      DownloadManagerCubit(repository: repository)..load(),
                ),
                BlocProvider(
                  create: (_) => WatchProgressCubit(
                    repository: FixedWatchProgressRepository([progress]),
                  )..load(),
                ),
              ],
              child: DownloadTitlePage(
                title: DownloadTitle(downloadTitleKey(item), [item]),
                onWatch: (_) {},
              ),
            ),
            theme: buildAppTheme(brightness: Brightness.dark),
          ),
        );
        await tester.pumpAndSettle();
        final action = find.byKey(const Key('download_action_frieren-6'));
        await tester.scrollUntilVisible(action, 240);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final position = find.descendant(
          of: rowFor(tester, item.id),
          matching: find.text('10:00:00 / 24:00:00'),
        );
        expect(
          tester.getRect(position).right,
          closeTo(tester.getRect(action).left - 8, .1),
        );
        expect(tester.getSize(action), const Size(48, 48));
        repository.push([
          item.copyWith(
            status: DownloadStatus.downloading,
            downloadedBytes: item.totalBytes,
          ),
        ]);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final percent = find.descendant(
          of: rowFor(tester, item.id),
          matching: find.text('100%'),
        );
        final percentText = tester.widget<Text>(percent);
        final percentPainter = TextPainter(
          text: TextSpan(text: percentText.data, style: percentText.style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(tester.element(percent)),
          maxLines: 1,
        )..layout();
        expect(
          tester.getSize(percent).width,
          closeTo(percentPainter.width, .01),
        );
        percentPainter.dispose();
        expect(
          tester.getRect(position).right,
          closeTo(tester.getRect(action).left - 8, .1),
        );
        tester.view.physicalSize = const Size(320, 844);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        repository.push([item]);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final positionText = tester.widget<Text>(position);
        final positionPainter = TextPainter(
          text: TextSpan(text: positionText.data, style: positionText.style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(tester.element(position)),
          maxLines: 1,
        )..layout();
        expect(
          tester.getSize(position).width,
          lessThanOrEqualTo(positionPainter.width),
        );
        positionPainter.dispose();
        await tester.longPress(rowFor(tester, item.id));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('download_status')));
        await tester.pumpAndSettle();
        expect(find.text('10:00:00 / 24:00:00'), findsOneWidget);
        expect(statusText('10:00:00 / 24:00:00'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('status shows transfer ETA without repeating the filename', (
      tester,
    ) async {
      await pump(tester, download());
      expect(find.text('Episode 06'), findsOneWidget);
      await openStatus(tester);

      expect(statusText('Frieren - 06.mkv'), findsNothing);
      expect(statusText('~5 min left'), findsOneWidget);
    });

    testWidgets('title changes animate, but progress and page chrome do not', (
      tester,
    ) async {
      final first = download();
      final repository = _ScriptedDownloadsRepository([first]);
      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(repository: repository)..load(),
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );
      expect(
        find.descendant(
          of: rowFor(tester, first.id),
          matching: find.byType(BayerMasked),
        ),
        findsNothing,
      );
      expect(find.byType(Scrollable), findsOneWidget);
      repository.push([first.copyWith(downloadedBytes: 400 << 20)]);
      await tester.pump();
      expect(
        find.descendant(
          of: rowFor(tester, first.id),
          matching: find.byType(BayerMasked),
        ),
        findsNothing,
      );
      final second = first.copyWith(
        id: 'other',
        animeId: 'other',
        animeTitle: 'Other',
      );
      repository.push([first, second]);
      await tester.pump();
      await tester.pump(DitherTransition.duration ~/ 2);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('download_title_anime:other')),
          matching: find.byType(BayerMasked),
        ),
        findsOneWidget,
      );
      for (final text in ['Frieren', 'Downloads']) {
        expect(
          find.ancestor(
            of: find.text(text),
            matching: find.byType(BayerMasked),
          ),
          findsNothing,
        );
      }
      await tester.pumpAndSettle();
      repository.push([second]);
      await tester.pump();
      await tester.pump(DitherTransition.duration ~/ 2);
      expect(
        find.byKey(const ValueKey('download_title_anime:52991')),
        findsOneWidget,
        reason: 'the removed title is still dissolving',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('download_title_anime:52991')),
        findsNothing,
      );
      expect(find.byType(Scrollable), findsOneWidget);
    });

    testWidgets('episode rows animate only when added or removed', (
      tester,
    ) async {
      final first = download();
      final repository = await pump(tester, first);
      expect(
        find.descendant(
          of: rowFor(tester, first.id),
          matching: find.byType(BayerMasked),
        ),
        findsNothing,
      );
      repository.push([first.copyWith(downloadedBytes: 400 << 20)]);
      await tester.pump();
      expect(
        find.descendant(
          of: rowFor(tester, first.id),
          matching: find.byType(BayerMasked),
        ),
        findsNothing,
      );
      await tester.longPress(find.text('Episode 06'));
      await tester.pumpAndSettle();
      repository.push([first.copyWith(downloadedBytes: 410 << 20)]);
      await tester.pump();
      expect(find.byKey(const Key('download_delete')), findsOneWidget);
      expect(
        find.descendant(
          of: rowFor(tester, first.id),
          matching: find.byType(BayerMasked),
        ),
        findsNothing,
      );
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      final second = first.copyWith(
        id: 'frieren-7',
        fileIndex: 6,
        fileName: 'Frieren - 07.mkv',
      );
      repository.push([first, second]);
      await tester.pump();
      await tester.pump(DitherTransition.duration ~/ 2);
      expect(
        find.ancestor(
          of: find.text('Episode 07'),
          matching: find.byType(BayerMasked),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('Episode 06'),
          matching: find.byType(BayerMasked),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      repository.push([second]);
      await tester.pump();
      await tester.pump(DitherTransition.duration ~/ 2);
      expect(find.text('Episode 06'), findsOneWidget);
      expect(
        find.ancestor(
          of: find.text('Frieren batch'),
          matching: find.byType(BayerMasked),
        ),
        findsNothing,
      );
      await tester.pumpAndSettle();
      expect(find.text('Episode 06'), findsNothing);
      expect(find.text('Episode 07'), findsOneWidget);
    });

    testWidgets(
      'without motion the last title leaves for the empty state at once',
      (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        final first = download();
        final repository = _ScriptedDownloadsRepository([first]);
        await _pumpApp(
          tester,
          BlocProvider(
            create: (_) => DownloadManagerCubit(repository: repository)..load(),
            child: DownloadManagerPage(
              onOpenTitle: (_) {},
              onWatch: (_) {},
              onBrowseCatalog: () {},
            ),
          ),
        );
        expect(
          MediaQuery.disableAnimationsOf(
            tester.element(
              find.byKey(const ValueKey('download_title_anime:52991')),
            ),
          ),
          isTrue,
        );
        repository.push([]);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('download_title_anime:52991')),
          findsNothing,
        );
        expect(find.text('Browse the catalog'), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);
        repository.push([first]);
        await tester.pumpAndSettle();
        expect(find.text('Browse the catalog'), findsNothing);
        expect(
          find.byKey(const ValueKey('download_title_anime:52991')),
          findsOneWidget,
        );
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets('status gives speed and sizes in full', (tester) async {
      await pump(tester, download(rate: (12.3 * 1024 * 1024).round()));
      await openStatus(tester);

      expect(statusText('12 MB/s'), findsOneWidget);
      expect(statusText('12.3'), findsNothing);
      expect(statusText('300.0 MB / 600.0 MB'), findsOneWidget);
    });

    testWidgets('status names a missing swarm instead of zero speed', (
      tester,
    ) async {
      await pump(tester, download(rate: 0, peers: 0));
      await openStatus(tester);

      expect(statusText('no peers yet'), findsOneWidget);
      expect(statusText('left'), findsNothing);
    });

    testWidgets(
      'status has online estimates and speed but no requested quality',
      (tester) async {
        await pump(
          tester,
          download(
            peers: 0,
            quality: 1080,
            magnet: 'online:anilibria/9542?anime=52991',
          ),
        );
        await openStatus(tester);

        expect(statusText('no peers yet'), findsNothing);
        expect(statusText('300.0 MB / ~600.0 MB'), findsOneWidget);
        expect(statusText('MB/s'), findsOneWidget);
        expect(statusText('1080p'), findsNothing);
      },
    );

    testWidgets(
      'an active online episode with unknown size shows no fake zero',
      (tester) async {
        await pump(
          tester,
          download(
            status: DownloadStatus.downloading,
            downloaded: 0,
            rate: 0,
            peers: 0,
            total: 0,
            magnet: 'online:anilibria/9542?anime=52991',
          ),
        );

        expect(find.text('Downloading'), findsOneWidget);
        final row = rowFor(tester, 'frieren-6');
        expect(
          find.descendant(of: row, matching: find.textContaining('0%')),
          findsNothing,
        );
        expect(
          find.descendant(of: row, matching: find.textContaining('0 B')),
          findsNothing,
        );
        await openStatus(tester);

        // Unknown size must not become a fake zero size or zero-percent value.
        expect(
          find.descendant(
            of: find.byKey(const Key('download_status_dialog')),
            matching: find.text('0 B'),
          ),
          findsNothing,
        );
        expect(statusText('0%'), findsNothing);
        expect(statusText('~'), findsNothing);
      },
    );

    testWidgets('paused watch history and live info survive the page scope', (
      tester,
    ) async {
      final item = download(status: DownloadStatus.paused);
      final repository = _ScriptedDownloadsRepository([item]);
      final watchProgress = WatchProgress(
        torrentKey: sourceProgressKey(item.magnet),
        fileIndex: item.fileIndex,
        fileName: item.fileName,
        magnet: item.magnet,
        sourceTitle: item.sourceTitle,
        position: const Duration(minutes: 12, seconds: 34),
        duration: const Duration(minutes: 24),
        updatedAt: DateTime(2026, 10, 10),
      );

      await _pumpApp(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) =>
                  DownloadManagerCubit(repository: repository)..load(),
            ),
            BlocProvider(
              create: (_) => WatchProgressCubit(
                repository: FixedWatchProgressRepository([watchProgress]),
              )..load(),
            ),
          ],
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            titleKey: downloadTitleKey(item),
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );

      final row = rowFor(tester, item.id);
      expect(
        find.descendant(of: row, matching: find.text('12:34 / 24:00')),
        findsOneWidget,
      );

      await openStatus(tester);
      expect(find.text('12:34 / 24:00'), findsOneWidget);
      expect(statusText('12:34 / 24:00'), findsNothing);
      expect(statusText('300.0 MB / 600.0 MB'), findsOneWidget);

      repository.push([item.copyWith(downloadedBytes: 400 * 1024 * 1024)]);
      await tester.pumpAndSettle();
      expect(statusText('400.0 MB / 600.0 MB'), findsOneWidget);
      expect(statusText('300.0 MB / 600.0 MB'), findsNothing);
      expect(statusText('12:34 / 24:00'), findsNothing);

      repository.push([]);
      await tester.pumpAndSettle();
      expect(find.byType(FocusableListRow), findsNothing);
      expect(statusText('No episodes remain on this device.'), findsOneWidget);
    });

    testWidgets('unknown watch duration shows only the current position', (
      tester,
    ) async {
      final item = download(status: DownloadStatus.paused);
      final progress = WatchProgress(
        torrentKey: sourceProgressKey(item.magnet),
        fileIndex: item.fileIndex,
        fileName: item.fileName,
        magnet: item.magnet,
        sourceTitle: item.sourceTitle,
        position: const Duration(minutes: 12, seconds: 34),
        duration: Duration.zero,
        updatedAt: DateTime(2026, 10, 10),
      );

      await _pumpApp(
        tester,
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => DownloadManagerCubit(
                repository: _ScriptedDownloadsRepository([item]),
              )..load(),
            ),
            BlocProvider(
              create: (_) => WatchProgressCubit(
                repository: FixedWatchProgressRepository([progress]),
              )..load(),
            ),
          ],
          child: DownloadManagerPage(
            onOpenTitle: (_) {},
            titleKey: downloadTitleKey(item),
            onWatch: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      );

      final row = rowFor(tester, item.id);
      expect(
        find.descendant(of: row, matching: find.text('12:34')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('/ 0:00')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('status for a queued file shows its known size', (
      tester,
    ) async {
      await pump(
        tester,
        download(status: DownloadStatus.queued, downloaded: 0, rate: 0),
      );
      await openStatus(tester);

      expect(statusText('0 B /'), findsNothing);
      expect(statusText('600'), findsOneWidget);
    });

    testWidgets('status keeps the failure reason and next step', (
      tester,
    ) async {
      await pump(
        tester,
        download(
          status: DownloadStatus.failed,
          error: 'No space left on device',
        ),
      );
      await openStatus(tester);

      expect(
        statusText('The device ran out of space. Free some up and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('status explains that retry resumes a lost video server', (
      tester,
    ) async {
      await pump(
        tester,
        download(
          status: DownloadStatus.failed,
          magnet: 'online:anilibria/9542?anime=52991',
          error: downloadConnectionLostMessage,
        ),
      );
      await openStatus(tester);

      expect(
        statusText(
          'The video server stopped answering. '
          'Try again to pick up where it stopped.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('opens its menu on a long press and a right click', (
      tester,
    ) async {
      await pump(tester, download());

      await tester.longPress(find.text('Episode 06'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download_status')), findsOneWidget);
      expect(find.byKey(const Key('download_delete')), findsOneWidget);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download_delete')), findsNothing);

      await tester.tap(find.text('Episode 06'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download_status')), findsOneWidget);
      expect(find.byKey(const Key('download_delete')), findsOneWidget);
    });

    testWidgets('completed downloads offer deletion without status details', (
      tester,
    ) async {
      await pump(
        tester,
        download(
          status: DownloadStatus.completed,
          downloaded: 600 * 1024 * 1024,
        ),
      );

      await tester.longPress(find.text('Episode 06'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('download_delete')), findsOneWidget);
      expect(find.byKey(const Key('download_status')), findsNothing);
    });

    testWidgets('asks to delete on the Delete key', (tester) async {
      await pump(tester, download());

      Focus.of(tester.element(find.text('Episode 06'))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
    });

    testWidgets('announces a finished download', (tester) async {
      final announced = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockDecodedMessageHandler<dynamic>(
        SystemChannels.accessibility,
        (message) async {
          final event = message as Map;
          if (event['type'] == 'announce') {
            announced.add((event['data'] as Map)['message'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => messenger.setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        ),
      );
      final repository = await pump(tester, download());

      repository.push([
        download(status: DownloadStatus.completed, downloaded: 600 << 20),
      ]);
      await tester.pumpAndSettle();

      expect(announced, ['Downloaded: Frieren, Episode 06']);
    });
  });

  for (final deletable in const [true, false]) {
    testWidgets(
      deletable
          ? 'a deleted download leaves without a message'
          : 'a download that cannot be deleted says so',
      (tester) async {
        final repository = await _repositoryWithDownloads(
          count: 1,
          deletable: deletable,
        );
        await _pumpApp(
          tester,
          BlocProvider(
            create: (_) => DownloadManagerCubit(repository: repository)..load(),
            child: DownloadManagerPage(
              onOpenTitle: (_) {},
              titleKey: 'anime:5114',
              onWatch: (_) {},
              onBrowseCatalog: () {},
            ),
          ),
        );

        await tester.longPress(find.byType(FocusableListRow));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('download_delete')));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Unable to delete the files. Close the file if it is open and '
            'try again',
          ),
          deletable ? findsNothing : findsOneWidget,
        );
      },
    );
  }

  group('downloadTitles', () {
    DownloadItem item(
      String id,
      String title,
      String file,
      DownloadStatus status,
      int hour,
    ) => DownloadItem(
      id: id,
      animeId: title,
      animeTitle: title,
      sourceTitle: title,
      magnet: 'magnet:?xt=urn:btih:$id',
      fileIndex: 0,
      fileName: file,
      relativePath: file,
      localPath: file,
      totalBytes: 1,
      downloadedBytes: 1,
      downloadRateBytesPerSecond: 0,
      peers: 0,
      status: status,
      createdAt: DateTime(2026, 10, 10, hour),
    );

    test(
      'names do not merge titles and unlinked releases keep their identity',
      () {
        final first = item('a', 'Same name', '01', DownloadStatus.completed, 1);
        final titles = downloadTitles([
          first.copyWith(animeId: '1'),
          first.copyWith(id: 'b', animeId: '2'),
          first.copyWith(id: 'c', animeId: '', magnet: 'online:anilibria/42'),
          first.copyWith(
            id: 'd',
            animeId: '',
            magnet: 'online:anilibria/42?anime=1',
          ),
        ]);
        expect(
          titles.map((title) => title.key),
          unorderedEquals(['anime:1', 'anime:2', 'online:anilibria/42']),
        );
        expect(
          titles.singleWhere((title) => title.key.startsWith('online:')).items,
          hasLength(2),
        );
      },
    );

    test('active titles stay together across episode statuses', () {
      final ordered = downloadTitles([
        item(
          'k18',
          'Kusuriya',
          'Kusuriya - 18.mkv',
          DownloadStatus.completed,
          3,
        ),
        item('f', 'Frieren', 'Frieren - 06.mkv', DownloadStatus.downloading, 1),
        item('k17', 'Kusuriya', 'Kusuriya - 17.mkv', DownloadStatus.queued, 4),
        item('a', 'AoT', 'AoT - 01.mkv', DownloadStatus.completed, 2),
      ]);

      expect(ordered.map((title) => title.name), [
        'Kusuriya',
        'Frieren',
        'AoT',
      ]);
      expect(ordered.first.items, hasLength(2));
    });
  });

  group('failures', () {
    test('the engine’s words become a reason to act on', () {
      expect(
        downloadFailureFrom('No space left on device'),
        DownloadFailure.noSpace,
      );
      expect(
        downloadFailureFrom('There is not enough space on the disk.'),
        DownloadFailure.noSpace,
      );
      expect(
        downloadFailureFrom('Access is denied.'),
        DownloadFailure.noAccess,
      );
      expect(
        downloadFailureFrom(downloadFileMissingMessage),
        DownloadFailure.fileMissing,
      );
      expect(
        downloadFailureFrom(downloadCouldNotStartMessage),
        DownloadFailure.couldNotStart,
      );
      expect(downloadFailureFrom('tracker timed out'), DownloadFailure.other);
    });
  });
}

Future<void> _pumpApp(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(testApp(home));
  await tester.pumpAndSettle();
}

Future<void> _withTargetPlatform(
  TargetPlatform platform,
  Future<void> Function() run,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await run();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

DownloadItem _libraryDownload({
  required String id,
  required String animeId,
  required String animeTitle,
  required String fileName,
  required DownloadStatus status,
  required DateTime createdAt,
}) => DownloadItem(
  id: id,
  animeId: animeId,
  animeTitle: animeTitle,
  sourceTitle: '$animeTitle release',
  magnet: 'magnet:?xt=urn:btih:$animeId',
  fileIndex: 0,
  fileName: fileName,
  relativePath: fileName,
  localPath: fileName,
  totalBytes: 100,
  downloadedBytes: status == DownloadStatus.completed ? 100 : 50,
  downloadRateBytesPerSecond: 10,
  peers: 2,
  status: status,
  createdAt: createdAt,
  posterUrl: 'https://example.test/$animeId.jpg',
);

Future<MockDownloadsRepository> _repositoryWithDownloads({
  required int count,
  bool deletable = true,
}) async {
  final repository = deletable
      ? MockDownloadsRepository()
      : _LockedDownloadsRepository();
  const source = PreparedDownloadSource(sourceToken: 'mock-source', files: []);
  for (var index = 0; index < count; index++) {
    await repository.enqueueDownload(
      source: source,
      file: DownloadableFile(
        index: index,
        name: 'episode-0$index.mkv',
        relativePath: 'episode-0$index.mkv',
        size: 734003200,
      ),
      animeId: '5114',
      animeTitle: 'Fullmetal Alchemist: Brotherhood',
      sourceTitle: '[Mock] Fullmetal Alchemist: Brotherhood Batch',
    );
  }
  return repository;
}

/// Files that stay open elsewhere, so they cannot be removed.
class _LockedDownloadsRepository extends MockDownloadsRepository {
  @override
  Future<bool> delete({required String id}) async => false;
}

/// Hands the screen exactly the downloads a test describes.
class _ScriptedDownloadsRepository extends MockDownloadsRepository {
  _ScriptedDownloadsRepository(this._items);

  final _changes = StreamController<List<DownloadItem>>.broadcast();
  List<DownloadItem> _items;

  void push(List<DownloadItem> items) => _changes.add(_items = items);

  @override
  Stream<List<DownloadItem>> watchDownloads() async* {
    yield _items;
    yield* _changes.stream;
  }
}
