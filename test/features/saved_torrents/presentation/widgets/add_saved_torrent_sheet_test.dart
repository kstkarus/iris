import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/saved_torrents/domain/repositories/saved_torrents_repository.dart';
import 'package:iris/features/saved_torrents/presentation/widgets/add_saved_torrent_sheet.dart';
import 'package:iris/shared/torrent/torrent_file_picker.dart';

import '../../../../helpers/bencode.dart';
import '../../../../helpers/test_app.dart';

const _magnet =
    'magnet:?xt=urn:btih:065c4691de84f964e143103b3bd0de17be5bfd0a'
    '&dn=Frieren%20BD&xl=2048';

void main() {
  late List<String> saved;

  Future<void> pumpForm(
    WidgetTester tester, {
    String? initialMagnet,
    TorrentFilePicker? pickFile,
  }) async {
    saved = [];
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: AddSavedTorrentForm(
            onSave: (magnet) async {
              saved.add(magnet);
              return const SaveTorrentInvalidMagnet();
            },
            initialMagnet: initialMagnet,
            pickFile: pickFile ?? () async => null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool canAdd(WidgetTester tester) => tester
      .widget<FilledButton>(find.byKey(AddSavedTorrentForm.saveButtonKey))
      .enabled;

  testWidgets('a link gives way to what it is, and back when cleared', (
    tester,
  ) async {
    await pumpForm(tester);
    expect(canAdd(tester), isFalse);

    await tester.enterText(
      find.byKey(AddSavedTorrentForm.magnetFieldKey),
      _magnet,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      find.byKey(AddSavedTorrentForm.draftKey),
      findsOneWidget,
      reason: 'developing where the field was',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(AddSavedTorrentForm.magnetFieldKey), findsNothing);
    expect(find.text('Frieren BD'), findsOneWidget);
    expect(find.text('2 KB · from a link'), findsOneWidget);
    expect(canAdd(tester), isTrue);

    await tester.tap(find.byKey(AddSavedTorrentForm.clearDraftKey));
    await tester.pumpAndSettle();
    expect(find.byKey(AddSavedTorrentForm.draftKey), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(AddSavedTorrentForm.magnetFieldKey))
          .controller!
          .text,
      isEmpty,
    );
    expect(canAdd(tester), isFalse);
  });

  testWidgets('adds the link of the torrent shown', (tester) async {
    await pumpForm(tester, initialMagnet: _magnet);

    expect(find.text('Frieren BD'), findsOneWidget, reason: 'a paste');
    await tester.tap(find.byKey(AddSavedTorrentForm.saveButtonKey));
    await tester.pumpAndSettle();

    expect(saved, [_magnet]);
  });

  testWidgets('says a text is not a link once the user is done with it', (
    tester,
  ) async {
    await pumpForm(tester);
    await tester.enterText(
      find.byKey(AddSavedTorrentForm.magnetFieldKey),
      'magnet:?xt=urn:btih:nope',
    );
    await tester.pump();
    expect(find.textContaining('Not a magnet link'), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.textContaining('Not a magnet link'), findsOneWidget);
  });

  testWidgets('a paste that is not a link starts an empty form', (
    tester,
  ) async {
    await pumpForm(tester, initialMagnet: 'some copied words');

    expect(find.byKey(AddSavedTorrentForm.draftKey), findsNothing);
    expect(find.textContaining('Not a magnet link'), findsNothing);
  });

  testWidgets('a file is read for its torrent, or said not to be one', (
    tester,
  ) async {
    var bytes = Uint8List.fromList(utf8.encode('not a torrent'));
    await pumpForm(tester, pickFile: () async => bytes);

    await tester.tap(find.byKey(AddSavedTorrentForm.fileButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('This file is not a torrent.'), findsOneWidget);

    bytes = torrentFileBytes('Frieren [BD]', length: 3 * 1024 * 1024);
    await tester.tap(find.byKey(AddSavedTorrentForm.fileButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('Frieren [BD]'), findsOneWidget);
    expect(find.text('1 file · 3.0 MB · from a file'), findsOneWidget);

    await tester.tap(find.byKey(AddSavedTorrentForm.saveButtonKey));
    await tester.pumpAndSettle();
    expect(saved.single, startsWith('magnet:?xt=urn:btih:'));
    expect(saved.single, contains('dn=Frieren+%5BBD%5D'));
  });
}
