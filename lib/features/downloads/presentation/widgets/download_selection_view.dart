import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
import 'package:iris/features/downloads/presentation/widgets/download_selection_footer.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/features/online_sources/domain/online_episode_files.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/episode_number.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/block_runner.dart';
import 'package:iris/shared/widgets/busy_button_child.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/segmented_choice.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/tap_row.dart';

class DownloadSelectionView extends StatelessWidget {
  const DownloadSelectionView({required this.onWatch, super.key});
  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final episodes = context
        .read<DownloadSelectionCubit>()
        .args
        .isOnlineRelease;
    return BlocBuilder<DownloadSelectionCubit, DownloadSelectionState>(
      builder: (context, state) {
        final (Object key, Widget view) = switch (state) {
          DownloadSelectionInitial() || DownloadSelectionLoading() => (
            'loading',
            LoadingView(
              semanticsLabel: episodes
                  ? l10n.downloadSelectionPreparingEpisodes
                  : l10n.downloadSelectionPreparing,
            ),
          ),
          final DownloadSelectionReady ready => (
            'ready',
            _FileList(state: ready, onWatch: onWatch),
          ),
          DownloadSelectionFailure(:final type) => (
            'failure',
            _FailureState(type: type),
          ),
        };
        return DitherSwitcher(
          expand: true,
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(key: ValueKey(key), child: view),
        );
      },
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({required this.state, required this.onWatch});

  final DownloadSelectionReady state;
  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    final files = state.source.files;
    final cubit = context.read<DownloadSelectionCubit>();
    final scheme = Theme.of(context).colorScheme;
    final rule = DetailLayout.ruleColor(scheme);
    final list = ListView.builder(
      padding: EdgeInsets.only(bottom: state.selecting ? 12 : 24),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final isFirst = index == 0;
        return Material(
          color: scheme.surfaceContainerLow,
          shape: Border(
            top: isFirst ? BorderSide(color: rule) : BorderSide.none,
            left: BorderSide(color: rule),
            right: BorderSide(color: rule),
            bottom: BorderSide(color: rule),
          ),
          child: _FileRow(
            file: file,
            download: state.downloads[file.index],
            adding: state.adding.contains(file.index),
            addingBatch: state.addingBatch,
            notAdded: state.notAdded.contains(file.index),
            selecting: state.selecting,
            selected: state.selected.contains(file.index),
            selectable: state.canSelect(file.index),
            onSelect: !state.addingBatch && state.canSelect(file.index)
                ? () {
                    final before = cubit.state;
                    cubit.toggleSelection(file.index);
                    if (cubit.state != before) AppHaptics.selection();
                  }
                : null,
            onStartSelection: state.canStartSelection
                ? () {
                    final before = cubit.state;
                    cubit.startSelection(
                      index: state.canSelect(file.index) ? file.index : null,
                    );
                    if (cubit.state != before) AppHaptics.medium();
                  }
                : null,
            onWatch: onWatch,
          ),
        );
      },
    );
    final qualities = state.source.qualities;
    final l10n = AppLocalizations.of(context);
    return PopScope(
      canPop: !state.selecting || state.addingBatch,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) cubit.cancelSelection();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (qualities.isNotEmpty)
            _QualityChoice(
              qualities: qualities,
              quality: state.quality,
              enabled: !state.addingBatch,
            ),
          Expanded(key: const Key('download_selection_list'), child: list),
          DownloadSelectionFooter(
            visible: state.selecting,
            child: FilledButton(
              key: const Key('download_selected'),
              style: busyButtonStyle(busy: state.addingBatch),
              onPressed: state.addingBatch || state.selected.isEmpty
                  ? null
                  : () async {
                      if (cubit.state case DownloadSelectionReady(
                        addingBatch: true,
                      )) {
                        return;
                      }
                      if (await cubit.downloadSelected() &&
                          context.mounted &&
                          ModalRoute.of(context)?.isCurrent != false) {
                        AppHaptics.success();
                      }
                    },
              child: BusyButtonChild(
                cubit.args.isOnlineRelease
                    ? l10n.downloadSelectedEpisodes(state.selected.length)
                    : l10n.downloadSelectedFiles(state.selected.length),
                busy: state.addingBatch,
                busyLabel: l10n.downloadAddingToQueue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A file and what became of it: a download button until it is queued,
/// then its download's state in place of the button, filling as it loads.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.download,
    required this.adding,
    required this.addingBatch,
    required this.notAdded,
    required this.selecting,
    required this.selected,
    required this.selectable,
    required this.onSelect,
    required this.onStartSelection,
    required this.onWatch,
  });

  final DownloadableFile file;
  final DownloadItem? download;
  final bool adding;
  final bool addingBatch;
  final bool notAdded;
  final bool selecting;
  final bool selected;
  final bool selectable;
  final VoidCallback? onSelect;
  final VoidCallback? onStartSelection;
  final ValueChanged<DownloadItem> onWatch;

  static final _plainNumber = RegExp(r'^\d+(?:\.\d+)?$');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<DownloadSelectionCubit>();
    final download = this.download;
    final status = adding ? null : download?.status;
    // A tap queues the file, or takes a stopped download up again.
    final actionable = selectable && !addingBatch;
    final onTap = selecting
        ? onSelect
        : actionable
        ? () => unawaited(cubit.download(file))
        : status == DownloadStatus.completed
        ? () => onWatch(download!)
        : null;
    final note = switch (status) {
      _ when adding => l10n.downloadAddingToQueue,
      null when notAdded => l10n.downloadUnableToQueue,
      null => null,
      // How far, once there is a size to measure it by.
      DownloadStatus.downloading when download!.totalBytes > 0 =>
        l10n.downloadSelectionLoading(
          (download.progressUntilCompleted * 100).floor(),
        ),
      final status => downloadStatusLabel(l10n, status),
    };
    final size = download?.totalBytes ?? file.size;
    // An online episode's size is unknown until it loads, and a guess
    // until it is done.
    final estimated =
        download != null &&
        download.isOnline &&
        status != DownloadStatus.completed;
    final details = [
      if (size > 0) '${estimated ? '~' : ''}${formatByteSize(l10n, size)}',
      ?note,
    ].join(' · ');
    final isOnline = cubit.args.isOnlineRelease;
    final onlineEpisode = isOnline
        ? parseOnlineEpisodeFileName(file.name)
        : null;
    final rawName = isOnline ? file.name : fileDisplayName(file.name);
    final justNumber =
        onlineEpisode?.title.isEmpty ?? _plainNumber.hasMatch(rawName);
    final number = isOnline
        ? onlineEpisode?.number
        : episodeNumberFromFileName(file.name);
    final badgeText =
        number?.toString().padLeft(2, '0') ?? (justNumber ? rawName : null);
    final displayTitle = onlineEpisode?.title ?? rawName;
    final active = status == DownloadStatus.downloading;
    final statusColor = notAdded && !adding || status == DownloadStatus.failed
        ? scheme.error
        : active
        ? scheme.tertiary
        : scheme.onSurfaceVariant;
    final badge = SizedBox.square(
      dimension: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          border: Border.all(
            color: active
                ? scheme.tertiary
                : status == DownloadStatus.failed
                ? scheme.error
                : DetailLayout.ruleColor(scheme),
          ),
        ),
        child: Center(
          child: badgeText == null
              ? PixelIcon(
                  PixelGlyph.file,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                )
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      badgeText,
                      style: DetailLayout.monoTelemetryStyle(
                        theme.textTheme.bodyMedium,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? scheme.tertiary
                            : status == DownloadStatus.completed
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
    return Semantics(
      key: ValueKey('download_selection_file_${file.index}'),
      checked: selecting && selectable ? selected : null,
      enabled: selecting ? onSelect != null : null,
      onLongPressHint: onStartSelection == null
          ? null
          : cubit.args.isOnlineRelease
          ? l10n.downloadSelectEpisodes
          : l10n.downloadSelectFiles,
      child: TapRow(
        onTap: onTap,
        onLongPress: onStartSelection,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              badge,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!justNumber)
                      Text(
                        displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: DetailLayout.sansFont,
                          fontWeight: status == DownloadStatus.completed
                              ? FontWeight.w400
                              : FontWeight.w500,
                          color: status == DownloadStatus.completed
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    if (details.isNotEmpty) ...[
                      if (!justNumber) const SizedBox(height: 3),
                      PixelSeparatedText(
                        details,
                        sansStyle: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: DetailLayout.sansFont,
                          color: statusColor,
                        ),
                        monoStyle: DetailLayout.monoTelemetryStyle(
                          theme.textTheme.bodySmall,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height:
                    theme.materialTapTargetSize == MaterialTapTargetSize.padded
                    ? 48
                    : 40,
                child: Center(
                  child: DitherSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: selecting
                        ? selectable
                              ? ExcludeSemantics(
                                  key: const ValueKey('selection'),
                                  child: Checkbox(
                                    value: selected,
                                    onChanged: onSelect == null
                                        ? null
                                        : (_) => onSelect!(),
                                  ),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('unavailable'),
                                )
                        : KeyedSubtree(
                            key: ValueKey(
                              'action_${adding ? 'adding' : switch (status) {
                                      null => 'idle',
                                      DownloadStatus.paused => 'paused',
                                      DownloadStatus.failed => 'failed',
                                      DownloadStatus.completed => 'completed',
                                      DownloadStatus.queued || DownloadStatus.downloading => 'active',
                                    }}',
                            ),
                            child: switch (status) {
                              _ when adding => BlockRunner(
                                color: scheme.onSurface,
                                trackColor: DetailLayout.ruleColor(scheme),
                                cell: 5,
                                gap: 2,
                              ),
                              null => IconButton(
                                key: ValueKey(
                                  'download_file_button_${file.index}',
                                ),
                                tooltip: l10n.downloadFileButton,
                                icon: const PixelIcon(
                                  PixelGlyph.download,
                                  size: 18,
                                ),
                                onPressed: onTap,
                              ),
                              DownloadStatus.paused ||
                              DownloadStatus.failed => IconButton(
                                key: ValueKey(
                                  'download_file_button_${file.index}',
                                ),
                                tooltip: status == DownloadStatus.paused
                                    ? l10n.downloadResumeButton
                                    : l10n.commonRetry,
                                icon: PixelIcon(
                                  PixelGlyph.download,
                                  size: 18,
                                  fill: download!.progressUntilCompleted,
                                  color: status == DownloadStatus.failed
                                      ? scheme.error
                                      : scheme.onSurface,
                                ),
                                onPressed: onTap,
                              ),
                              DownloadStatus.completed => IconButton(
                                key: ValueKey(
                                  'download_file_watch_${file.index}',
                                ),
                                tooltip: l10n.downloadWatchButton,
                                onPressed: onTap,
                                icon: const PixelIcon(
                                  PixelGlyph.play,
                                  size: 18,
                                ),
                              ),
                              DownloadStatus.queued ||
                              DownloadStatus.downloading => PixelIcon(
                                PixelGlyph.download,
                                key: ValueKey(
                                  'download_file_progress_${file.index}',
                                ),
                                size: 18,
                                fill: download!.progressUntilCompleted,
                                color: scheme.tertiary,
                                trackColor: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The quality the next episodes load in, over the episodes.
class _QualityChoice extends StatelessWidget {
  const _QualityChoice({
    required this.qualities,
    required this.quality,
    required this.enabled,
  });

  final List<int> qualities;
  final int? quality;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<DownloadSelectionCubit>();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.onlineQualityTitle,
            style: theme.textTheme.labelMedium?.copyWith(
              fontFamily: DetailLayout.sansFont,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          // The episodes queued keep the quality they were queued in.
          SegmentedChoice<int?>(
            key: const Key('download_quality_choice'),
            selected: quality,
            onSelected: enabled ? cubit.chooseQuality : null,
            options: [
              SegmentedOption(value: null, label: l10n.onlineQualityAuto),
              for (final height in qualities)
                SegmentedOption(
                  value: height,
                  label: l10n.onlineQualityHeight(height),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.type});

  final DownloadSelectionFailureType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = switch (type) {
      DownloadSelectionFailureType.unsupported =>
        l10n.downloadSelectionUnsupported,
      DownloadSelectionFailureType.unableToPrepare =>
        l10n.downloadSelectionUnableToPrepare,
    };
    return RetryView(
      message: message,
      onRetry: context.read<DownloadSelectionCubit>().load,
    );
  }
}
