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
          ),
        ),
      ),
    );

    expect(find.text('Speed 1.5 MB/s'), findsOneWidget);
    expect(find.text('Memory 256 MB'), findsOneWidget);
  });

  testWidgets('renders only speed when memory is unavailable', (tester) async {
    await tester.pumpWidget(
      _wrap(
        child: const PlayerPlaybackStatsIndicator(
          stats: PlayerPlaybackStats(
            downloadRateBytesPerSecond: 524288,
            appMemoryBytes: null,
          ),
        ),
      ),
    );

    expect(find.text('Speed 512 KB/s'), findsOneWidget);
    expect(find.textContaining('Memory'), findsNothing);
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
