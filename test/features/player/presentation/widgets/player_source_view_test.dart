import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/domain/entities/player_launch_update.dart';
import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/entities/prepared_player_source.dart';
import 'package:iris/features/player/domain/repositories/player_repository.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/player_source_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows loading state while source is being prepared', (
    tester,
  ) async {
    final cubit = _FakePlayerSourceCubit(const PlayerSourceLoading());

    await tester.pumpWidget(_wrap(cubit: cubit));

    expect(find.text('Preparing torrent files'), findsOneWidget);
  });

  testWidgets('lists files with sizes and opens the tapped one', (
    tester,
  ) async {
    final cubit = _FakePlayerSourceCubit(
      const PlayerSourceReady(
        PreparedPlayerSource(
          sessionId: '42',
          files: [
            PlayerVideoFile(
              index: 1,
              name: 'episode-01.mkv',
              size: 734003200,
              extension: 'mkv',
            ),
            PlayerVideoFile(
              index: 2,
              name: 'episode-02.mp4',
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

    expect(find.text('episode-01'), findsOneWidget);
    expect(find.text('700.0 MB'), findsOneWidget);
    expect(find.text('episode-02'), findsOneWidget);
    expect(find.text('500.0 MB'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);

    await tester.tap(find.text('episode-02'));
    expect(selected, [2]);
  });

  testWidgets('marks progress and continues the last unfinished file', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      _wrap(
        cubit: _FakePlayerSourceCubit(
          const PlayerSourceReady(
            PreparedPlayerSource(sessionId: '42', files: _episodes),
          ),
        ),
        progressByFile: {2: _progress(2, 300)},
        onFileSelected: (file) => selected.add(file.index),
      ),
    );

    // The card above the list and the file's own row both show where it
    // stopped; the card's button is the only "Continue".
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Stopped at 5:00 of 24:00'), findsNWidgets(2));

    await tester.tap(find.byKey(PlayerSourceView.continueButtonKey));
    expect(selected, [2]);
  });

  testWidgets('offers the next file after a finished one', (tester) async {
    await tester.pumpWidget(
      _wrap(
        cubit: _FakePlayerSourceCubit(
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
    expect(find.text('Watched'), findsOneWidget);
  });

  testWidgets('shows unsupported-source failure state', (tester) async {
    final cubit = _FakePlayerSourceCubit(
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
  required _FakePlayerSourceCubit cubit,
  Map<int, WatchProgress> progressByFile = const {},
  ValueChanged<PlayerVideoFile>? onFileSelected,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<PlayerSourceCubit>.value(
      value: cubit,
      child: Scaffold(
        body: PlayerSourceView(
          progressByFile: progressByFile,
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

class _FakePlayerSourceCubit extends PlayerSourceCubit {
  _FakePlayerSourceCubit(PlayerSourceState initialState)
    : super(
        magnet: 'magnet:?xt=urn:btih:test-source',
        repository: _UnusedPlayerRepository(),
      ) {
    emit(initialState);
  }
}

class _UnusedPlayerRepository implements PlayerRepository {
  @override
  Future<void> stopPlayback({required String sessionId}) async {}

  @override
  Future<void> disposePlayback({required String sessionId}) async {}

  @override
  Future<PreparedPlayerSource> prepareSource({required String magnet}) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerLaunchUpdate> startPlayback({
    required String sessionId,
    required int fileIndex,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<PlayerPlaybackStats> watchPlaybackStats({required String sessionId}) {
    return const Stream.empty();
  }
}
