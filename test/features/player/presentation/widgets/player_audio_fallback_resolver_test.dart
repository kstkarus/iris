import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/widgets/player_audio_fallback_resolver.dart';

void main() {
  test('returns alternative audio track when codec is unsupported', () {
    final fallback = resolveAudioFallbackTrack(
      errorMessage: "Failed to initialize a decoder for codec 'truehd'.",
      audioTracks: const [
        AudioTrack('1', 'TrueHD', 'en', codec: 'truehd'),
        AudioTrack('2', 'AC3', 'en', codec: 'ac3'),
      ],
      selectedAudioTrack: const AudioTrack(
        '1',
        'TrueHD',
        'en',
        codec: 'truehd',
      ),
    );

    expect(fallback, const AudioTrack('2', 'AC3', 'en', codec: 'ac3'));
  });

  test('returns no-audio track when no supported alternative exists', () {
    final fallback = resolveAudioFallbackTrack(
      errorMessage: "Failed to initialize a decoder for codec 'truehd'.",
      audioTracks: const [AudioTrack('1', 'TrueHD', 'en', codec: 'truehd')],
      selectedAudioTrack: const AudioTrack(
        '1',
        'TrueHD',
        'en',
        codec: 'truehd',
      ),
    );

    expect(fallback, AudioTrack.no());
  });

  test('returns null for unrelated errors', () {
    final fallback = resolveAudioFallbackTrack(
      errorMessage: 'Network timeout.',
      audioTracks: const [AudioTrack('1', 'AC3', 'en', codec: 'ac3')],
      selectedAudioTrack: const AudioTrack('1', 'AC3', 'en', codec: 'ac3'),
    );

    expect(fallback, isNull);
  });
}
