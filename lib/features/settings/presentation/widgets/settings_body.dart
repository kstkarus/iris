import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';
import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/presentation/cubit/animejoy_account_cubit.dart';
import 'package:iris/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:iris/features/settings/presentation/widgets/about_app_section.dart';
import 'package:iris/features/settings/presentation/widgets/animejoy_account_section.dart';
import 'package:iris/features/settings/presentation/widgets/settings_choice.dart';
import 'package:iris/features/settings/presentation/widgets/shikimori_account_row.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/labeled_section.dart';
import 'package:iris/shared/widgets/segmented_choice.dart';

class SettingsBody extends StatefulWidget {
  const SettingsBody({
    this.onAnimejoySignIn,
    this.onOpenUpdate,
    this.openExternalUrl,
    super.key,
  });

  final VoidCallback? onAnimejoySignIn;
  final VoidCallback? onOpenUpdate;
  final OpenExternalUrl? openExternalUrl;

  @override
  State<SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<SettingsBody> {
  @override
  void initState() {
    super.initState();
    context.read<AnimejoyAccountCubit>().ensureRestored();
    context.read<AppUpdateCubit>().loadInstalledVersion();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final compact = WindowSizeClass.of(context).isCompact;
    final sectionDivider = Divider(
      height: 1,
      thickness: 1,
      color: DetailLayout.ruleColor(theme.colorScheme),
    );
    final cubit = context.read<AppSettingsCubit>();
    final settings = context.watch<AppSettingsCubit>().state;
    final sections = [
      (
        l10n.settingsSectionAccounts,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShikimoriAccountRow(),
            AnimejoyAccountSection(onSignIn: widget.onAnimejoySignIn),
          ],
        ),
      ),
      (
        l10n.settingsSectionPlayback,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsMenuChoice(
              key: const Key('settings_default_audio_choice'),
              label: l10n.settingsDefaultAudioLabel,
              selected: settings.defaultAudioLanguage,
              onSelected: cubit.setDefaultAudioLanguage,
              options: [
                SegmentedOption(
                  value: DefaultAudioLanguage.auto,
                  label: l10n.settingsTrackAuto,
                ),
                SegmentedOption(
                  value: DefaultAudioLanguage.japanese,
                  label: l10n.settingsAudioJapanese,
                ),
                SegmentedOption(
                  value: DefaultAudioLanguage.russian,
                  label: l10n.settingsAudioRussian,
                ),
                SegmentedOption(
                  value: DefaultAudioLanguage.english,
                  label: l10n.settingsAudioEnglish,
                ),
              ],
            ),
            SettingsMenuChoice(
              key: const Key('settings_default_subtitles_choice'),
              label: l10n.settingsDefaultSubtitlesLabel,
              selected: settings.defaultSubtitleLanguage,
              onSelected: cubit.setDefaultSubtitleLanguage,
              options: [
                SegmentedOption(
                  value: DefaultSubtitleLanguage.auto,
                  label: l10n.settingsTrackAuto,
                ),
                SegmentedOption(
                  value: DefaultSubtitleLanguage.russian,
                  label: l10n.settingsSubtitlesRussian,
                ),
                SegmentedOption(
                  value: DefaultSubtitleLanguage.english,
                  label: l10n.settingsSubtitlesEnglish,
                ),
                SegmentedOption(
                  value: DefaultSubtitleLanguage.off,
                  label: l10n.settingsSubtitlesOff,
                ),
              ],
            ),
          ],
        ),
      ),
      (
        l10n.settingsSectionAppearance,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsAppearanceChoice(
              key: const Key('settings_theme_choice'),
              label: l10n.settingsThemeLabel,
              selected: settings.themeMode,
              onSelected: cubit.setThemeMode,
              options: [
                SegmentedOption(
                  value: AppThemePreference.system,
                  label: l10n.settingsThemeSystem,
                ),
                SegmentedOption(
                  value: AppThemePreference.light,
                  label: l10n.settingsThemeLight,
                ),
                SegmentedOption(
                  value: AppThemePreference.dark,
                  label: l10n.settingsThemeDark,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SettingsAppearanceChoice(
              key: const Key('settings_language_choice'),
              label: l10n.settingsLanguageLabel,
              selected: settings.locale,
              onSelected: cubit.setLocale,
              options: [
                SegmentedOption(
                  value: AppLocalePreference.system,
                  label: l10n.settingsLanguageSystem,
                ),
                SegmentedOption(
                  value: AppLocalePreference.russian,
                  label: l10n.settingsLanguageRussian,
                ),
                SegmentedOption(
                  value: AppLocalePreference.english,
                  label: l10n.settingsLanguageEnglish,
                ),
              ],
            ),
          ],
        ),
      ),
      (
        l10n.settingsSectionAbout,
        AboutAppSection(
          onOpenUpdate: widget.onOpenUpdate,
          openExternalUrl: widget.openExternalUrl,
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final labelWidth =
            compact || width < 540 || DetailLayout.isLargeText(context)
            ? null
            : width < 720
            ? 200.0
            : 240.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, (label, content)) in sections.indexed) ...[
              if (index > 0) sectionDivider,
              Padding(
                padding: EdgeInsets.symmetric(vertical: width < 720 ? 12 : 20),
                child: LabeledSection(
                  label: label,
                  labelWidth: labelWidth,
                  labelStyle: DetailLayout.sectionTitleStyle(theme),
                  uppercase: false,
                  alignLabelBaseline: true,
                  child: content,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
