import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Track equality ignores metadata; retain each new snapshot from the player.
class PlayerTrackNotifier<T> extends ChangeNotifier
    implements ValueListenable<T> {
  PlayerTrackNotifier(this._value);

  T _value;

  @override
  T get value => _value;

  set value(T value) {
    if (identical(_value, value)) return;
    _value = value;
    notifyListeners();
  }
}

extension PlayerTrackAvailability on Tracks {
  List<AudioTrack> get realAudioTracks => audio
      .where((track) => track.id != 'auto' && track.id != 'no')
      .toSet()
      .toList();

  List<SubtitleTrack> get realSubtitleTracks => subtitle
      .where((track) => track.id != 'auto' && track.id != 'no')
      .toSet()
      .toList();

  bool get hasAudioChoice => realAudioTracks.length > 1;
  bool get hasSubtitles => realSubtitleTracks.isNotEmpty;
  bool get hasTrackChoice => hasAudioChoice || hasSubtitles;

  bool canStyleSubtitles(SubtitleTrack selected) {
    final tracks = realSubtitleTracks;
    final current = tracks
        .where((track) => track.id == selected.id)
        .firstOrNull;
    // Keep the saved look accessible with Auto or Off, too.
    return current != null
        ? _isTextSubtitle(current)
        : tracks.any(_isTextSubtitle);
  }
}

// shortcut: unknown codecs keep text controls; extend bitmap codecs when encountered.
bool _isTextSubtitle(SubtitleTrack track) => !const {
  'hdmv_pgs_subtitle',
  'dvd_subtitle',
  'dvb_subtitle',
  'xsub',
}.contains(track.codec?.toLowerCase());
