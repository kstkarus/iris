import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/widgets/player_episode_cards.dart';
import 'package:iris/features/player/presentation/widgets/player_episode_grid.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_list.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';

enum _Layout { list, grid, drawer }

void main() {
  for (final layout in _Layout.values) {
    testWidgets('${layout.name} lazily reveals a distant episode', (
      tester,
    ) async {
      setTestWindowSize(tester, const Size(360, 290));
      final files = List.generate(
        800,
        (position) => PlayerVideoFile(
          index: position * 3,
          name: 'episode.mkv',
          size: 1024 * 1024,
          extension: 'mkv',
          title: position < 100 || position > 650
              ? 'Short title'
              : 'A long episode title that takes more than a single line',
        ),
      );
      final keyPrefix = layout == _Layout.drawer
          ? 'player_episode_card_'
          : 'player_episode_';

      Future<void> show(int position) {
        final fileIndex = files[position].index;
        final episodes = switch (layout) {
          _Layout.list => PlayerEpisodesList(
            files: files,
            currentFileIndex: fileIndex,
            progressByFile: const {},
            onSelected: (_) {},
          ),
          _Layout.grid => PlayerEpisodeGrid(
            files: files,
            highlightedFileIndex: fileIndex,
            progressByFile: const {},
            listed: const {},
            onSelected: (_) {},
          ),
          _Layout.drawer => PlayerEpisodeCards(
            files: files,
            currentFileIndex: fileIndex,
            progressByFile: const {},
            onSelected: (_) {},
          ),
        };
        return tester.pumpWidget(
          testApp(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Scaffold(body: episodes),
            ),
          ),
        );
      }

      void expectLazy() {
        final rows = find.byWidgetPredicate(
          (widget) => switch (widget.key) {
            ValueKey<String>(:final value) => value.startsWith(keyPrefix),
            _ => false,
          },
        );
        expect(rows.evaluate().length, inInclusiveRange(1, files.length ~/ 4));
      }

      void expectVisible(int position) {
        final key = ValueKey('$keyPrefix${files[position].index}');
        final row = tester.getRect(find.byKey(key));
        final viewport = tester.getRect(find.byType(Scrollable));
        expect(row.top, greaterThanOrEqualTo(viewport.top));
        expect(row.bottom, lessThanOrEqualTo(viewport.bottom));
      }

      await show(400);
      expectLazy();
      await tester.pumpAndSettle();
      expectVisible(400);
      expectLazy();

      for (final position in [files.length - 1, 4]) {
        await show(position);
        await tester.pumpAndSettle();
        expectVisible(position);
        expectLazy();
      }
    });
  }
}
