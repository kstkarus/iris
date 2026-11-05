import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/entities/user_rate/domain/mark_episode_watched.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/cubit/episode_mark_cubit.dart';
import 'package:iris/features/player/presentation/widgets/episode_mark_plate.dart';
import 'package:iris/features/player/presentation/widgets/player_wait_indicator.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';

const _source = AnimePlayerSource(
  animeId: '1',
  animeTitle: 'Anime',
  sourceTitle: 'Source',
  sessionId: 's',
  fileIndex: 0,
  fileName: 'Episode',
  files: [
    PlayerVideoFile(
      index: 0,
      name: 'Episode',
      size: 0,
      extension: '',
      episodeNumber: 11,
    ),
  ],
);
const _marked = EpisodeMarked(
  previous: null,
  saved: UserRate(id: '1', status: UserRateStatus.watching, episodes: 11),
);

void main() {
  testWidgets('shows an indicator during undo, then allows restore', (
    tester,
  ) async {
    final marker = _Marker();
    final cubit = EpisodeMarkCubit(
      markEpisode: marker,
      userId: '42',
      sessionGeneration: () => 0,
    );
    final visible = ValueNotifier(true);
    addTearDown(cubit.close);
    addTearDown(visible.dispose);
    await tester.pumpWidget(_app(cubit, visible));
    cubit.watched(_source);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Episode 11 marked'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final runner = tester.widget<BlockRunner>(
      find.descendant(
        of: find.byKey(const Key('player_mark_progress')),
        matching: find.byType(BlockRunner),
      ),
    );
    expect((runner.cell, runner.gap), (6, 2));
    expect(find.text('Undo'), findsNothing);
    await tester.pump(const Duration(seconds: 6));
    expect(find.byKey(const Key('player_mark_progress')), findsOneWidget);
    marker.undoReply.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Episode 11 not marked'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);
    await tester.tap(find.text('Restore'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Episode 11 marked'), findsOneWidget);
  });

  testWidgets('success hides with controls, while an error remains and opens', (
    tester,
  ) async {
    final marker = _Marker();
    final cubit = EpisodeMarkCubit(
      markEpisode: marker,
      userId: '42',
      sessionGeneration: () => 0,
    );
    final visible = ValueNotifier(false);
    addTearDown(cubit.close);
    addTearDown(visible.dispose);
    await tester.pumpWidget(_app(cubit, visible));
    cubit.watched(_source);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('player_mark_disclosure')), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('player_mark_visibility')),
          )
          .opacity,
      0,
    );
    visible.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byKey(const Key('player_mark_toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Undo'));
    await tester.pump();
    marker.undoReply.completeError(StateError('offline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Could not undo'), findsOneWidget);
    expect(find.text('Previously: Episode 11 marked'), findsOneWidget);
    visible.value = false;
    await tester.pump(const Duration(seconds: 11));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.byKey(const Key('player_mark_visibility')),
          )
          .opacity,
      1,
    );
    expect(find.byKey(const Key('player_mark_disclosure')), findsOneWidget);
    expect(
      tester
          .widget<PixelIcon>(find.byKey(const ValueKey(PixelGlyph.markWarning)))
          .color,
      const Color(0xFFFFD93B),
    );
    await tester.tap(find.byKey(const Key('player_mark_toggle')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Try Again'), findsOneWidget);
  });

  testWidgets('fits the available width with double text size', (tester) async {
    setTestWindowSize(tester, const Size(480, 320));
    final marker = _Marker();
    final cubit = EpisodeMarkCubit(
      markEpisode: marker,
      userId: '42',
      sessionGeneration: () => 0,
    );
    final visible = ValueNotifier(true);
    addTearDown(cubit.close);
    addTearDown(visible.dispose);
    await tester.pumpWidget(_app(cubit, visible, width: 320, textScale: 2));
    cubit.watched(_source);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('player_mark_plate'))).width,
      lessThanOrEqualTo(320),
    );
    expect(find.text('Marked'), findsOneWidget);
  });

  testWidgets('multiple failed marks can be reached from the plate', (
    tester,
  ) async {
    final cubit = EpisodeMarkCubit(
      markEpisode: _FailingMarker(),
      userId: '42',
      sessionGeneration: () => 0,
    );
    final visible = ValueNotifier(true);
    addTearDown(cubit.close);
    addTearDown(visible.dispose);
    await tester.pumpWidget(_app(cubit, visible));
    cubit.watched(_source);
    cubit.watched(
      const AnimePlayerSource(
        animeId: '1',
        animeTitle: 'Anime',
        sourceTitle: 'Source',
        sessionId: 's',
        fileIndex: 0,
        fileName: 'Episode',
        files: [
          PlayerVideoFile(
            index: 0,
            name: 'Episode',
            size: 0,
            extension: '',
            episodeNumber: 12,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Could not mark episode 11'), findsOneWidget);
    expect(find.text('1/2 ›'), findsOneWidget);
    await tester.tap(find.byKey(const Key('player_mark_next_pending')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Could not mark episode 12'), findsOneWidget);
    expect(find.text('2/2 ›'), findsOneWidget);
  });

  testWidgets('holds its countdown while the player overlay is hidden', (
    tester,
  ) async {
    final cubit = EpisodeMarkCubit(
      markEpisode: _Marker(),
      userId: '42',
      sessionGeneration: () => 0,
    );
    final visible = ValueNotifier(true);
    final active = ValueNotifier(true);
    addTearDown(cubit.close);
    addTearDown(visible.dispose);
    addTearDown(active.dispose);
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ValueListenableBuilder<bool>(
            valueListenable: active,
            builder: (context, enabled, _) => TickerMode(
              enabled: enabled,
              child: SizedBox(
                width: 500,
                child: EpisodeMarkPlate(cubit: cubit, controlsVisible: visible),
              ),
            ),
          ),
        ),
        theme: buildAppTheme(brightness: Brightness.dark),
      ),
    );
    cubit.watched(_source);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    active.value = false;
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    active.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Undo'), findsOneWidget);
  });
}

Widget _app(
  EpisodeMarkCubit cubit,
  ValueNotifier<bool> visible, {
  double width = 500,
  double textScale = 1,
}) => testApp(
  Scaffold(
    body: Center(
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: SizedBox(
          width: width,
          child: EpisodeMarkPlate(cubit: cubit, controlsVisible: visible),
        ),
      ),
    ),
  ),
  theme: buildAppTheme(brightness: Brightness.dark),
);

class _Marker implements EpisodeMarker {
  final undoReply = Completer<bool>();

  @override
  Future<EpisodeMarkResult> call({
    required String userId,
    required String animeId,
    required int episode,
    bool Function()? isCurrent,
  }) async => _marked;

  @override
  Future<bool> undo({
    required String userId,
    required String animeId,
    required EpisodeMarked mark,
    bool Function()? isCurrent,
  }) => undoReply.future;
}

class _FailingMarker implements EpisodeMarker {
  @override
  Future<EpisodeMarkResult> call({
    required String userId,
    required String animeId,
    required int episode,
    bool Function()? isCurrent,
  }) async => throw StateError('offline');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
