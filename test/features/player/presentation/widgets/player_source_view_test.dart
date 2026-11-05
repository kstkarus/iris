import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/player_source_view.dart';
import 'package:iris/features/player/presentation/widgets/player_episode_grid.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

import '../../../../helpers/test_app.dart';
import '../../player_test_doubles.dart';

void main() {
  testWidgets('shows loading state while source is being prepared', (
    tester,
  ) async {
    final cubit = FakePlayerSourceCubit(const PlayerSourceLoading());

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(find.text('Preparing torrent files'), findsOneWidget);
  });

  testWidgets('lists files with sizes and opens the tapped one', (
    tester,
  ) async {
    final cubit = FakePlayerSourceCubit(
      const PlayerSourceReady(
        PreparedPlayerSource(
          sessionId: '42',
          files: [
            PlayerVideoFile(
              index: 1,
              name: 'episode-01 - First.mkv',
              size: 734003200,
              extension: 'mkv',
            ),
            PlayerVideoFile(
              index: 2,
              name: 'episode-02 - Second.mp4',
              size: 524288000,
              extension: 'mp4',
            ),
          ],
        ),
      ),
    );

    final selected = <int>[];
    await tester.pumpWidget(
      _wrap(cubit: cubit, onFileSelected: (file) => selected.add(file.index)),
    );

    expect(find.text('episode-01 - First'), findsOneWidget);
    expect(find.text('700.0 MB'), findsOneWidget);
    expect(find.text('episode-02 - Second'), findsOneWidget);
    expect(find.text('500.0 MB'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(find.text('episode-02 - Second'));
    expect(selected, [2]);
  });

  testWidgets('lists online episodes by their own names and lengths', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        cubit: FakePlayerSourceCubit(
          const PlayerSourceReady(
            PreparedPlayerSource(
              sessionId: 'online:anilibria/9542',
              files: [
                PlayerVideoFile(
                  index: 0,
                  name: '01 «Конец приключений»',
                  size: 0,
                  extension: '',
                  episodeNumber: 1,
                  title: '«Конец приключений»',
                  duration: Duration(minutes: 25, seconds: 50),
                ),
                PlayerVideoFile(
                  index: 1,
                  name: '02 «Дело-то вовсе не в магии!»',
                  size: 0,
                  extension: '',
                  episodeNumber: 2,
                  title: '«Дело-то вовсе не в магии!»',
                  duration: Duration(minutes: 26),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('01'), findsOneWidget);
    expect(find.text('«Конец приключений»'), findsOneWidget);
    expect(find.text('«Дело-то вовсе не в магии!»'), findsOneWidget);
    // The name history keeps is not repeated under the title.
    expect(find.text('01 «Конец приключений»'), findsNothing);
    expect(find.text('26 min'), findsNWidgets(2));
    expect(find.text('0 B'), findsNothing);
  });

  testWidgets('an episode without a length shows no size either', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        cubit: FakePlayerSourceCubit(
          const PlayerSourceReady(
            PreparedPlayerSource(
              sessionId: 'online:yummy_anime/10661:AniDUB',
              files: [
                PlayerVideoFile(
                  index: 1,
                  name: '1',
                  size: 0,
                  extension: '',
                  episodeNumber: 1,
                ),
                PlayerVideoFile(
                  index: 100050,
                  name: '0.5',
                  size: 0,
                  extension: '',
                  episodeNumber: 0.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('0 B'), findsNothing);
    expect(find.textContaining('min'), findsNothing);
    // A special is labelled with its own number, not its position.
    expect(find.text('0.5'), findsWidgets);
  });

  testWidgets('says episodes, not torrent files, load for an online release', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        cubit: FakePlayerSourceCubit(const PlayerSourceLoading()),
        isOnline: true,
      ),
    );

    expect(find.text('Loading episodes'), findsOneWidget);
  });

  testWidgets('marks progress and continues the last unfinished file', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _wrap(
        cubit: FakePlayerSourceCubit(
          const PlayerSourceReady(
            PreparedPlayerSource(sessionId: '42', files: _episodes),
          ),
        ),
        progressByFile: {2: _progress(2, 300)},
        onFileSelected: (file) => selected.add(file.index),
      ),
    );

    // The Continue card keeps the time; the grid tile shows its progress bar.
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Stopped at 5:00 of 24:00'), findsOneWidget);

    await tester.tap(find.byKey(PlayerSourceView.continueButtonKey));
    expect(selected, [2]);
  });

  testWidgets('offers the next file after a finished one', (tester) async {
    await tester.pumpWidget(
      _wrap(
        cubit: FakePlayerSourceCubit(
          const PlayerSourceReady(
            PreparedPlayerSource(sessionId: '42', files: _episodes),
          ),
        ),
        progressByFile: {1: _progress(1, 1400)},
      ),
    );

    expect(find.widgetWithText(FilledButton, 'Play next'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('episode-02')),
      findsOneWidget,
    );
    // A mark at the end of the row, not a line of its own.
    expect(find.text('Watched'), findsNothing);
    expect(_watchedMarks, findsOneWidget);
  });

  testWidgets('an online episode named by its number shows the number once', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        cubit: FakePlayerSourceCubit(
          const PlayerSourceReady(
            PreparedPlayerSource(sessionId: '42', files: _online),
          ),
        ),
        progressByFile: {1: _progress(1, 1400)},
        isOnline: true,
      ),
    );

    expect(find.text('01'), findsOneWidget);
    expect(find.text('02'), findsNWidgets(2));
    expect(find.widgetWithText(FilledButton, 'Play next'), findsOneWidget);
  });

  testWidgets('marks what the Shikimori list counts and plays on from it', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        cubit: FakePlayerSourceCubit(
          const PlayerSourceReady(
            PreparedPlayerSource(sessionId: '42', files: _online),
          ),
        ),
        listedEpisodes: 2,
        isOnline: true,
      ),
    );

    expect(_watchedMarks, findsNWidgets(2));
    expect(
      find.descendant(of: find.byType(Card), matching: find.text('03')),
      findsOneWidget,
    );
  });

  testWidgets('progress here shows over the list mark', (tester) async {
    await tester.pumpWidget(
      _wrap(
        cubit: FakePlayerSourceCubit(
          const PlayerSourceReady(
            PreparedPlayerSource(sessionId: '42', files: _online),
          ),
        ),
        progressByFile: {2: _progress(2, 600, minute: 5)},
        listedEpisodes: 2,
        isOnline: true,
      ),
    );

    expect(_watchedMarks, findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
    expect(find.text('Stopped at 10:00 of 24:00'), findsWidgets);
  });

  testWidgets('unnamed episodes use a grid and keep progress and replay', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _wrap(
        cubit: FakePlayerSourceCubit(
          PlayerSourceReady(
            PreparedPlayerSource(
              sessionId: 'online:test',
              files: [
                for (var number = 1; number <= 3; number++)
                  PlayerVideoFile(
                    index: number,
                    name: '$number',
                    size: 0,
                    extension: 'm3u8',
                    episodeNumber: number,
                    title: 'Серия $number',
                  ),
                const PlayerVideoFile(
                  index: 10,
                  name: '12.5',
                  size: 0,
                  extension: 'm3u8',
                  episodeNumber: 12.5,
                ),
              ],
            ),
          ),
        ),
        isOnline: true,
        listedEpisodes: 2,
        progressByFile: {2: _progress(2, 600)},
        onFileSelected: (file) => selected.add(file.index),
      ),
    );
    await tester.pumpAndSettle();

    Finder tile(int index) => find.byKey(ValueKey('player_episode_$index'));
    expect(tester.getTopLeft(tile(1)).dy, tester.getTopLeft(tile(2)).dy);
    expect(find.text('12.5'), findsOneWidget);
    expect(_watchedMarks, findsOneWidget);
    final bar = tester.widget<SegmentedBar>(
      find.descendant(
        of: find.byType(PlayerEpisodeGrid),
        matching: find.byType(SegmentedBar),
      ),
    );
    expect(bar.value, 600 / 1440);
    for (final index in [1, 2, 10]) {
      await tester.tap(tile(index));
    }
    expect(selected, [1, 2, 10]);
  });

  testWidgets('shows unsupported-source failure state', (tester) async {
    final cubit = FakePlayerSourceCubit(
      const PlayerSourceFailure(PlayerSourceFailureType.unsupportedSource),
    );

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(
      find.text('This source is not suitable for playback.'),
      findsOneWidget,
    );
  });
}

Widget _wrap({
  required FakePlayerSourceCubit cubit,
  Map<int, WatchProgress> progressByFile = const {},
  ValueChanged<PlayerVideoFile>? onFileSelected,
  int listedEpisodes = 0,
  bool isOnline = false,
}) {
  return testApp(
    BlocProvider<PlayerSourceCubit>.value(
      value: cubit,
      child: Scaffold(
        body: PlayerSourceView(
          progressByFile: progressByFile,
          listedEpisodes: listedEpisodes,
          isOnline: isOnline,
          onFileSelected: onFileSelected ?? (_) {},
        ),
      ),
    ),
  );
}

const _episodes = [
  PlayerVideoFile(index: 1, name: 'episode-01.mkv', size: 1, extension: 'mkv'),
  PlayerVideoFile(index: 2, name: 'episode-02.mkv', size: 1, extension: 'mkv'),
];

/// An online release whose episodes have no titles: each is named by its
/// number.
const _online = [
  PlayerVideoFile(
    index: 1,
    name: '01',
    size: 0,
    extension: 'm3u8',
    episodeNumber: 1,
  ),
  PlayerVideoFile(
    index: 2,
    name: '02',
    size: 0,
    extension: 'm3u8',
    episodeNumber: 2,
  ),
  PlayerVideoFile(
    index: 3,
    name: '03',
    size: 0,
    extension: 'm3u8',
    episodeNumber: 3,
  ),
];

final _watchedMarks = find.byWidgetPredicate(
  (widget) => widget is PixelIcon && widget.glyph == PixelGlyph.check,
);

WatchProgress _progress(int fileIndex, int seconds, {int minute = 0}) {
  return WatchProgress(
    torrentKey: 'abc',
    fileIndex: fileIndex,
    fileName: 'episode-0$fileIndex.mkv',
    magnet: 'magnet:?xt=urn:btih:abc',
    sourceTitle: 'Release',
    position: Duration(seconds: seconds),
    duration: const Duration(minutes: 24),
    updatedAt: DateTime.utc(2026, 10, 4, 12, minute),
  );
}
