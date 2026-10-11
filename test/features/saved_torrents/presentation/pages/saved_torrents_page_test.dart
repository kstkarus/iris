import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/saved_torrents/data/repositories/shared_preferences_saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import 'package:iris/features/saved_torrents/presentation/pages/saved_torrents_page.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/add_saved_torrent_sheet.dart';

import '../../../../helpers/fake_watch_progress_repository.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';

const _hash = '065c4691de84f964e143103b3bd0de17be5bfd0a';
const _magnet = 'magnet:?xt=urn:btih:$_hash&dn=Death%20Note%20S01';

void main() {
  late SharedPreferencesSavedTorrentsRepository repository;
  late List<String> watched;
  late List<String> downloaded;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SharedPreferencesSavedTorrentsRepository(
      await SharedPreferences.getInstance(),
    );
    watched = [];
    downloaded = [];
  });

  tearDown(() => repository.close());

  Future<void> pumpPage(
    WidgetTester tester, {
    Size? size,
    List<WatchProgress> history = const [],
  }) async {
    if (size != null) setTestWindowSize(tester, size);
    await tester.pumpWidget(
      testApp(
        // A new page each time, so a changed platform builds afresh.
        key: UniqueKey(),
        locale: const Locale('ru'),
        MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => SavedTorrentsCubit(
                repository: repository,
                highlightDuration: const Duration(milliseconds: 10),
              )..load(),
            ),
            BlocProvider(
              create: (_) => WatchProgressCubit(
                repository: FixedWatchProgressRepository(history),
              )..load(),
            ),
          ],
          child: SavedTorrentsPage(
            onWatch: (SavedTorrent torrent, {int? autoOpenFileIndex}) =>
                watched.add(torrent.infoHash),
            onDownload: (SavedTorrent torrent) =>
                downloaded.add(torrent.infoHash),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAddSheet(WidgetTester tester) async {
    await tester.tap(find.byKey(SavedTorrentsPage.addButtonKey));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state with an add action', (tester) async {
    await pumpPage(tester);

    expect(find.text('Пока нет сохранённых раздач'), findsOneWidget);
    expect(find.text('Добавить раздачу'), findsWidgets);
  });

  testWidgets('saves a pasted magnet named after dn', (tester) async {
    await pumpPage(tester);
    await openAddSheet(tester);

    await tester.enterText(
      find.byKey(AddSavedTorrentForm.magnetFieldKey),
      _magnet,
    );
    await tester.pump();
    final nameField = tester.widget<TextField>(
      find.byKey(AddSavedTorrentForm.nameFieldKey),
    );
    expect(nameField.controller!.text, 'Death Note S01');

    await tester.tap(find.byKey(AddSavedTorrentForm.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Раздача добавлена'), findsOneWidget);
    expect(find.text('Death Note S01'), findsOneWidget);
    expect(find.textContaining('065c4691'), findsNothing);
  });

  testWidgets('keeps the sheet open and explains an invalid link', (
    tester,
  ) async {
    await pumpPage(tester);
    await openAddSheet(tester);

    await tester.enterText(
      find.byKey(AddSavedTorrentForm.magnetFieldKey),
      'https://example.com',
    );
    await tester.pump();
    await tester.tap(find.byKey(AddSavedTorrentForm.saveButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Это не magnet-ссылка с хэшем раздачи (xt=urn:btih:…).'),
      findsOneWidget,
    );
    expect(find.byKey(AddSavedTorrentForm.magnetFieldKey), findsOneWidget);
  });

  testWidgets('reports a duplicate instead of saving twice', (tester) async {
    await repository.add(magnet: _magnet, title: 'Моя тетрадь');
    await pumpPage(tester);
    await openAddSheet(tester);

    await tester.enterText(
      find.byKey(AddSavedTorrentForm.magnetFieldKey),
      'magnet:?xt=urn:btih:${_hash.toUpperCase()}',
    );
    await tester.pump();
    await tester.tap(find.byKey(AddSavedTorrentForm.saveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Уже добавлена как «Моя тетрадь»'), findsOneWidget);
    expect(find.text('Моя тетрадь'), findsOneWidget);
  });

  testWidgets('pastes from the clipboard button', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, Object?>{'text': _magnet};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpPage(tester);
    await openAddSheet(tester);

    await tester.tap(find.byTooltip('Вставить из буфера'));
    await tester.pumpAndSettle();

    final magnetField = tester.widget<TextField>(
      find.byKey(AddSavedTorrentForm.magnetFieldKey),
    );
    expect(magnetField.controller!.text, _magnet);
  });

  testWidgets('watch and download hand the torrent to navigation', (
    tester,
  ) async {
    await repository.add(magnet: _magnet);
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('saved_torrent_watch_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('saved_torrent_download')));
    await tester.pumpAndSettle();

    expect(watched, [_hash]);
    expect(downloaded, [_hash]);
    expect(find.textContaining('Открывали'), findsOneWidget);
  });

  testWidgets('a long press or a right click opens the row menu', (
    tester,
  ) async {
    await repository.add(magnet: _magnet);
    await pumpPage(tester);
    final row = find.byKey(const Key('saved_torrent_watch_button'));

    await tester.longPress(row);
    await tester.pumpAndSettle();
    expect(find.text('Переименовать'), findsOneWidget);
    expect(watched, isEmpty);

    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.text('Переименовать'), findsNothing);

    await tester.tap(row, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Переименовать'), findsOneWidget);
  });

  testWidgets('a watched torrent shows the episode, not the file name', (
    tester,
  ) async {
    await repository.add(magnet: _magnet);
    await pumpPage(
      tester,
      history: [
        WatchProgress(
          torrentKey: _hash,
          fileIndex: 4,
          fileName: 'Death Note S01/[Group] Death Note - 05 (1080p).mkv',
          magnet: _magnet,
          sourceTitle: 'Death Note S01',
          position: const Duration(minutes: 12, seconds: 31),
          duration: const Duration(minutes: 23, seconds: 40),
          updatedAt: DateTime(2026, 10, 10),
        ),
      ],
    );

    expect(find.text('Серия 5 · 12:31 / 23:40'), findsOneWidget);
    expect(find.textContaining('Death Note - 05'), findsNothing);
    expect(find.textContaining('Добавлена'), findsNothing);
  });

  testWidgets('a finished episode is named, not the whole torrent', (
    tester,
  ) async {
    await repository.add(magnet: _magnet);
    await pumpPage(
      tester,
      history: [
        WatchProgress(
          torrentKey: _hash,
          fileIndex: 6,
          fileName: '[Group] Death Note - 07 (1080p).mkv',
          magnet: _magnet,
          sourceTitle: 'Death Note S01',
          position: const Duration(minutes: 23, seconds: 30),
          duration: const Duration(minutes: 23, seconds: 40),
          updatedAt: DateTime(2026, 10, 10),
        ),
      ],
    );

    expect(find.text('Серия 7 просмотрена'), findsOneWidget);
    expect(find.text('Просмотрено'), findsNothing);
  });

  testWidgets('the paste shortcut is spelled for the platform', (tester) async {
    await pumpPage(tester);
    expect(find.textContaining('из буфера'), findsNothing);

    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await pumpPage(tester);
      expect(find.text('⌘V — добавить раздачу из буфера'), findsOneWidget);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      await pumpPage(tester);
      expect(find.text('Ctrl+V — добавить раздачу из буфера'), findsOneWidget);
    } finally {
      // Reset before the test ends: Flutter checks it before tear-downs.
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('renames, deletes at once and undoes the delete', (tester) async {
    await repository.add(magnet: _magnet);
    await pumpPage(tester);

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Переименовать'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Тетрадь смерти');
    await tester.tap(find.widgetWithText(FilledButton, 'Сохранить'));
    await tester.pumpAndSettle();
    expect(find.text('Тетрадь смерти'), findsOneWidget);

    await tester.tap(find.byTooltip('Ещё'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    // No question first: an undo instead.
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Пока нет сохранённых раздач'), findsOneWidget);
    expect(find.text('Раздача удалена'), findsOneWidget);

    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();
    expect(find.text('Тетрадь смерти'), findsOneWidget);
  });

  testWidgets('the add sheet covers the whole window on phones', (
    tester,
  ) async {
    await pumpPage(tester, size: TestWindowSizes.phone);
    await openAddSheet(tester);

    expect(find.text('Добавить раздачу'), findsWidgets);
    expect(
      tester.widget<BottomSheet>(find.byType(BottomSheet)).showDragHandle,
      isTrue,
    );
  });

  for (final entry in TestWindowSizes.all.entries) {
    testWidgets('lays out without overflow on ${entry.key}', (tester) async {
      for (var index = 0; index < 5; index++) {
        await repository.add(
          magnet:
              'magnet:?xt=urn:btih:${'$index'.padLeft(40, 'a')}'
              '&dn=${Uri.encodeQueryComponent('Very long torrent name ' * 4)}',
        );
      }
      await pumpPage(tester, size: entry.value);

      expect(tester.takeException(), isNull);
      final isCompact = entry.value.width < 600;
      // One add button in the page header on every size; no floating copy.
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byKey(SavedTorrentsPage.addButtonKey), findsOneWidget);

      await openAddSheet(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(Dialog), isCompact ? findsNothing : findsOneWidget);
    });
  }
}
