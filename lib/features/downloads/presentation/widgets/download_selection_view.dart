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
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
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
        return switch (state) {
          DownloadSelectionInitial() ||
          DownloadSelectionLoading() => LoadingView(
            label: episodes
                ? l10n.downloadSelectionPreparingEpisodes
                : l10n.downloadSelectionPreparing,
          ),
          final DownloadSelectionReady ready => _FileList(
            state: ready,
            onWatch: onWatch,
          ),
          DownloadSelectionFailure(:final type) => _FailureState(type: type),
        };
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
    final list = ListView.separated(
      itemCount: files.length,
      separatorBuilder: (_, _) => const SegmentedRule(),
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileRow(
          file: file,
          download: state.downloads[file.index],
          adding: state.adding.contains(file.index),
          addingBatch: state.addingBatch,
          notAdded: state.notAdded.contains(file.index),
          selecting: state.selecting,
          selected: state.selected.contains(file.index),
          selectable: state.canSelect(file.index),
          onSelect: !state.addingBatch && state.canSelect(file.index)
              ? () => context.read<DownloadSelectionCubit>().toggleSelection(
                  file.index,
                )
              : null,
          onStartSelection: state.canStartSelection
              ? () => context.read<DownloadSelectionCubit>().startSelection(
                  index: state.canSelect(file.index) ? file.index : null,
                )
              : null,
          onWatch: onWatch,
        );
      },
    );
    final qualities = state.source.qualities;
    final cubit = context.read<DownloadSelectionCubit>();
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
              onPressed: state.addingBatch || state.selected.isEmpty
                  ? null
                  : cubit.downloadSelected,
              child: Text(
                state.addingBatch
                    ? l10n.downloadAddingToQueue
                    : cubit.args.isOnlineRelease
                    ? l10n.downloadSelectedEpisodes(state.selected.length)
                    : l10n.downloadSelectedFiles(state.selected.length),
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
        l10n.downloadSelectionLoading((_loaded(download) * 100).floor()),
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
          padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileDisplayName(file.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (details.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        details,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              notAdded && !adding ||
                                  status == DownloadStatus.failed
                              ? scheme.error
                              : null,
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
                            key: const ValueKey('action'),
                            child: switch (status) {
                              _ when adding => const SizedBox(
                                width: 28,
                                child: BlockSpinner(height: 4),
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
                                  fill: _loaded(download!),
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
                                fill: _loaded(download!),
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

/// How much of [download] is here: all of it once done, and short of all
/// until then, as an online episode's size is a guess it may outgrow.
double _loaded(DownloadItem download) =>
    download.status == DownloadStatus.completed
    ? 1
    : download.progress.clamp(0.0, 0.99);

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
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.onlineQualityTitle,
            style: theme.textTheme.bodySmall?.copyWith(
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
