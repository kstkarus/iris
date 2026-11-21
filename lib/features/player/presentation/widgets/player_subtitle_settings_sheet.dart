import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';

import 'package:iris/features/player/presentation/playback/player_quality_choice.dart';
import 'package:iris/features/player/presentation/playback/player_track_availability.dart';
import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/widgets/player_adaptive_layout.dart';
import 'package:iris/features/player/presentation/widgets/player_choice_row.dart';
import 'package:iris/features/player/presentation/widgets/player_overlay_preferences.dart';
import 'package:iris/features/player/presentation/widgets/player_panel.dart';
import 'package:iris/features/player/presentation/playback/player_subtitle_preferences_mapper.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/segmented_choice.dart';

/// The video stays in view behind the settings, lightly dimmed, so a change
/// to the subtitles shows on them at once.
const _settingsBarrier = Color(0x33000000);

/// Room for the size samples and "Semi-transparent" in a third of a row.
const _popoverWidth = 440.0;

/// The playing session's speed, offered at the top of the settings.
class PlayerSpeedSetting {
  const PlayerSpeedSetting({required this.rate, required this.onSelected});

  static const rates = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  final ValueListenable<double> rate;
  final ValueChanged<double> onSelected;
}

/// The playing file's quality, offered under the speed while it has a
/// choice (an online episode).
class PlayerQualitySetting {
  const PlayerQualitySetting({required this.choice, required this.onSelected});

  final ValueListenable<PlayerQualityChoice?> choice;

  /// Null is "Auto".
  final ValueChanged<int?> onSelected;
}

/// Opens the settings; on wide windows as a popover of [anchor], the
/// settings button. Playback controls are shown when the session offers them.
Future<void> showPlayerSubtitleSettingsSheet(
  BuildContext context, {
  required ValueListenable<Tracks> tracks,
  required ValueListenable<Track> selectedTrack,
  BuildContext? anchor,
  PlayerSpeedSetting? speed,
  PlayerQualitySetting? quality,
  ValueNotifier<BoxFit>? videoFit,
}) {
  final subtitleCubit = context.read<PlayerSubtitlePreferencesCubit>();
  final decodingCubit = context.read<PlayerDecodingPreferencesCubit>();

  return showPlayerAdaptiveSheet<void>(
    context: context,
    anchor: anchor,
    popoverWidth: _popoverWidth,
    semanticsLabel: AppLocalizations.of(context).playerSettingsTitle,
    isScrollControlled: true,
    barrierColor: _settingsBarrier,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider<PlayerSubtitlePreferencesCubit>.value(
          value: subtitleCubit,
        ),
        BlocProvider<PlayerDecodingPreferencesCubit>.value(
          value: decodingCubit,
        ),
      ],
      child: ValueListenableBuilder<Tracks>(
        valueListenable: tracks,
        builder: (context, available, _) => ValueListenableBuilder<Track>(
          valueListenable: selectedTrack,
          builder: (context, selected, _) => PlayerSubtitleSettingsSheet(
            tracks: available,
            selectedSubtitleTrack: selected.subtitle,
            speed: speed,
            quality: quality,
            videoFit: videoFit,
          ),
        ),
      ),
    ),
  );
}

/// The player's settings: the look of subtitles first, as the thing people
/// change; the decoder, the ASS renderer and the technical overlay folded
/// under Advanced, for playback problems.
class PlayerSubtitleSettingsSheet extends StatelessWidget {
  const PlayerSubtitleSettingsSheet({
    required this.tracks,
    this.selectedSubtitleTrack = const SubtitleTrack('auto', null, null),
    this.speed,
    this.quality,
    this.videoFit,
    super.key,
  });

  final Tracks tracks;
  final SubtitleTrack selectedSubtitleTrack;
  final PlayerSpeedSetting? speed;
  final PlayerQualitySetting? quality;
  final ValueNotifier<BoxFit>? videoFit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final rule = DetailLayout.ruleColor(theme.colorScheme);
    final showAppearance = tracks.canStyleSubtitles(selectedSubtitleTrack);
    final hasPlaybackControls =
        speed != null || quality != null || videoFit != null;
    return PlayerPanel(
      title: l10n.playerSettingsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasPlaybackControls)
            _PlaybackSection(
              speed: speed,
              quality: quality,
              videoFit: videoFit,
              showBottomDivider: showAppearance,
            ),
          if (showAppearance) const _Appearance(),
          if (hasPlaybackControls || showAppearance) ...[
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 1, color: rule),
            const SizedBox(height: 4),
          ],
          _Advanced(hasSubtitles: tracks.hasSubtitles),
        ],
      ),
    );
  }
}

TextStyle _sectionTitleStyle(ThemeData theme) => DetailLayout.queueHeadingStyle(
  theme,
).copyWith(fontSize: 16, fontWeight: FontWeight.w600);

class _PlaybackSection extends StatelessWidget {
  const _PlaybackSection({
    required this.speed,
    required this.quality,
    required this.videoFit,
    required this.showBottomDivider,
  });

  final PlayerSpeedSetting? speed;
  final PlayerQualitySetting? quality;
  final ValueNotifier<BoxFit>? videoFit;
  final bool showBottomDivider;

  @override
  Widget build(BuildContext context) {
    final quality = this.quality;
    if (quality == null) {
      return _buildContent(context, choice: null);
    }
    return ValueListenableBuilder<PlayerQualityChoice?>(
      valueListenable: quality.choice,
      builder: (context, choice, _) => _buildContent(context, choice: choice),
    );
  }

  Widget _buildContent(BuildContext context, {PlayerQualityChoice? choice}) {
    final speed = this.speed;
    final videoFit = this.videoFit;
    if (speed == null && choice == null && videoFit == null) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionLabel(
          l10n.playerPlaybackSectionTitle,
          style: _sectionTitleStyle(theme),
          uppercase: false,
        ),
        const SizedBox(height: 10),
        if (speed != null) _Speed(speed: speed),
        if (choice != null)
          _Quality(choice: choice, onSelected: quality!.onSelected),
        if (videoFit != null)
          ValueListenableBuilder<BoxFit>(
            valueListenable: videoFit,
            builder: (context, fit, _) => _Labelled(
              label: l10n.playerVideoFitTitle,
              child: SegmentedChoice<BoxFit>(
                selected: fit,
                onSelected: (value) => videoFit.value = value,
                options: [
                  SegmentedOption(
                    value: BoxFit.contain,
                    label: l10n.playerZoomFit,
                  ),
                  SegmentedOption(
                    value: BoxFit.cover,
                    label: l10n.playerZoomFill,
                  ),
                ],
              ),
            ),
          ),
        if (showBottomDivider) ...[
          const SizedBox(height: 4),
          Divider(
            height: 1,
            thickness: 1,
            color: DetailLayout.ruleColor(theme.colorScheme),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Speed extends StatelessWidget {
  const _Speed({required this.speed});

  final PlayerSpeedSetting speed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: speed.rate,
      builder: (context, rate, _) => _Labelled(
        label: l10n.playerPlaybackSpeedTitle,
        child: SegmentedChoice<double>(
          key: const Key('player_speed_choice'),
          selected: rate,
          onSelected: speed.onSelected,
          options: [
            for (final option in PlayerSpeedSetting.rates)
              SegmentedOption(
                value: option,
                label: l10n.playerPlaybackRate(option),
              ),
          ],
        ),
      ),
    );
  }
}

class _Quality extends StatelessWidget {
  const _Quality({required this.choice, required this.onSelected});

  final PlayerQualityChoice choice;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Labelled(
      label: l10n.onlineQualityTitle,
      child: SegmentedChoice<int?>(
        key: const Key('player_quality_choice'),
        selected: choice.selected,
        onSelected: onSelected,
        options: [
          SegmentedOption(value: null, label: l10n.onlineQualityAuto),
          for (final height in choice.offered)
            SegmentedOption(
              value: height,
              label: l10n.onlineQualityHeight(height),
            ),
        ],
      ),
    );
  }
}

class _Appearance extends StatelessWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<PlayerSubtitlePreferencesCubit>();
    final preferences = context.watch<PlayerSubtitlePreferencesCubit>().state;
    final isDefault =
        preferences ==
        const SubtitlePreferences.defaults().copyWith(
          libassEnabled: preferences.libassEnabled,
        );
    // Only where the release's own renderer would otherwise draw them.
    final overridesRelease =
        preferences.libassEnabled && overridesReleaseSubtitleStyle(preferences);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(
          l10n.playerSubtitleAppearanceTitle,
          style: _sectionTitleStyle(theme),
          uppercase: false,
          trailing: TextButton(
            style: TextButton.styleFrom(
              textStyle: const TextStyle(
                fontFamily: DetailLayout.sansFont,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: isDefault ? null : cubit.resetAppearance,
            child: Text(l10n.playerSubtitleResetAction),
          ),
        ),
        const SizedBox(height: 8),
        _Labelled(
          label: l10n.playerSubtitleSizeLabel,
          child: SegmentedChoice<SubtitleTextScalePreset>(
            selected: preferences.textScale,
            onSelected: cubit.setTextScale,
            options: [
              for (final (preset, label, size) in [
                (
                  SubtitleTextScalePreset.compact,
                  l10n.playerSubtitleSizeSmaller,
                  11.0,
                ),
                (
                  SubtitleTextScalePreset.normal,
                  l10n.playerSubtitleSizeNormal,
                  13.0,
                ),
                (
                  SubtitleTextScalePreset.large,
                  l10n.playerSubtitleSizeLarger,
                  15.0,
                ),
                (
                  SubtitleTextScalePreset.xLarge,
                  l10n.playerSubtitleSizeLargest,
                  17.0,
                ),
              ])
                SegmentedOption(
                  value: preset,
                  label: label,
                  // A sample at the size says more than a name or a factor.
                  text: l10n.playerSubtitleSizeSample,
                  textStyle: TextStyle(fontSize: size),
                ),
            ],
          ),
        ),
        _Labelled(
          label: l10n.playerSubtitleColorLabel,
          child: SegmentedChoice<SubtitleTextColorPreset>(
            selected: preferences.textColor,
            onSelected: cubit.setTextColor,
            options: [
              for (final (preset, label) in [
                (SubtitleTextColorPreset.white, l10n.playerSubtitleColorWhite),
                (
                  SubtitleTextColorPreset.yellow,
                  l10n.playerSubtitleColorYellow,
                ),
                (SubtitleTextColorPreset.cyan, l10n.playerSubtitleColorCyan),
              ])
                SegmentedOption(
                  value: preset,
                  label: label,
                  leading: _Swatch(color: subtitleTextColor(preset)),
                ),
            ],
          ),
        ),
        _Labelled(
          label: l10n.playerSubtitleBackgroundLabel,
          child: SegmentedChoice<SubtitleBackgroundStylePreset>(
            selected: preferences.backgroundStyle,
            onSelected: cubit.setBackgroundStyle,
            options: [
              SegmentedOption(
                value: SubtitleBackgroundStylePreset.none,
                label: l10n.playerSubtitleBackgroundNone,
              ),
              SegmentedOption(
                value: SubtitleBackgroundStylePreset.translucent,
                label: l10n.playerSubtitleBackgroundTranslucent,
              ),
              SegmentedOption(
                value: SubtitleBackgroundStylePreset.solid,
                label: l10n.playerSubtitleBackgroundSolid,
              ),
            ],
          ),
        ),
        _Labelled(
          label: l10n.playerSubtitlePositionLabel,
          child: SegmentedChoice<SubtitleVerticalPositionPreset>(
            selected: preferences.verticalPosition,
            onSelected: cubit.setVerticalPosition,
            options: [
              SegmentedOption(
                value: SubtitleVerticalPositionPreset.low,
                label: l10n.playerSubtitlePositionLow,
              ),
              SegmentedOption(
                value: SubtitleVerticalPositionPreset.standard,
                label: l10n.playerSubtitlePositionStandard,
              ),
              SegmentedOption(
                value: SubtitleVerticalPositionPreset.high,
                label: l10n.playerSubtitlePositionHigh,
              ),
            ],
          ),
        ),
        // The warning comes and goes with the choice that causes it.
        _Reveal(
          visible: overridesRelease,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              l10n.playerSubtitleOverrideHint,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: DetailLayout.sansFont,
                fontSize: 12.5,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A control under its small caption.
class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: DetailLayout.sansFont,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
    );
  }
}

/// The decoder, the ASS renderer and the technical overlay: wanted for a
/// playback problem, so folded until asked for. Folded, a line says what
/// they are set to.
class _Advanced extends StatefulWidget {
  const _Advanced({required this.hasSubtitles});

  final bool hasSubtitles;

  @override
  State<_Advanced> createState() => _AdvancedState();
}

class _AdvancedState extends State<_Advanced> {
  static const _unfold = Duration(milliseconds: 240);

  final _contentKey = GlobalKey();
  bool _expanded = false;

  Duration get _duration => motionDuration(context, _unfold);

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (!_expanded) return;
    // Opened at the bottom of the sheet, the content would unfold out of
    // sight: once it has its size, bring it into view. The frame after the
    // unfolding is the one that has that size.
    final duration = _duration;
    Future<void>.delayed(duration, () {
      if (!mounted) return;
      WidgetsBinding.instance
        ..addPostFrameCallback((_) => _reveal(duration))
        ..scheduleFrame();
    });
  }

  void _reveal(Duration duration) {
    final content = _contentKey.currentContext;
    if (!mounted || content == null || !content.mounted) return;
    Scrollable.ensureVisible(
      content,
      duration: duration == Duration.zero
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final decoding = context.watch<PlayerDecodingPreferencesCubit>().state;
    final libass = context.select(
      (PlayerSubtitlePreferencesCubit cubit) => cubit.state.libassEnabled,
    );
    final decoder = resolveSupportedHwdecMode(decoding.hwdecMode);
    final duration = _duration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: _expanded,
          child: InkWell(
            onTap: _toggle,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.playerAdvancedTitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: DetailLayout.sansFont,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _Reveal(
                          visible: !_expanded,
                          duration: duration,
                          child: PixelSeparatedText(
                            widget.hasSubtitles
                                ? l10n.playerAdvancedSummary(
                                    _decoderShortLabel(l10n, decoder),
                                    libass
                                        ? l10n.playerSettingOn
                                        : l10n.playerSettingOff,
                                  )
                                : '${l10n.playerDecoderSettingsTitle}: '
                                      '${_decoderShortLabel(l10n, decoder)}',
                            sansStyle: theme.textTheme.bodySmall?.copyWith(
                              fontFamily: DetailLayout.sansFont,
                              fontSize: 12.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            monoStyle: DetailLayout.monoTelemetryStyle(
                              theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12.5,
                              ),
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Points down to unfold and up to fold.
                  AnimatedRotation(
                    turns: _expanded ? -0.25 : 0.25,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: const PixelIcon(PixelGlyph.arrowRight, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        _Reveal(
          visible: _expanded,
          duration: duration,
          child: KeyedSubtree(
            key: _contentKey,
            child: _AdvancedContent(
              decoder: decoder,
              libass: libass,
              hasSubtitles: widget.hasSubtitles,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdvancedContent extends StatelessWidget {
  const _AdvancedContent({
    required this.decoder,
    required this.libass,
    required this.hasSubtitles,
  });

  final PlayerHwdecModePreset decoder;
  final bool libass;
  final bool hasSubtitles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontSize: 12.5,
      color: theme.colorScheme.onSurfaceVariant,
    );
    final switchTitle = theme.textTheme.bodyLarge?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontSize: 15,
    );
    final decodingCubit = context.read<PlayerDecodingPreferencesCubit>();
    final subtitleCubit = context.read<PlayerSubtitlePreferencesCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.playerDecoderSettingsTitle,
          style: muted?.copyWith(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 2),
        Text(l10n.playerDecoderSettingsDescription, style: muted),
        const SizedBox(height: 4),
        for (final preset in supportedHwdecModes())
          PlayerChoiceRow(
            label: _decoderLabel(l10n, preset),
            selected: decoder == preset,
            onTap: () {
              if (decoder != preset) AppHaptics.selection();
              decodingCubit.setHwdecMode(preset);
            },
          ),
        const SizedBox(height: 8),
        if (hasSubtitles)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.playerSubtitleLibassLabel, style: switchTitle),
            subtitle: Text(l10n.playerSubtitleLibassDescription, style: muted),
            value: libass,
            onChanged: subtitleCubit.setLibassEnabled,
          ),
        ValueListenableBuilder<bool>(
          valueListenable: playerDetailedStatsEnabled,
          builder: (context, enabled, _) => SwitchListTile(
            key: const Key('player_detailed_stats_switch'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.playerDetailedStats, style: switchTitle),
            subtitle: Text(l10n.playerDetailedStatsHint, style: muted),
            value: enabled,
            onChanged: (value) => playerDetailedStatsEnabled.value = value,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasSubtitles ? l10n.playerRestartHint : l10n.playerDecoderRestartHint,
          style: muted,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Shows or hides [child], growing and fading rather than jumping.
class _Reveal extends StatelessWidget {
  const _Reveal({required this.visible, required this.child, this.duration});

  static const _defaultDuration = Duration(milliseconds: 200);

  final bool visible;
  final Widget child;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final duration = this.duration ?? motionDuration(context, _defaultDuration);
    return AnimatedCrossFade(
      duration: duration,
      sizeCurve: Curves.easeOutCubic,
      crossFadeState: visible
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: const SizedBox(width: double.infinity),
      secondChild: SizedBox(width: double.infinity, child: child),
    );
  }
}

String _decoderLabel(AppLocalizations l10n, PlayerHwdecModePreset preset) {
  return switch (preset) {
    PlayerHwdecModePreset.autoSafe => l10n.playerDecoderAutoSafe,
    PlayerHwdecModePreset.mediacodec => l10n.playerDecoderMediacodec,
    PlayerHwdecModePreset.mediacodecCopy => l10n.playerDecoderMediacodecCopy,
    PlayerHwdecModePreset.softwareOnly => l10n.playerDecoderSoftwareOnly,
  };
}

/// The decoder in the folded summary: "auto" without the advice.
String _decoderShortLabel(AppLocalizations l10n, PlayerHwdecModePreset preset) {
  return preset == PlayerHwdecModePreset.autoSafe
      ? l10n.playerDecoderAutoShort
      : _decoderLabel(l10n, preset);
}
