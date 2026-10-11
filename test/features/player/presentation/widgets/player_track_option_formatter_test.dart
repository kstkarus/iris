import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/widgets/player_track_option_formatter.dart';

void main() {
  test('formats audio track labels from title and language', () {
    expect(_audio(const AudioTrack('1', 'Japanese', 'ja')), 'Japanese');
    expect(_audio(const AudioTrack('2', null, 'en')), 'English');
    expect(_audio(const AudioTrack('3', null, null, codec: 'aac')), 'AAC');
    expect(_audio(AudioTrack.auto()), 'Auto');
  });

  test('formats subtitle track labels with off option', () {
    expect(
      _subtitle(const SubtitleTrack('10', 'English Signs', 'en')),
      'English Signs',
    );
    expect(_subtitle(const SubtitleTrack('11', null, 'ru')), 'Russian');
    expect(_subtitle(SubtitleTrack.no()), 'Off');
  });
}

String _audio(AudioTrack track) =>
    formatAudioTrackLabel(track, autoLabel: 'Auto', offLabel: 'Off');

String _subtitle(SubtitleTrack track) =>
    formatSubtitleTrackLabel(track, autoLabel: 'Auto', offLabel: 'Off');
