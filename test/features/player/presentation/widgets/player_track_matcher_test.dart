import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_track_matcher.dart';

void main() {
  final audio = [
    AudioTrack.auto(),
    AudioTrack.no(),
    const AudioTrack('1', 'Original', 'jpn'),
    const AudioTrack('2', 'AniLibria', 'rus'),
    const AudioTrack('3', 'Studio Band', 'rus'),
  ];
  final subtitles = [
    SubtitleTrack.auto(),
    SubtitleTrack.no(),
    const SubtitleTrack('1', 'Full', 'rus'),
    const SubtitleTrack('2', 'Signs', 'rus'),
  ];

  test('describes picked tracks and ignores automatic selection', () {
    expect(
      preferredAudioTrackFrom(audio[3]),
      const PreferredTrack(language: 'rus', title: 'anilibria'),
    );
    expect(preferredAudioTrackFrom(AudioTrack.auto()), isNull);
    expect(
      preferredSubtitleTrackFrom(SubtitleTrack.no()),
      const PreferredTrack.off(),
    );
    expect(preferredSubtitleTrackFrom(SubtitleTrack.auto()), isNull);
  });

  test('prefers language and title, then language, then title', () {
    expect(
      matchAudioTrack(
        audio,
        const PreferredTrack(language: 'rus', title: 'studio band'),
      )?.id,
      '3',
    );
    expect(
      matchAudioTrack(
        audio,
        const PreferredTrack(language: 'rus', title: 'Renamed dub'),
      )?.id,
      '2',
    );
    expect(
      matchAudioTrack(audio, const PreferredTrack(title: 'ORIGINAL'))?.id,
      '1',
    );
    expect(matchAudioTrack(audio, const PreferredTrack(language: 'eng')), null);
  });

  test('restores switched-off subtitles', () {
    expect(
      matchSubtitleTrack(subtitles, const PreferredTrack.off()),
      SubtitleTrack.no(),
    );
    expect(
      matchSubtitleTrack(
        subtitles,
        const PreferredTrack(language: 'rus', title: 'signs'),
      )?.id,
      '2',
    );
  });
}
