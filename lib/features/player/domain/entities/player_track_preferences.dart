/// A track the user picked, described so it can be found again in another
/// file of the same release (track ids differ between files).
class PreferredTrack {
  const PreferredTrack({this.language, this.title, this.disabled = false});

  /// Subtitles switched off.
  const PreferredTrack.off() : language = null, title = null, disabled = true;

  final String? language;
  final String? title;
  final bool disabled;

  @override
  bool operator ==(Object other) {
    return other is PreferredTrack &&
        other.language == language &&
        other.title == title &&
        other.disabled == disabled;
  }

  @override
  int get hashCode => Object.hash(language, title, disabled);
}

/// Audio and subtitle choices remembered per release (torrent).
class PlayerTrackPreferences {
  const PlayerTrackPreferences({this.audio, this.subtitle});

  final PreferredTrack? audio;
  final PreferredTrack? subtitle;

  bool get isEmpty => audio == null && subtitle == null;

  PlayerTrackPreferences copyWith({
    PreferredTrack? audio,
    PreferredTrack? subtitle,
  }) {
    return PlayerTrackPreferences(
      audio: audio ?? this.audio,
      subtitle: subtitle ?? this.subtitle,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PlayerTrackPreferences &&
        other.audio == audio &&
        other.subtitle == subtitle;
  }

  @override
  int get hashCode => Object.hash(audio, subtitle);
}
