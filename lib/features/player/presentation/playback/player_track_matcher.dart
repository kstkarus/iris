import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/domain/entities/player_track_preferences.dart';

/// Describes a track the user picked; null for automatic selection.
PreferredTrack? preferredAudioTrackFrom(AudioTrack track) {
  if (track.id == 'auto' || track.id == 'no') return null;
  return _describe(track.language, track.title);
}

/// Describes a subtitle choice; "off" is remembered too.
PreferredTrack? preferredSubtitleTrackFrom(SubtitleTrack track) {
  if (track.id == 'no') return const PreferredTrack.off();
  if (track.id == 'auto') return null;
  return _describe(track.language, track.title);
}

AudioTrack? matchAudioTrack(List<AudioTrack> tracks, PreferredTrack preferred) {
  if (preferred.disabled) return null;
  return _match(
    tracks.where((track) => track.id != 'auto' && track.id != 'no'),
    preferred,
    language: (track) => track.language,
    title: (track) => track.title,
  );
}

SubtitleTrack? matchSubtitleTrack(
  List<SubtitleTrack> tracks,
  PreferredTrack preferred,
) {
  if (preferred.disabled) return SubtitleTrack.no();
  return _match(
    tracks.where((track) => track.id != 'auto' && track.id != 'no'),
    preferred,
    language: (track) => track.language,
    title: (track) => track.title,
  );
}

PreferredTrack? _describe(String? language, String? title) {
  final normalizedLanguage = _normalize(language);
  final normalizedTitle = _normalize(title);
  if (normalizedLanguage == null && normalizedTitle == null) return null;
  return PreferredTrack(language: normalizedLanguage, title: normalizedTitle);
}

/// Language and title first, then language, then title. For each language
/// match, prefer the original tag over another name for the same language.
T? _match<T>(
  Iterable<T> tracks,
  PreferredTrack preferred, {
  required String? Function(T track) language,
  required String? Function(T track) title,
}) {
  final candidates = tracks.toList();
  final wantedLanguage = _normalize(preferred.language);
  final wantedAlias = _languageAlias(wantedLanguage);
  final wantedTitle = _normalize(preferred.title);
  if (wantedLanguage == null && wantedTitle == null) return null;

  bool sameLanguage(T track) =>
      wantedLanguage != null && _normalize(language(track)) == wantedLanguage;
  bool sameAlias(T track) =>
      wantedAlias != null &&
      _languageAlias(_normalize(language(track))) == wantedAlias;
  bool sameTitle(T track) =>
      wantedTitle != null && _normalize(title(track)) == wantedTitle;

  for (final track in candidates) {
    if ((wantedLanguage == null || sameLanguage(track)) &&
        (wantedTitle == null || sameTitle(track))) {
      return track;
    }
  }
  for (final track in candidates) {
    if (sameAlias(track) && sameTitle(track)) return track;
  }
  for (final track in candidates) {
    if (sameLanguage(track)) return track;
  }
  for (final track in candidates) {
    if (sameAlias(track)) return track;
  }
  for (final track in candidates) {
    if (sameTitle(track)) return track;
  }
  return null;
}

String? _languageAlias(String? language) => switch (language) {
  'ja' || 'jpn' || 'jp' || 'japanese' => 'ja',
  'ru' || 'rus' || 'russian' => 'ru',
  'en' || 'eng' || 'english' => 'en',
  _ => null,
};

String? _normalize(String? value) {
  final trimmed = value?.trim().toLowerCase();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
