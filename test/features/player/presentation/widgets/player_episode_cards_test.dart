import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/widgets/player_episode_cards.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_drawer.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

PlayerVideoFile _file(int index, String name) =>
    PlayerVideoFile(index: index, name: name, size: 1, extension: 'mkv');

WatchProgress _progress(int fileIndex, Duration position) => WatchProgress(
  torrentKey: 'key',
  fileIndex: fileIndex,
  fileName: 'file.mkv',
  magnet: 'magnet:?xt=urn:btih:key',
  sourceTitle: 'Release',
  position: position,
  duration: const Duration(minutes: 24),
  updatedAt: DateTime(2026),
);

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(brightness: Brightness.dark),
  home: Scaffold(body: child),
);

void main() {
  group('distinctEpisodeNames', () {
    test('keeps what a file names beyond the series and its number', () {
      final names = distinctEpisodeNames([
        _file(0, "[Group] Frieren - 01 - The Journey's End [1080p].mkv"),
        _file(
          1,
          '[Group] Frieren - 02 - It Didn’t Have to Be Magic [1080p].mkv',
        ),
      ]);

      expect(names, {0: "The Journey's End", 1: 'It Didn’t Have to Be Magic'});
    });

    test('gives nothing for files told apart by their number only', () {
      expect(
        distinctEpisodeNames([
          _file(0, '[Group] Death Note 01 [BDRip 1080p].mkv'),
          _file(1, '[Group] Death Note 02 [BDRip 1080p].mkv'),
          _file(2, '[Group] Death Note 19 [BDRip 1080p].mkv'),
        ]),
        isEmpty,
      );
      expect(distinctEpisodeNames([_file(0, 'Movie.mkv')]), isEmpty);
    });
  });

  testWidgets('marks the playing card and the progress of the others', (
    tester,
  ) async {
    PlayerVideoFile? selected;
    await tester.pumpWidget(
      _wrap(
        PlayerEpisodeCards(
          files: [
            _file(0, 'Show - 01.mkv'),
            _file(1, 'Show - 02.mkv'),
            _file(2, 'Show - 03.mkv'),
          ],
          currentFileIndex: 1,
          progressByFile: {
            0: _progress(0, const Duration(minutes: 24)),
            2: _progress(2, const Duration(minutes: 4)),
          },
          onSelected: (file) => selected = file,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('NOW PLAYING'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is PixelIcon && widget.glyph == PixelGlyph.check,
      ),
      findsOneWidget,
    );
    expect(find.text('20:00 left'), findsOneWidget);
    expect(find.byType(SegmentedBar), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('player_episode_card_1')));
    expect(selected, isNull, reason: 'the playing file is not picked again');
    await tester.tap(find.byKey(const ValueKey('player_episode_card_2')));
    expect(selected?.index, 2);
  });

  testWidgets('heads the drawer with its caption and closes it', (
    tester,
  ) async {
    var closed = 0;
    await tester.pumpWidget(
      _wrap(
        PlayerEpisodesDrawer(
          onClose: () => closed++,
          caption: 'Release · 3 episodes',
          builder: (context, close) => const SizedBox.expand(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Episodes'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('player_episodes_caption')))
          .data,
      'Release · 3 episodes',
    );

    await tester.tap(find.byKey(const Key('player_episodes_close_button')));
    await tester.tapAt(const Offset(20, 300));
    expect(closed, 2);
  });
}
