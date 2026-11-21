import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_state.dart';
import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';
import 'package:iris/features/settings/presentation/widgets/settings_row.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';

class AboutAppSection extends StatelessWidget {
  const AboutAppSection({this.onOpenUpdate, this.openExternalUrl, super.key});

  static const checkUpdatesButtonKey = Key('settings_check_updates_button');
  static const openUpdateButtonKey = Key('settings_open_update_button');

  final VoidCallback? onOpenUpdate;
  final OpenExternalUrl? openExternalUrl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<AppUpdateCubit>();
    final state = context.watch<AppUpdateCubit>().state;
    final installed = state.installedVersion;
    final labelStyle = SettingsRow.labelStyle(theme);
    final windows = theme.platform == TargetPlatform.windows;
    final inApp = cubit.supportsInAppUpdate;
    final actionLabel = !inApp
        ? l10n.appUpdateDownload
        : switch (state.phase) {
            AppUpdatePhase.available => l10n.settingsUpdateOpen,
            AppUpdatePhase.ready =>
              windows ? l10n.appUpdateRestart : l10n.appUpdateInstall,
            _ => l10n.settingsUpdateOpenDetails,
          };

    final release = state.availableRelease;
    final feedback = release != null
        ? _updateFeedback(l10n, state, scheme, windows: windows)
        : switch (state.checkStatus) {
            AppUpdateCheckStatus.checking => SettingsStatus.loading(
              l10n.settingsUpdateChecking,
            ),
            AppUpdateCheckStatus.upToDate => SettingsStatus(
              l10n.settingsUpdateUpToDate,
            ),
            AppUpdateCheckStatus.failed => SettingsStatus(
              l10n.settingsUpdateCheckFailed,
              color: scheme.error,
            ),
            AppUpdateCheckStatus.idle || AppUpdateCheckStatus.available => null,
          };
    void openUpdate() => showAppUpdateSheet(context, open: openExternalUrl);
    final action = release != null
        ? inApp && state.phase == AppUpdatePhase.installing
              ? null
              : FilledButton(
                  key: openUpdateButtonKey,
                  onPressed: !inApp
                      ? openUpdate
                      : switch (state.phase) {
                          AppUpdatePhase.ready => cubit.install,
                          _ => onOpenUpdate ?? openUpdate,
                        },
                  child: Text(actionLabel, textAlign: TextAlign.center),
                )
        : cubit.supportsCheck
        ? TextButton(
            key: checkUpdatesButtonKey,
            onPressed: state.checkStatus == AppUpdateCheckStatus.checking
                ? null
                : cubit.checkManually,
            style: settingsActionStyle(context),
            child: Text(l10n.settingsCheckUpdates, textAlign: TextAlign.end),
          )
        : null;

    final version = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: 12,
      children: [
        Flexible(child: Text(l10n.settingsAppVersion, style: labelStyle)),
        Flexible(
          child: Text(
            installed?.toString() ?? l10n.settingsAppVersionUnknown,
            style: installed == null
                ? SettingsRow.captionStyle(theme)
                : DetailLayout.monoTelemetryStyle(
                    labelStyle,
                    color: scheme.onSurfaceVariant,
                  ),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsRow(
          action: action,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              version,
              DitherSwitcher(
                duration: const Duration(milliseconds: 300),
                resizeDuration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(
                    release == null ? state.checkStatus : state.phase,
                  ),
                  child: feedback == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Semantics(liveRegion: true, child: feedback),
                        ),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: motionDuration(context, const Duration(milliseconds: 200)),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: state.release != null && state.showsProgress
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: AppUpdateProgressBar(state: state),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _updateFeedback(
    AppLocalizations l10n,
    AppUpdateState state,
    ColorScheme scheme, {
    required bool windows,
  }) {
    final label = appUpdatePhaseLabel(l10n, state, windows: windows);
    if (state.phase == AppUpdatePhase.verifying ||
        state.phase == AppUpdatePhase.installing) {
      return SettingsStatus.loading(label);
    }
    final signal = state.hasFailure ? scheme.error : scheme.tertiary;
    return SettingsStatus(
      state.phase == AppUpdatePhase.downloading && state.totalBytes > 0
          ? '$label · ${state.progressPercent}%'
          : label,
      signalColor: signal,
      color: signal,
      mixedData: true,
    );
  }
}
