import 'package:media_kit/media_kit.dart';

AudioTrack? resolveAudioFallbackTrack({
  required String errorMessage,
  required List<AudioTrack> audioTracks,
  required AudioTrack selectedAudioTrack,
}) {
  final unsupportedCodec = _extractUnsupportedCodec(errorMessage);
  if (unsupportedCodec == null) {
    return null;
  }

  for (final track in audioTracks) {
    final trackId = track.id;
    if (trackId == AudioTrack.auto().id || trackId == AudioTrack.no().id) {
      continue;
    }
    if (trackId == selectedAudioTrack.id) {
      continue;
    }
    if (track.codec?.toLowerCase() == unsupportedCodec) {
      continue;
    }
    return track;
  }

  return AudioTrack.no();
}

String? _extractUnsupportedCodec(String errorMessage) {
  final match = RegExp(
    "decoder for codec '([^']+)'",
    caseSensitive: false,
  ).firstMatch(errorMessage);
  return match?.group(1)?.toLowerCase();
}
