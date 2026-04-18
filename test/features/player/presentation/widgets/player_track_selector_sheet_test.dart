import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/widgets/player_track_selector_sheet.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows audio and subtitle track sections', (tester) async {
    await tester.pumpWidget(
      _wrap(
        child: PlayerTrackSelectorSheet(
          audioTracks: const [
            AudioTrack('auto', null, null),
            AudioTrack('1', 'Japanese', 'ja'),
            AudioTrack('2', 'English Dub', 'en'),
          ],
          selectedAudioTrack: const AudioTrack('1', 'Japanese', 'ja'),
          subtitleTracks: const [
            SubtitleTrack('auto', null, null),
            SubtitleTrack('10', 'English Signs', 'en'),
          ],
          selectedSubtitleTrack: const SubtitleTrack(
            '10',
            'English Signs',
            'en',
          ),
          onAudioTrackSelected: (_) {},
          onSubtitleTrackSelected: (_) {},
          onSubtitleAppearancePressed: () {},
        ),
      ),
    );

    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Subtitles'), findsOneWidget);
    expect(find.text('Japanese'), findsOneWidget);
    expect(find.text('English Signs'), findsOneWidget);
    expect(find.text('Auto'), findsNWidgets(2));
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('invokes callbacks when track options are tapped', (
    tester,
  ) async {
    AudioTrack? selectedAudio;
    SubtitleTrack? selectedSubtitle;
    var settingsOpened = false;

    await tester.pumpWidget(
      _wrap(
        child: PlayerTrackSelectorSheet(
          audioTracks: const [
            AudioTrack('auto', null, null),
            AudioTrack('1', 'Japanese', 'ja'),
            AudioTrack('2', 'English Dub', 'en'),
          ],
          selectedAudioTrack: const AudioTrack('auto', null, null),
          subtitleTracks: const [
            SubtitleTrack('auto', null, null),
            SubtitleTrack('10', 'English Signs', 'en'),
          ],
          selectedSubtitleTrack: const SubtitleTrack('auto', null, null),
          onAudioTrackSelected: (track) => selectedAudio = track,
          onSubtitleTrackSelected: (track) => selectedSubtitle = track,
          onSubtitleAppearancePressed: () => settingsOpened = true,
        ),
      ),
    );

    await tester.tap(find.text('English Dub'));
    await tester.pump();
    await tester.tap(find.text('Off'));
    await tester.pump();
    await tester.ensureVisible(find.text('Subtitle Appearance'));
    await tester.tap(find.text('Subtitle Appearance'));
    await tester.pumpAndSettle();

    expect(selectedAudio, const AudioTrack('2', 'English Dub', 'en'));
    expect(selectedSubtitle, SubtitleTrack.no());
    expect(settingsOpened, isTrue);
  });

  testWidgets('supports scrolling for long track lists', (tester) async {
    final audioTracks = List.generate(
      20,
      (index) => AudioTrack('$index', 'Audio $index', 'en'),
    );
    final subtitleTracks = List.generate(
      20,
      (index) => SubtitleTrack('$index', 'Subtitle $index', 'en'),
    );

    await tester.pumpWidget(
      _wrap(
        child: SizedBox(
          height: 320,
          child: PlayerTrackSelectorSheet(
            audioTracks: audioTracks,
            selectedAudioTrack: audioTracks.first,
            subtitleTracks: subtitleTracks,
            selectedSubtitleTrack: subtitleTracks.first,
            onAudioTrackSelected: (_) {},
            onSubtitleTrackSelected: (_) {},
            onSubtitleAppearancePressed: () {},
          ),
        ),
      ),
    );

    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -600),
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
    home: Scaffold(body: child),
  );
}
