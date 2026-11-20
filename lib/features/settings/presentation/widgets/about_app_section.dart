import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_state.dart';
import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';
import 'package:iris/features/settings/presentation/widgets/settings_row.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';

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
    final ready = state.phase == AppUpdatePhase.ready;
    final signal = state.phase == AppUpdatePhase.failed
        ? scheme.error
        : scheme.tertiary;

    final feedback = state.release != null
        ? SettingsStatus(
            appUpdatePhaseLabel(l10n, state),
            signalColor: signal,
            color: signal,
            mixedData: true,
          )
        : switch (state.checkStatus) {
            AppUpdateCheckStatus.checking => SettingsStatus(
              l10n.settingsUpdateChecking,
              leading: const SizedBox(
                width: 64,
                child: BlockSpinner(height: 6),
              ),
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
    final action = state.release != null
        ? FilledButton(
            key: openUpdateButtonKey,
            onPressed: state.phase == AppUpdatePhase.installing
                ? null
                : ready
                ? cubit.install
                : cubit.supportsInAppUpdate && onOpenUpdate != null
                ? onOpenUpdate
                : () => showAppUpdateSheet(context, open: openExternalUrl),
            child: Text(
              ready
                  ? l10n.appUpdateInstall
                  : cubit.supportsInAppUpdate
                  ? l10n.settingsUpdateOpenDetails
                  : l10n.appUpdateDownload,
              textAlign: TextAlign.center,
            ),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                version,
                if (feedback != null)
                  Semantics(liveRegion: true, child: feedback),
              ],
            ),
          ),
        ),
        if (state.release != null &&
            state.phase == AppUpdatePhase.downloading) ...[
          const SizedBox(height: 8),
          if (state.totalBytes > 0)
            SegmentedBar(value: state.progress)
          else
            const BlockSpinner(height: 6),
        ],
      ],
    );
  }
}
