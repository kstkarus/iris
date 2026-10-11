import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/widgets/player_choice_row.dart';
import 'package:iris/features/player/presentation/widgets/player_panel.dart';
import 'package:iris/features/player/presentation/widgets/player_track_option_formatter.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/section_label.dart';

/// Audio and subtitle tracks and nothing else: the look of subtitles and
/// the player's own options live in the settings.
///
/// Where there is room the two lists stand side by side; a phone's sheet
/// stacks them.
class PlayerTrackSelectorSheet extends StatelessWidget {
  const PlayerTrackSelectorSheet({
    required this.audioTracks,
    required this.selectedAudioTrack,
    required this.subtitleTracks,
    required this.selectedSubtitleTrack,
    required this.onAudioTrackSelected,
    required this.onSubtitleTrackSelected,
    super.key,
  });

  static const _columnGap = 32.0;

  /// Two columns of track names of about 28 characters each.
  static const _sideBySideMinWidth = 480.0;

  /// Side by side, with room for long release names.
  static const popoverWidth = 600.0;

  final List<AudioTrack> audioTracks;
  final AudioTrack selectedAudioTrack;
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack selectedSubtitleTrack;
  final ValueChanged<AudioTrack> onAudioTrackSelected;
  final ValueChanged<SubtitleTrack> onSubtitleTrackSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final audio = _TrackSection<AudioTrack>(
      title: l10n.playerAudioTracksTitle,
      tracks: _buildAudioOptions(audioTracks),
      selectedTrack: selectedAudioTrack,
      labelBuilder: (track) => formatAudioTrackLabel(l10n, track),
      codecOf: (track) => track.codec,
      emptyLabel: l10n.playerTracksUnavailable,
      onSelected: onAudioTrackSelected,
    );
    final subtitles = _TrackSection<SubtitleTrack>(
      title: l10n.playerSubtitleTracksTitle,
      tracks: _buildSubtitleOptions(subtitleTracks),
      selectedTrack: selectedSubtitleTrack,
      labelBuilder: (track) => formatSubtitleTrackLabel(l10n, track),
      codecOf: (track) => track.codec,
      emptyLabel: l10n.playerTracksUnavailable,
      onSelected: onSubtitleTrackSelected,
    );

    return PlayerPanel(
      title: l10n.playerAudioAndSubtitles,
      maxHeightFactor: 0.8,
      crossAxisAlignment: CrossAxisAlignment.start,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _sideBySideMinWidth) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [audio, const SizedBox(height: 20), subtitles],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: audio),
              const SizedBox(width: _columnGap),
              Expanded(child: subtitles),
            ],
          );
        },
      ),
    );
  }
}

class _TrackSection<T> extends StatelessWidget {
  const _TrackSection({
    required this.title,
    required this.tracks,
    required this.selectedTrack,
    required this.labelBuilder,
    required this.codecOf,
    required this.emptyLabel,
    required this.onSelected,
  });

  final String title;
  final List<T> tracks;
  final T selectedTrack;
  final String Function(T track) labelBuilder;
  final String? Function(T track) codecOf;
  final String emptyLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(title),
        const SizedBox(height: 4),
        if (tracks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              emptyLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          for (final track in tracks)
            PlayerChoiceRow(
              label: labelBuilder(track),
              detail: _codecDetail(labelBuilder(track), codecOf(track)),
              selected: selectedTrack == track,
              onTap: () => onSelected(track),
            ),
      ],
    );
  }
}

/// The codec tells two tracks of one language apart (ASS from SRT); left
/// out where the label already is the codec.
String? _codecDetail(String label, String? codec) {
  final name = codec?.trim().toLowerCase();
  if (name == null || name.isEmpty) return null;
  // A track named by nothing else is labelled with its codec already.
  if (label == name.toUpperCase()) return null;
  return _codecNames[name] ?? name.toUpperCase();
}

/// mpv's names for the subtitle formats people know by another one.
const _codecNames = {
  'subrip': 'SRT',
  'webvtt': 'VTT',
  'hdmv_pgs_subtitle': 'PGS',
  'dvd_subtitle': 'VOBSUB',
};

List<AudioTrack> _buildAudioOptions(List<AudioTrack> tracks) {
  final options = <AudioTrack>[AudioTrack.auto()];
  for (final track in tracks) {
    if (track.id == AudioTrack.auto().id || track.id == AudioTrack.no().id) {
      continue;
    }
    if (!options.contains(track)) {
      options.add(track);
    }
  }
  return options;
}

List<SubtitleTrack> _buildSubtitleOptions(List<SubtitleTrack> tracks) {
  final options = <SubtitleTrack>[SubtitleTrack.no(), SubtitleTrack.auto()];
  for (final track in tracks) {
    if (track.id == SubtitleTrack.auto().id ||
        track.id == SubtitleTrack.no().id) {
      continue;
    }
    if (!options.contains(track)) {
      options.add(track);
    }
  }
  return options;
}
