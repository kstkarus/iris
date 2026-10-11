import 'package:media_kit/media_kit.dart';

String formatAudioTrackLabel(
  AudioTrack track, {
  required String autoLabel,
  required String offLabel,
}) {
  if (track.id == AudioTrack.auto().id) {
    return autoLabel;
  }

  if (track.id == AudioTrack.no().id) {
    return offLabel;
  }

  return _formatTrackLabel(
    title: track.title,
    language: track.language,
    codec: track.codec,
  );
}

String formatSubtitleTrackLabel(
  SubtitleTrack track, {
  required String autoLabel,
  required String offLabel,
}) {
  if (track.id == SubtitleTrack.auto().id) {
    return autoLabel;
  }

  if (track.id == SubtitleTrack.no().id) {
    return offLabel;
  }

  return _formatTrackLabel(
    title: track.title,
    language: track.language,
    codec: track.codec,
  );
}

String _formatTrackLabel({
  required String? title,
  required String? language,
  required String? codec,
}) {
  final trimmedTitle = title?.trim();
  if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
    return trimmedTitle;
  }

  final languageLabel = _languageLabels[language?.toLowerCase()];
  if (languageLabel != null) {
    return languageLabel;
  }

  final trimmedCodec = codec?.trim();
  if (trimmedCodec != null && trimmedCodec.isNotEmpty) {
    return trimmedCodec.toUpperCase();
  }

  return 'Track';
}

const _languageLabels = {'en': 'English', 'ja': 'Japanese', 'ru': 'Russian'};
