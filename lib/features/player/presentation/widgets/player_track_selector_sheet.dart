import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/widgets/player_overlay_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_track_option_formatter.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/section_label.dart';

class PlayerTrackSelectorSheet extends StatelessWidget {
  const PlayerTrackSelectorSheet({
    required this.audioTracks,
    required this.selectedAudioTrack,
    required this.subtitleTracks,
    required this.selectedSubtitleTrack,
    required this.onAudioTrackSelected,
    required this.onSubtitleTrackSelected,
    required this.onSubtitleAppearancePressed,
    super.key,
  });

  final List<AudioTrack> audioTracks;
  final AudioTrack selectedAudioTrack;
  final List<SubtitleTrack> subtitleTracks;
  final SubtitleTrack selectedSubtitleTrack;
  final ValueChanged<AudioTrack> onAudioTrackSelected;
  final ValueChanged<SubtitleTrack> onSubtitleTrackSelected;
  final VoidCallback onSubtitleAppearancePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final audioOptions = _buildAudioOptions(audioTracks);
    final subtitleOptions = _buildSubtitleOptions(subtitleTracks);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.8),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + mediaQuery.viewInsets.bottom,
          ),
          child: Material(
            // Ink paints on the nearest Material: this one scrolls with the list,
            // so the sheet's edge clips the highlight.
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.playerTracksTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                _TrackSection<AudioTrack>(
                  title: l10n.playerAudioTracksTitle,
                  tracks: audioOptions,
                  selectedTrack: selectedAudioTrack,
                  labelBuilder: (track) => formatAudioTrackLabel(
                    track,
                    autoLabel: l10n.playerTrackAuto,
                    offLabel: l10n.playerTrackOff,
                  ),
                  emptyLabel: l10n.playerTracksUnavailable,
                  onSelected: onAudioTrackSelected,
                ),
                const SizedBox(height: 20),
                _TrackSection<SubtitleTrack>(
                  title: l10n.playerSubtitleTracksTitle,
                  tracks: subtitleOptions,
                  selectedTrack: selectedSubtitleTrack,
                  labelBuilder: (track) => formatSubtitleTrackLabel(
                    track,
                    autoLabel: l10n.playerTrackAuto,
                    offLabel: l10n.playerTrackOff,
                  ),
                  emptyLabel: l10n.playerTracksUnavailable,
                  onSelected: onSubtitleTrackSelected,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.playerSubtitleAppearanceTitle),
                  // Opens a sheet of its own; the arrow says so.
                  trailing: const PixelIcon(PixelGlyph.arrowRight, size: 16),
                  onTap: onSubtitleAppearancePressed,
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: playerDetailedStatsEnabled,
                  builder: (context, enabled, _) => SwitchListTile(
                    key: const Key('player_detailed_stats_switch'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.playerDetailedStats),
                    subtitle: Text(l10n.playerDetailedStatsHint),
                    value: enabled,
                    onChanged: (value) =>
                        playerDetailedStatsEnabled.value = value,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    required this.emptyLabel,
    required this.onSelected,
  });

  final String title;
  final List<T> tracks;
  final T selectedTrack;
  final String Function(T track) labelBuilder;
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              // For assistive technology; the check mark shows it on screen,
              // so the title keeps its colour.
              selected: selectedTrack == track,
              selectedColor: theme.colorScheme.onSurface,
              title: Text(labelBuilder(track)),
              trailing: selectedTrack == track
                  ? PixelIcon(
                      PixelGlyph.check,
                      size: 18,
                      color: theme.colorScheme.onSurface,
                    )
                  : null,
              onTap: () => onSelected(track),
            ),
      ],
    );
  }
}

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
  final options = <SubtitleTrack>[SubtitleTrack.auto(), SubtitleTrack.no()];
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
