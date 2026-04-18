import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/domain/entities/player_playback_stats.dart';
import 'package:iris/features/player/presentation/widgets/player_playback_stats_indicator.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('renders speed and memory when both are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        child: const PlayerPlaybackStatsIndicator(
          stats: PlayerPlaybackStats(
            downloadRateBytesPerSecond: 1572864,
            appMemoryBytes: 268435456,
            activePeers: 42,
          ),
        ),
      ),
    );

    expect(find.text('1.5 MB/s'), findsOneWidget);
    expect(find.text('256 MB'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('renders only speed when memory is unavailable', (tester) async {
    await tester.pumpWidget(
      _wrap(
        child: const PlayerPlaybackStatsIndicator(
          stats: PlayerPlaybackStats(
            downloadRateBytesPerSecond: 524288,
            appMemoryBytes: null,
            activePeers: 11,
          ),
        ),
      ),
    );

    expect(find.text('512 KB/s'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('Buffering...'), findsNothing);
  });

  testWidgets('renders stats when they appear after the first build', (
    tester,
  ) async {
    final notifier = ValueNotifier<PlayerPlaybackStats?>(null);
    addTearDown(notifier.dispose);

    await tester.pumpWidget(
      _wrap(child: PlayerPlaybackStatsListenable(listenable: notifier)),
    );

    expect(find.textContaining('Speed'), findsNothing);

    notifier.value = const PlayerPlaybackStats(
      downloadRateBytesPerSecond: 1048576,
      appMemoryBytes: 134217728,
      activePeers: 24,
    );
    await tester.pump();

    expect(find.text('1.0 MB/s'), findsOneWidget);
    expect(find.text('128 MB'), findsOneWidget);
    expect(find.text('24'), findsOneWidget);
  });

  testWidgets('renders codecs and buffering state when they are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        child: const PlayerPlaybackStatsIndicator(
          stats: PlayerPlaybackStats(
            downloadRateBytesPerSecond: 1048576,
            appMemoryBytes: 134217728,
            activePeers: 24,
          ),
          videoCodec: 'AV1',
          audioCodec: 'Opus',
          isBuffering: true,
        ),
      ),
    );

    expect(find.text('AV1'), findsOneWidget);
    expect(find.text('Opus'), findsOneWidget);
    expect(find.text('Buffering...'), findsOneWidget);
  });

  testWidgets('does not overflow on narrow widths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(220, 300));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(
      _wrap(
        child: const SizedBox(
          width: 160,
          child: PlayerPlaybackStatsIndicator(
            stats: PlayerPlaybackStats(
              downloadRateBytesPerSecond: 1572864,
              appMemoryBytes: 268435456,
              activePeers: 42,
            ),
            videoCodec: 'H.265 / HEVC Main 10',
            audioCodec: 'Opus 5.1 Surround',
            isBuffering: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

Widget _wrap({required Widget child}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}
