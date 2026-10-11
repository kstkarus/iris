import 'package:media_kit/media_kit.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

String formatAudioTrackLabel(AppLocalizations l10n, AudioTrack track) {
  if (track.id == AudioTrack.auto().id) {
    return l10n.playerTrackAuto;
  }

  if (track.id == AudioTrack.no().id) {
    return l10n.playerTrackOff;
  }

  return _formatTrackLabel(
    l10n,
    title: track.title,
    language: track.language,
    codec: track.codec,
  );
}

String formatSubtitleTrackLabel(AppLocalizations l10n, SubtitleTrack track) {
  if (track.id == SubtitleTrack.auto().id) {
    return l10n.playerTrackAuto;
  }

  if (track.id == SubtitleTrack.no().id) {
    return l10n.playerTrackOff;
  }

  return _formatTrackLabel(
    l10n,
    title: track.title,
    language: track.language,
    codec: track.codec,
  );
}

String _formatTrackLabel(
  AppLocalizations l10n, {
  required String? title,
  required String? language,
  required String? codec,
}) {
  final trimmedTitle = title?.trim();
  if (trimmedTitle != null && trimmedTitle.isNotEmpty) {
    return trimmedTitle;
  }

  final languageLabel = switch (language?.toLowerCase()) {
    'en' => l10n.playerTrackLanguageEnglish,
    'ja' => l10n.playerTrackLanguageJapanese,
    'ru' => l10n.playerTrackLanguageRussian,
    _ => null,
  };
  if (languageLabel != null) {
    return languageLabel;
  }

  final trimmedCodec = codec?.trim();
  if (trimmedCodec != null && trimmedCodec.isNotEmpty) {
    return trimmedCodec.toUpperCase();
  }

  return l10n.playerTrackUnnamed;
}
