import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/domain/entities/subtitle_preferences.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

Future<void> showPlayerSubtitleSettingsSheet(BuildContext context) {
  final cubit = context.read<PlayerSubtitlePreferencesCubit>();

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => BlocProvider<PlayerSubtitlePreferencesCubit>.value(
      value: cubit,
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
              BlocBuilder<PlayerSubtitlePreferencesCubit, SubtitlePreferences>(
                builder: (context, preferences) {
                  final cubit = context.read<PlayerSubtitlePreferencesCubit>();
                  final l10n = AppLocalizations.of(context);
                  final theme = Theme.of(context);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.playerSubtitleAppearanceTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.playerSubtitleVisibilityLabel),
                        value: preferences.visible,
                        onChanged: cubit.setVisibility,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.playerSubtitleLibassLabel),
                        subtitle: Text(l10n.playerSubtitleLibassDescription),
                        value: preferences.libassEnabled,
                        onChanged: cubit.setLibassEnabled,
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
                              onSelected: () => cubit.setTextScale(
                                SubtitleTextScalePreset.compact,
                              ),
                            ),
                            _ChoiceChip(
                              label: '1.0x',
                              selected:
                                  preferences.textScale ==
                                  SubtitleTextScalePreset.normal,
                              onSelected: () => cubit.setTextScale(
                                SubtitleTextScalePreset.normal,
                              ),
                            ),
                            _ChoiceChip(
                              label: '1.15x',
                              selected:
                                  preferences.textScale ==
                                  SubtitleTextScalePreset.large,
                              onSelected: () => cubit.setTextScale(
                                SubtitleTextScalePreset.large,
                              ),
                            ),
                            _ChoiceChip(
                              label: '1.30x',
                              selected:
                                  preferences.textScale ==
                                  SubtitleTextScalePreset.xLarge,
                              onSelected: () => cubit.setTextScale(
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
                              onSelected: () => cubit.setTextColor(
                                SubtitleTextColorPreset.white,
                              ),
                            ),
                            _ChoiceChip(
                              label: l10n.playerSubtitleColorYellow,
                              selected:
                                  preferences.textColor ==
                                  SubtitleTextColorPreset.yellow,
                              onSelected: () => cubit.setTextColor(
                                SubtitleTextColorPreset.yellow,
                              ),
                            ),
                            _ChoiceChip(
                              label: l10n.playerSubtitleColorCyan,
                              selected:
                                  preferences.textColor ==
                                  SubtitleTextColorPreset.cyan,
                              onSelected: () => cubit.setTextColor(
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
                              onSelected: () => cubit.setBackgroundStyle(
                                SubtitleBackgroundStylePreset.none,
                              ),
                            ),
                            _ChoiceChip(
                              label: l10n.playerSubtitleBackgroundTranslucent,
                              selected:
                                  preferences.backgroundStyle ==
                                  SubtitleBackgroundStylePreset.translucent,
                              onSelected: () => cubit.setBackgroundStyle(
                                SubtitleBackgroundStylePreset.translucent,
                              ),
                            ),
                            _ChoiceChip(
                              label: l10n.playerSubtitleBackgroundSolid,
                              selected:
                                  preferences.backgroundStyle ==
                                  SubtitleBackgroundStylePreset.solid,
                              onSelected: () => cubit.setBackgroundStyle(
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
                              onSelected: () => cubit.setVerticalPosition(
                                SubtitleVerticalPositionPreset.low,
                              ),
                            ),
                            _ChoiceChip(
                              label: l10n.playerSubtitlePositionStandard,
                              selected:
                                  preferences.verticalPosition ==
                                  SubtitleVerticalPositionPreset.standard,
                              onSelected: () => cubit.setVerticalPosition(
                                SubtitleVerticalPositionPreset.standard,
                              ),
                            ),
                            _ChoiceChip(
                              label: l10n.playerSubtitlePositionHigh,
                              selected:
                                  preferences.verticalPosition ==
                                  SubtitleVerticalPositionPreset.high,
                              onSelected: () => cubit.setVerticalPosition(
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
                          onPressed: cubit.reset,
                          child: Text(l10n.playerSubtitleResetAction),
                        ),
                      ),
                    ],
                  );
                },
              ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

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
