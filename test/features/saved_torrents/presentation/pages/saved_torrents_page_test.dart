import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/saved_torrents/data/repositories/shared_preferences_saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/domain/entities/saved_torrent.dart';
import 'package:iris/features/saved_torrents/presentation/cubit/saved_torrents_cubit.dart';
import 'package:iris/features/saved_torrents/presentation/pages/saved_torrents_page.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/add_saved_torrent_sheet.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

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

  Future<void> pumpPage(WidgetTester tester, {Size? size}) async {
    if (size != null) setTestWindowSize(tester, size);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ru'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider(
          create: (_) => SavedTorrentsCubit(
            repository: repository,
            highlightDuration: const Duration(milliseconds: 10),
          )..load(),
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
    expect(find.text('Добавить magnet'), findsWidgets);
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

    expect(find.text('Раздача сохранена'), findsOneWidget);
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

    expect(find.text('Уже сохранена как «Моя тетрадь»'), findsOneWidget);
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
    await tester.tap(find.byKey(const Key('saved_torrent_download_button')));
    await tester.pumpAndSettle();

    expect(watched, [_hash]);
    expect(downloaded, [_hash]);
    expect(find.textContaining('Открывали'), findsOneWidget);
  });

  testWidgets('renames and deletes from the card menu', (tester) async {
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
    expect(find.text('Удалить «Тетрадь смерти»?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Пока нет сохранённых раздач'), findsOneWidget);
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
