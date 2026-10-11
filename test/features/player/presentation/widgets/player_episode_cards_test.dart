import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/widgets/player_episode_cards.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_drawer.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

import '../../../../helpers/test_app.dart';

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

Widget _wrap(Widget child) => testApp(
  Scaffold(body: child),
  theme: ThemeData(brightness: Brightness.dark),
);

void main() {
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

  testWidgets('lets the keyboard pick a card in the drawer and leaves '
      'Escape to the player', (tester) async {
    final picked = <int>[];
    var escapes = 0;
    var pauses = 0;
    await tester.pumpWidget(
      _wrap(
        // Stands for the player's own keys above the drawer.
        Focus(
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent) return KeyEventResult.ignored;
            if (event.logicalKey == LogicalKeyboardKey.escape) {
              escapes++;
            } else if (event.logicalKey == LogicalKeyboardKey.space) {
              pauses++;
            } else {
              return KeyEventResult.ignored;
            }
            return KeyEventResult.handled;
          },
          child: PlayerEpisodesDrawer(
            onClose: () {},
            builder: (context, close) => PlayerEpisodeCards(
              files: [
                _file(0, 'Show - 01.mkv'),
                _file(1, 'Show - 02.mkv'),
                _file(2, 'Show - 03.mkv'),
              ],
              currentFileIndex: 0,
              progressByFile: const {},
              onSelected: (file) => picked.add(file.index),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    int? focusedCard() {
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused == null) return null;
      for (final index in [0, 1, 2]) {
        final card = find.descendant(
          of: find.byWidget(focused.widget),
          matching: find.byKey(ValueKey('player_episode_card_$index')),
        );
        if (card.evaluate().isNotEmpty) return index;
      }
      return null;
    }

    bool outlined(int index) {
      final box = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(ValueKey('player_episode_card_$index')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      return (box.foregroundDecoration as BoxDecoration?)?.border != null;
    }

    // The close button comes first; the playing card is passed by.
    final reached = <int?>[];
    for (var press = 0; press < 6; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      reached.add(focusedCard());
    }
    expect(reached, containsAll([1, 2]));
    expect(reached, isNot(contains(0)));

    while (focusedCard() != 1) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(outlined(1), isTrue, reason: 'focus shows on the card');
    expect(outlined(2), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(picked, [1]);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focusedCard(), 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(picked, [1, 2]);
    expect(pauses, 0, reason: 'Space picks the card instead');

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(escapes, 1);
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
