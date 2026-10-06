import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/domain/entities/player_decoding_preferences.dart';
import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/widgets/player_adaptive_layout.dart';
import 'package:iris/features/player/presentation/widgets/player_subtitle_preferences_mapper.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

Future<void> showPlayerSubtitleSettingsSheet(BuildContext context) {
  final subtitleCubit = context.read<PlayerSubtitlePreferencesCubit>();
  final decodingCubit = context.read<PlayerDecodingPreferencesCubit>();

  return showPlayerAdaptiveSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider<PlayerSubtitlePreferencesCubit>.value(
          value: subtitleCubit,
        ),
        BlocProvider<PlayerDecodingPreferencesCubit>.value(
          value: decodingCubit,
        ),
      ],
      child: const PlayerSubtitleSettingsSheet(),
    ),
  );
}

class PlayerSubtitleSettingsSheet extends StatelessWidget {
  const PlayerSubtitleSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.85),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            20 + mediaQuery.viewInsets.bottom,
          ),
          child:
              BlocBuilder<
                PlayerDecodingPreferencesCubit,
                PlayerDecodingPreferences
              >(
                builder: (context, decodingPreferences) {
                  return BlocBuilder<
                    PlayerSubtitlePreferencesCubit,
                    SubtitlePreferences
                  >(
                    builder: (context, preferences) {
                      final subtitleCubit = context
                          .read<PlayerSubtitlePreferencesCubit>();
                      final decodingCubit = context
                          .read<PlayerDecodingPreferencesCubit>();
                      final l10n = AppLocalizations.of(context);
                      final theme = Theme.of(context);
                      final effectiveHwdecMode = resolveSupportedHwdecMode(
                        decodingPreferences.hwdecMode,
                      );

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.playerSettingsTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SettingsSection(
                            title: l10n.playerDecoderSettingsTitle,
                            subtitle: l10n.playerDecoderSettingsDescription,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final preset in supportedHwdecModes())
                                  _ChoiceChip(
                                    label: _decoderLabel(l10n, preset),
                                    selected: effectiveHwdecMode == preset,
                                    onSelected: () =>
                                        decodingCubit.setHwdecMode(preset),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _SettingsSection(
                            title: l10n.playerSubtitleAppearanceTitle,
                            child: const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.playerSubtitleVisibilityLabel),
                            value: preferences.visible,
                            onChanged: subtitleCubit.setVisibility,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.playerSubtitleLibassLabel),
                            subtitle: Text(
                              l10n.playerSubtitleLibassDescription,
                            ),
                            value: preferences.libassEnabled,
                            onChanged: subtitleCubit.setLibassEnabled,
                          ),
                          const SizedBox(height: 12),
                          _SettingsSection(
                            title: l10n.playerSubtitleSizeLabel,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ChoiceChip(
                                  label: '0.85x',
                                  selected:
                                      preferences.textScale ==
                                      SubtitleTextScalePreset.compact,
                                  onSelected: () => subtitleCubit.setTextScale(
                                    SubtitleTextScalePreset.compact,
                                  ),
                                ),
                                _ChoiceChip(
                                  label: '1.0x',
                                  selected:
                                      preferences.textScale ==
                                      SubtitleTextScalePreset.normal,
                                  onSelected: () => subtitleCubit.setTextScale(
                                    SubtitleTextScalePreset.normal,
                                  ),
                                ),
                                _ChoiceChip(
                                  label: '1.15x',
                                  selected:
                                      preferences.textScale ==
                                      SubtitleTextScalePreset.large,
                                  onSelected: () => subtitleCubit.setTextScale(
                                    SubtitleTextScalePreset.large,
                                  ),
                                ),
                                _ChoiceChip(
                                  label: '1.30x',
                                  selected:
                                      preferences.textScale ==
                                      SubtitleTextScalePreset.xLarge,
                                  onSelected: () => subtitleCubit.setTextScale(
                                    SubtitleTextScalePreset.xLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SettingsSection(
                            title: l10n.playerSubtitleColorLabel,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ChoiceChip(
                                  label: l10n.playerSubtitleColorWhite,
                                  selected:
                                      preferences.textColor ==
                                      SubtitleTextColorPreset.white,
                                  onSelected: () => subtitleCubit.setTextColor(
                                    SubtitleTextColorPreset.white,
                                  ),
                                ),
                                _ChoiceChip(
                                  label: l10n.playerSubtitleColorYellow,
                                  selected:
                                      preferences.textColor ==
                                      SubtitleTextColorPreset.yellow,
                                  onSelected: () => subtitleCubit.setTextColor(
                                    SubtitleTextColorPreset.yellow,
                                  ),
                                ),
                                _ChoiceChip(
                                  label: l10n.playerSubtitleColorCyan,
                                  selected:
                                      preferences.textColor ==
                                      SubtitleTextColorPreset.cyan,
                                  onSelected: () => subtitleCubit.setTextColor(
                                    SubtitleTextColorPreset.cyan,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SettingsSection(
                            title: l10n.playerSubtitleBackgroundLabel,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ChoiceChip(
                                  label: l10n.playerSubtitleBackgroundNone,
                                  selected:
                                      preferences.backgroundStyle ==
                                      SubtitleBackgroundStylePreset.none,
                                  onSelected: () =>
                                      subtitleCubit.setBackgroundStyle(
                                        SubtitleBackgroundStylePreset.none,
                                      ),
                                ),
                                _ChoiceChip(
                                  label:
                                      l10n.playerSubtitleBackgroundTranslucent,
                                  selected:
                                      preferences.backgroundStyle ==
                                      SubtitleBackgroundStylePreset.translucent,
                                  onSelected: () =>
                                      subtitleCubit.setBackgroundStyle(
                                        SubtitleBackgroundStylePreset
                                            .translucent,
                                      ),
                                ),
                                _ChoiceChip(
                                  label: l10n.playerSubtitleBackgroundSolid,
                                  selected:
                                      preferences.backgroundStyle ==
                                      SubtitleBackgroundStylePreset.solid,
                                  onSelected: () =>
                                      subtitleCubit.setBackgroundStyle(
                                        SubtitleBackgroundStylePreset.solid,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SettingsSection(
                            title: l10n.playerSubtitlePositionLabel,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _ChoiceChip(
                                  label: l10n.playerSubtitlePositionLow,
                                  selected:
                                      preferences.verticalPosition ==
                                      SubtitleVerticalPositionPreset.low,
                                  onSelected: () =>
                                      subtitleCubit.setVerticalPosition(
                                        SubtitleVerticalPositionPreset.low,
                                      ),
                                ),
                                _ChoiceChip(
                                  label: l10n.playerSubtitlePositionStandard,
                                  selected:
                                      preferences.verticalPosition ==
                                      SubtitleVerticalPositionPreset.standard,
                                  onSelected: () =>
                                      subtitleCubit.setVerticalPosition(
                                        SubtitleVerticalPositionPreset.standard,
                                      ),
                                ),
                                _ChoiceChip(
                                  label: l10n.playerSubtitlePositionHigh,
                                  selected:
                                      preferences.verticalPosition ==
                                      SubtitleVerticalPositionPreset.high,
                                  onSelected: () =>
                                      subtitleCubit.setVerticalPosition(
                                        SubtitleVerticalPositionPreset.high,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: subtitleCubit.reset,
                              child: Text(l10n.playerSubtitleResetAction),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
        ),
      ),
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

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
