import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/widgets/player_track_option_formatter.dart';

void main() {
  test('formats audio track labels from title and language', () {
    expect(
      formatAudioTrackLabel(const AudioTrack('1', 'Japanese', 'ja')),
      'Japanese',
    );
    expect(formatAudioTrackLabel(const AudioTrack('2', null, 'en')), 'English');
    expect(
      formatAudioTrackLabel(const AudioTrack('3', null, null, codec: 'aac')),
      'AAC',
    );
    expect(formatAudioTrackLabel(AudioTrack.auto()), 'Auto');
  });

  test('formats subtitle track labels with off option', () {
    expect(
      formatSubtitleTrackLabel(
        const SubtitleTrack('10', 'English Signs', 'en'),
      ),
      'English Signs',
    );
    expect(
      formatSubtitleTrackLabel(const SubtitleTrack('11', null, 'ru')),
      'Russian',
    );
    expect(formatSubtitleTrackLabel(SubtitleTrack.no()), 'Off');
  });
}
