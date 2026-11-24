import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/theme/inverse_theme.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/equality.dart';
import 'package:iris/shared/widgets/busy_button_child.dart';
import 'package:iris/shared/widgets/checked_menu_item.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

String downloadSelectionTitle(AppLocalizations l10n, bool isOnline) =>
    isOnline ? l10n.downloadSelectionEpisodeTitle : l10n.downloadSelectionTitle;

String downloadSelectionPrompt(AppLocalizations l10n, bool isOnline) =>
    isOnline ? l10n.downloadSelectEpisodes : l10n.downloadSelectFiles;

ButtonStyle releaseDownloadOutline(
  BuildContext context, {
  bool compact = false,
}) => OutlinedButton.styleFrom(
  padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
  minimumSize: Size(0, compact ? 38 : 44),
  side: BorderSide(
    color: DetailLayout.ruleColor(Theme.of(context).colorScheme),
  ),
);

Future<void> enqueueReleaseDownloads(
  BuildContext context, {
  int? singleIndex,
}) async {
  final cubit = context.read<PlayerSourceCubit>();
  final success = await cubit.enqueue(singleIndex: singleIndex);
  if (!context.mounted || ModalRoute.isCurrentOf(context) == false) return;
  if (success) {
    AppHaptics.success();
  } else if (cubit.state case PlayerSourceReady(enqueueFailed: true)) {
    AppHaptics.error();
  }
}

class ReleaseEnqueueError extends StatelessWidget {
  const ReleaseEnqueueError({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        AppLocalizations.of(context).playerSourceQueueFailed,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
          fontFamily: DetailLayout.sansFont,
        ),
      ),
    );
  }
}

class DownloadPresetsMenu extends StatelessWidget {
  const DownloadPresetsMenu({
    required this.state,
    required this.isOnline,
    required this.progressByFile,
    required this.listed,
    required this.outlined,
    this.compact = false,
    super.key,
  });

  final PlayerSourceReady state;
  final bool isOnline;
  final Map<int, WatchProgress> progressByFile;
  final Set<int> listed;
  final bool outlined;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PlayerSourceCubit>();
    final l10n = AppLocalizations.of(context);
    final presets = state.downloadPresets(progressByFile, listed);
    final available = !state.addingBatch && presets.all.isNotEmpty;
    final inverseScheme = InverseTheme.of(Theme.of(context)).colorScheme;
    final nextCount = presets.next.isEmpty ? 5 : presets.next.length;
    Widget preset(String label, Set<int> files) => CheckedMenuItem(
      checked: files.isNotEmpty && sameSet(state.selected, files),
      onPressed: files.isEmpty || state.addingBatch
          ? null
          : () {
              final before = cubit.state;
              cubit.replaceSelection(files);
              if (cubit.state != before) AppHaptics.selection();
            },
      child: Text(label),
    );
    return MenuAnchor(
      style: MenuStyle(
        alignment: outlined
            ? AlignmentDirectional.bottomStart
            : AlignmentDirectional.bottomEnd,
      ),
      alignmentOffset: const Offset(0, 2),
      menuChildren: [
        preset(
          isOnline
              ? l10n.playerSourceNextEpisodes(nextCount)
              : l10n.playerSourceNextFiles(nextCount),
          presets.next,
        ),
        preset(l10n.playerSourceAllUnwatched, presets.unwatched),
        preset(l10n.downloadSelectAll, presets.all),
        Divider(
          height: 1,
          thickness: 1,
          color: DetailLayout.ruleColor(inverseScheme),
        ),
        CheckedMenuItem(
          checked: false,
          onPressed: state.selected.isEmpty || state.addingBatch
              ? null
              : () {
                  final before = cubit.state;
                  cubit.replaceSelection(const {});
                  if (cubit.state != before) AppHaptics.selection();
                },
          child: Text(l10n.downloadDeselectAll),
        ),
      ],
      builder: (context, controller, _) {
        final label = _MenuLabel(l10n.downloadSelect);
        final open = available ? controller.toggle : null;
        return outlined
            ? OutlinedButton(
                onPressed: open,
                style: releaseDownloadOutline(context, compact: compact),
                child: label,
              )
            : TextButton(
                onPressed: open,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: label,
              );
      },
    );
  }
}

class DownloadQualityMenu extends StatelessWidget {
  const DownloadQualityMenu({
    required this.state,
    this.compact = false,
    super.key,
  });

  final PlayerSourceReady state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final inverse = InverseTheme.of(theme);
    final cubit = context.read<PlayerSourceCubit>();
    String label(int? height) => height == null
        ? l10n.onlineQualityAuto
        : l10n.onlineQualityHeight(height);
    return MenuAnchor(
      alignmentOffset: const Offset(0, 2),
      menuChildren: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            l10n.playerSourceDownloadQuality,
            style: inverse.textTheme.bodySmall?.copyWith(
              color: inverse.colorScheme.onSurfaceVariant,
              fontFamily: DetailLayout.sansFont,
            ),
          ),
        ),
        for (final height in <int?>[null, ...state.downloadSource!.qualities])
          CheckedMenuItem(
            checked: height == state.quality,
            onPressed: state.addingBatch
                ? null
                : () {
                    if (height != state.quality) AppHaptics.selection();
                    cubit.chooseQuality(height);
                  },
            child: Text(label(height)),
          ),
      ],
      builder: (context, controller, _) => OutlinedButton(
        onPressed: state.addingBatch ? null : controller.toggle,
        style: releaseDownloadOutline(context, compact: compact),
        child: _MenuLabel(label(state.quality), isQuality: true),
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.label, {this.isQuality = false});

  final String label;
  final bool isQuality;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = DefaultTextStyle.of(
      context,
    ).style.copyWith(fontSize: 13, fontWeight: FontWeight.w500, height: 1.2);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isQuality)
          MixedDataText(
            label,
            sansStyle: style.copyWith(fontFamily: DetailLayout.sansFont),
            monoStyle: DetailLayout.monoTelemetryStyle(
              style,
              color: style.color,
            ),
          )
        else
          Text(label),
        const SizedBox(width: 8),
        PixelIcon(PixelGlyph.expand, size: 8, color: scheme.onSurfaceVariant),
      ],
    );
  }
}

class ReleaseDownloadActions extends StatelessWidget {
  const ReleaseDownloadActions({
    required this.state,
    required this.isOnline,
    this.inline = false,
    this.compact = false,
    this.showError = true,
    super.key,
  });

  final PlayerSourceReady state;
  final bool isOnline;
  final bool inline;
  final bool compact;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selected = state.selected;
    final count = selected.length;
    final size = state.files.fold(
      0,
      (bytes, file) =>
          selected.contains(file.index) ? bytes + file.size : bytes,
    );
    final actionLabel = count == 0
        ? downloadSelectionPrompt(l10n, isOnline)
        : isOnline
        ? l10n.downloadSelectedEpisodes(count)
        : l10n.downloadSelectedFiles(count);
    final label = size > 0
        ? '$actionLabel · ${formatByteSize(l10n, size, decimalDigits: 2)}'
        : actionLabel;
    final button = FilledButton(
      style: busyButtonStyle(
        busy: state.addingBatch,
        base: compact
            ? FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              )
            : null,
      ),
      onPressed: count == 0 || state.addingBatch
          ? null
          : () => enqueueReleaseDownloads(context),
      child: BusyButtonChild(
        label,
        busy: state.addingBatch,
        busySemanticsLabel: l10n.downloadAddingToQueue,
      ),
    );
    final Widget action;
    if (isOnline && state.downloadSource?.qualities.isNotEmpty == true) {
      action = Row(
        mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          DownloadQualityMenu(state: state, compact: compact),
          const SizedBox(width: 10),
          Flexible(fit: inline ? FlexFit.loose : FlexFit.tight, child: button),
        ],
      );
    } else {
      action = inline
          ? button
          : SizedBox(width: double.infinity, child: button);
    }
    if (!showError) return action;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: inline
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.stretch,
      children: [
        DitherSwitcher(
          collapse: true,
          resizeDuration: const Duration(milliseconds: 180),
          duration: const Duration(milliseconds: 180),
          alignment: inline
              ? AlignmentDirectional.topEnd
              : AlignmentDirectional.topStart,
          child: state.enqueueFailed
              ? const Padding(
                  key: ValueKey('enqueue_error'),
                  padding: EdgeInsets.only(bottom: 8),
                  child: ReleaseEnqueueError(),
                )
              : const SizedBox.shrink(key: ValueKey('no_enqueue_error')),
        ),
        action,
      ],
    );
  }
}
