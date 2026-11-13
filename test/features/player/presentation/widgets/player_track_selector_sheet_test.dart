import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/widgets/player_track_selector_sheet.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_window.dart';

void main() {
  testWidgets('names untitled tracks in the app language', (tester) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: PlayerTrackSelectorSheet(
            audioTracks: const [
              AudioTrack('1', null, 'ja'),
              AudioTrack('2', null, 'en'),
            ],
            selectedAudioTrack: const AudioTrack('1', null, 'ja'),
            subtitleTracks: const [
              SubtitleTrack('10', null, 'ru'),
              SubtitleTrack('11', null, null),
            ],
            selectedSubtitleTrack: const SubtitleTrack('10', null, 'ru'),
            onAudioTrackSelected: (_) {},
            onSubtitleTrackSelected: (_) {},
          ),
        ),
        locale: const Locale('ru'),
      ),
    );

    expect(find.text('Японский'), findsOneWidget);
    expect(find.text('Английский'), findsOneWidget);
    expect(find.text('Русский'), findsOneWidget);
    expect(find.text('Дорожка'), findsOneWidget);
    expect(find.text('English'), findsNothing);
    expect(find.text('Track'), findsNothing);
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
            AudioTrack('2', 'English Dub', 'en'),
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

  testWidgets('hides a single audio track while subtitles remain selectable', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        child: _sheet(
          audioTracks: const [
            AudioTrack('auto', null, null),
            AudioTrack('no', null, null),
            AudioTrack('1', 'Japanese', 'ja'),
          ],
        ),
      ),
    );

    expect(find.text('AUDIO'), findsNothing);
    expect(find.text('Japanese'), findsNothing);
    expect(find.text('SUBTITLES'), findsOneWidget);
    expect(find.text('Off'), findsOneWidget);
    expect(find.text('English Signs'), findsOneWidget);
  });

  testWidgets('hides subtitle options when only Auto and Off exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        child: _sheet(
          subtitleTracks: const [
            SubtitleTrack('auto', null, null),
            SubtitleTrack('no', null, null),
          ],
        ),
      ),
    );

    expect(find.text('AUDIO'), findsOneWidget);
    expect(find.text('SUBTITLES'), findsNothing);
    expect(find.text('Off'), findsNothing);
    expect(find.text('Auto'), findsOneWidget);
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

  for (final width in [400.0, 1280.0]) {
    testWidgets('can select a track at the end of a long list at $width dp', (
      tester,
    ) async {
      setTestWindowSize(tester, Size(width, 800));
      SubtitleTrack? selected;
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
              onSubtitleTrackSelected: (track) => selected = track,
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('Subtitle 19'),
        200,
        scrollable: find.descendant(
          of: find.byType(PlayerTrackSelectorSheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Subtitle 19'));
      expect(selected, subtitleTracks.last);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _wrap({required Widget child}) {
  return testApp(Scaffold(body: child));
}

PlayerTrackSelectorSheet _sheet({
  List<AudioTrack> audioTracks = const [
    AudioTrack('1', 'Japanese', 'ja'),
    AudioTrack('2', 'English Dub', 'en'),
  ],
  List<SubtitleTrack> subtitleTracks = const [
    SubtitleTrack('10', 'English Signs', 'en'),
  ],
}) {
  return PlayerTrackSelectorSheet(
    audioTracks: audioTracks,
    selectedAudioTrack: const AudioTrack('1', 'Japanese', 'ja'),
    subtitleTracks: subtitleTracks,
    selectedSubtitleTrack: SubtitleTrack.auto(),
    onAudioTrackSelected: (_) {},
    onSubtitleTrackSelected: (_) {},
  );
}
