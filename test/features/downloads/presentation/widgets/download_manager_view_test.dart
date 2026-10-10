import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/downloads/presentation/pages/download_manager_page.dart';
import 'package:iris/features/downloads/presentation/pages/download_selection_page.dart';
import 'package:iris/features/downloads/presentation/widgets/download_manager_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';

import '../../../../helpers/test_window.dart';

void main() {
  for (final entry in TestWindowSizes.all.entries) {
    // The sidebar takes its share, so only desktop windows fit both panes.
    // Content of 840 dp and up puts storage in a side pane.
    final isWide = entry.value.width >= 900;

    testWidgets('download manager adapts panes on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);
      final repository = await _repositoryWithDownloads(count: 3);
      await repository.pause(id: 'mock-1');

      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) => DownloadManagerCubit(repository: repository)..load(),
          child: DownloadManagerPage(onWatch: (_) {}, onBrowseCatalog: () {}),
        ),
      );

      final storage = tester.getRect(find.text('APP STORAGE'));
      final firstFile = tester.getRect(find.text('episode-00'));
      if (isWide) {
        expect(storage.left, greaterThan(firstFile.right));
      } else {
        // The files come first; storage follows them.
        expect(storage.top, greaterThan(firstFile.bottom));
      }
      expect(find.textContaining('PAUSED', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('download manager empty state fits on ${entry.key}', (
      tester,
    ) async {
      setTestWindowSize(tester, entry.value);

      await _pumpApp(
        tester,
        BlocProvider(
          create: (_) =>
              DownloadManagerCubit(repository: MockDownloadsRepository())
                ..load(),
          child: DownloadManagerPage(onWatch: (_) {}, onBrowseCatalog: () {}),
        ),
      );

      expect(
        find.text(
          'Episodes download from a title’s sources, or from Torrents.',
        ),
        findsOneWidget,
      );
      expect(find.text('Browse the catalog'), findsOneWidget);
      expect(tester.takeException(), isNull);
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
          child: DownloadSelectionPage(args: args, onQueued: (_) {}),
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
        child: DownloadManagerPage(onWatch: (_) {}, onBrowseCatalog: () {}),
      ),
    );

    expect(
      find.bySemanticsLabel(
        RegExp('^Resume: Fullmetal Alchemist: Brotherhood, '),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp('^More actions: Fullmetal Alchemist: Brotherhood, '),
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
      String? error,
    }) => DownloadItem(
      id: 'frieren-6',
      animeId: '52991',
      animeTitle: 'Frieren',
      sourceTitle: 'Frieren batch',
      magnet: 'magnet:?xt=urn:btih:frieren',
      fileIndex: 5,
      fileName: 'Frieren - 06.mkv',
      relativePath: 'Frieren - 06.mkv',
      localPath: 'Frieren - 06.mkv',
      totalBytes: 600 * 1024 * 1024,
      downloadedBytes: downloaded,
      downloadRateBytesPerSecond: rate,
      peers: peers,
      status: status,
      createdAt: DateTime(2026, 10, 10),
      errorMessage: error,
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
          child: DownloadManagerPage(onWatch: (_) {}, onBrowseCatalog: () {}),
        ),
      );
      return repository;
    }

    testWidgets('says the episode and how long is left', (tester) async {
      await pump(tester, download());

      expect(find.text('Episode 6'), findsOneWidget);
      expect(find.text('Frieren - 06.mkv'), findsNothing);
      expect(find.textContaining('~5 min left'), findsOneWidget);
    });

    testWidgets('names a missing swarm instead of a zero speed', (
      tester,
    ) async {
      await pump(tester, download(rate: 0, peers: 0));

      expect(find.textContaining('no peers yet'), findsOneWidget);
      expect(find.textContaining('left'), findsNothing);
    });

    testWidgets('a queued file shows only its size', (tester) async {
      await pump(
        tester,
        download(status: DownloadStatus.queued, downloaded: 0, rate: 0),
      );

      expect(find.textContaining('0 B /'), findsNothing);
      expect(find.textContaining('600'), findsOneWidget);
    });

    testWidgets('a failure says what to do about it', (tester) async {
      await pump(
        tester,
        download(
          status: DownloadStatus.failed,
          error: 'No space left on device',
        ),
      );

      expect(
        find.text('The device ran out of space. Free some up and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('opens its menu on a long press and a right click', (
      tester,
    ) async {
      await pump(tester, download());

      await tester.longPress(find.text('Episode 6'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download_delete')), findsOneWidget);

      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download_delete')), findsNothing);

      await tester.tap(find.text('Episode 6'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('download_delete')), findsOneWidget);
    });

    testWidgets('asks to delete on the Delete key', (tester) async {
      await pump(tester, download());

      Focus.of(tester.element(find.text('Episode 6'))).requestFocus();
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

      expect(announced, ['Downloaded: Frieren, Episode 6']);
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
            child: DownloadManagerPage(onWatch: (_) {}, onBrowseCatalog: () {}),
          ),
        );

        await tester.tap(find.byTooltip('More actions'));
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

  group('orderedDownloads', () {
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

    test('active first; a title stays together in episode order', () {
      final ordered = orderedDownloads([
        item(
          'k18',
          'Kusuriya',
          'Kusuriya - 18.mkv',
          DownloadStatus.completed,
          3,
        ),
        item('f', 'Frieren', 'Frieren - 06.mkv', DownloadStatus.downloading, 1),
        item(
          'k17',
          'Kusuriya',
          'Kusuriya - 17.mkv',
          DownloadStatus.completed,
          4,
        ),
        item('a', 'AoT', 'AoT - 01.mkv', DownloadStatus.completed, 2),
      ]);

      expect([for (final item in ordered) item.id], ['f', 'k17', 'k18', 'a']);
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
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

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
        extension: 'mkv',
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
  Future<List<DownloadItem>> currentDownloads() async => _items;

  @override
  Stream<List<DownloadItem>> watchDownloads() async* {
    yield _items;
    yield* _changes.stream;
  }
}
