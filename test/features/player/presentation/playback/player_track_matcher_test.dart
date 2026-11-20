import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/domain/entities/player_track_preferences.dart';
import 'package:iris/features/player/presentation/playback/player_track_matcher.dart';

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

  for (final aliases in const [
    ['ja', 'jpn', 'jp', 'japanese'],
    ['ru', 'rus', 'russian'],
    ['en', 'eng', 'english'],
  ]) {
    test('matches ${aliases.last} aliases in both directions', () {
      for (final alias in aliases) {
        final audio = AudioTrack('1', null, ' ${alias.toUpperCase()} ');
        final subtitle = SubtitleTrack('1', null, aliases.first);
        expect(
          matchAudioTrack([audio], PreferredTrack(language: aliases.first)),
          audio,
        );
        expect(
          matchSubtitleTrack([subtitle], PreferredTrack(language: alias)),
          subtitle,
        );
      }
    });
  }

  test('prefers an exact tag for equal matches and keeps the dub title', () {
    const aliased = AudioTrack('1', 'Studio Band', 'russian');
    const exact = AudioTrack('2', 'Studio Band', 'rus');
    const otherDub = AudioTrack('3', 'AniLibria', 'rus');
    const preferred = PreferredTrack(language: 'rus', title: 'studio band');

    expect(matchAudioTrack([aliased, exact], preferred), exact);
    expect(matchAudioTrack([otherDub, aliased], preferred), aliased);
    expect(
      matchAudioTrack([aliased, exact], const PreferredTrack(language: 'rus')),
      exact,
    );
  });
}
