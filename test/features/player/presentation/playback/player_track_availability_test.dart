import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/playback/player_track_availability.dart';

void main() {
  test(
    'automatic options and duplicate audio tracks do not create a choice',
    () {
      const tracks = Tracks(
        audio: [
          AudioTrack('auto', null, null),
          AudioTrack('no', null, null),
          AudioTrack('1', 'Japanese', 'ja'),
          AudioTrack('1', 'Japanese', 'ja'),
        ],
      );

      expect(tracks.hasAudioChoice, isFalse);
      expect(tracks.hasSubtitles, isFalse);
      expect(tracks.hasTrackChoice, isFalse);
      expect(tracks.canStyleSubtitles(SubtitleTrack.auto()), isFalse);
    },
  );

  test('bitmap tracks stay selectable without text styling', () {
    for (final codec in [
      'hdmv_pgs_subtitle',
      'dvd_subtitle',
      'dvb_subtitle',
      'xsub',
    ]) {
      final tracks = Tracks(
        subtitle: [SubtitleTrack('1', null, null, codec: codec)],
      );

      expect(tracks.hasTrackChoice, isTrue);
      expect(tracks.canStyleSubtitles(SubtitleTrack.auto()), isFalse);
      expect(tracks.canStyleSubtitles(SubtitleTrack.no()), isFalse);
    }
  });

  test('text and external tracks keep styling even with unknown codecs', () {
    for (final track in [
      const SubtitleTrack('1', null, null, codec: 'ass', image: true),
      const SubtitleTrack('2', null, null, codec: 'subrip'),
      const SubtitleTrack('3', null, null, codec: 'webvtt'),
      SubtitleTrack.uri('https://example.test/episode.vtt'),
    ]) {
      final tracks = Tracks(subtitle: [track]);

      expect(tracks.hasSubtitles, isTrue);
      expect(tracks.canStyleSubtitles(SubtitleTrack.no()), isTrue);
    }
  });
}
