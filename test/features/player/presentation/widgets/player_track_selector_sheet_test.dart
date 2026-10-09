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
        ),
      ),
    );

    expect(find.text('AUDIO'), findsOneWidget);
    expect(find.text('SUBTITLES'), findsOneWidget);
    expect(find.text('Japanese'), findsOneWidget);
    expect(find.text('English Signs'), findsOneWidget);
    expect(find.text('Auto'), findsNWidgets(2));
    expect(find.text('Off'), findsOneWidget);
  });

  testWidgets('tells assistive technology which tracks are selected', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        child: PlayerTrackSelectorSheet(
          audioTracks: const [
            AudioTrack('auto', null, null),
            AudioTrack('1', 'Japanese', 'ja'),
          ],
          selectedAudioTrack: const AudioTrack('1', 'Japanese', 'ja'),
          subtitleTracks: const [
            SubtitleTrack('auto', null, null),
            SubtitleTrack('10', 'English Signs', 'en'),
          ],
          selectedSubtitleTrack: const SubtitleTrack('auto', null, null),
          onAudioTrackSelected: (_) {},
          onSubtitleTrackSelected: (_) {},
        ),
      ),
    );

    Matcher row({required bool selected}) => isSemantics(
      isSelected: selected,
      hasSelectedState: true,
      isButton: true,
      isFocusable: true,
      hasEnabledState: true,
      isEnabled: true,
      hasTapAction: true,
      hasFocusAction: true,
    );
    expect(tester.getSemantics(find.text('Japanese')), row(selected: true));
    expect(
      tester.getSemantics(find.text('English Signs')),
      row(selected: false),
    );
    semantics.dispose();
  });

  testWidgets('invokes callbacks when track options are tapped', (
    tester,
  ) async {
    AudioTrack? selectedAudio;
    SubtitleTrack? selectedSubtitle;

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
        ),
      ),
    );

    await tester.tap(find.text('English Dub'));
    await tester.pump();
    await tester.tap(find.text('Off'));
    await tester.pump();

    expect(selectedAudio, const AudioTrack('2', 'English Dub', 'en'));
    expect(selectedSubtitle, SubtitleTrack.no());
  });

  testWidgets('holds only the tracks, the settings live elsewhere', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(child: _sheet()));

    expect(find.text('Audio & subtitles'), findsOneWidget);
    expect(find.text('Subtitle Appearance'), findsNothing);
    expect(find.byKey(const Key('player_detailed_stats_switch')), findsNothing);
  });

  testWidgets('tells apart two tracks of one language by their format', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        child: _sheet(
          subtitleTracks: const [
            SubtitleTrack('10', 'Russian', 'ru', codec: 'ass'),
            SubtitleTrack('11', 'Russian Full', 'ru', codec: 'subrip'),
            SubtitleTrack('12', null, null, codec: 'ass'),
          ],
        ),
      ),
    );

    expect(find.text('SRT'), findsOneWidget);
    // Named by its codec already: no second ASS beside it.
    expect(find.text('ASS'), findsNWidgets(2));
  });

  for (final (width, sideBySide) in const [(1280.0, true), (400.0, false)]) {
    testWidgets(
      sideBySide
          ? 'sets the lists side by side in a wide window'
          : 'stacks the lists in a phone sheet',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_wrap(child: _sheet()));

        final audio = tester.getRect(find.text('AUDIO'));
        final subtitles = tester.getRect(find.text('SUBTITLES'));
        if (sideBySide) {
          expect(subtitles.top, audio.top);
          expect(subtitles.left, greaterThan(audio.right));
        } else {
          expect(subtitles.top, greaterThan(audio.bottom));
          expect(subtitles.left, audio.left);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

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

PlayerTrackSelectorSheet _sheet({
  List<SubtitleTrack> subtitleTracks = const [
    SubtitleTrack('10', 'English Signs', 'en'),
  ],
}) {
  return PlayerTrackSelectorSheet(
    audioTracks: const [AudioTrack('1', 'Japanese', 'ja')],
    selectedAudioTrack: const AudioTrack('1', 'Japanese', 'ja'),
    subtitleTracks: subtitleTracks,
    selectedSubtitleTrack: SubtitleTrack.auto(),
    onAudioTrackSelected: (_) {},
    onSubtitleTrackSelected: (_) {},
  );
}
