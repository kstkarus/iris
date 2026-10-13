import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
import 'package:iris/features/downloads/presentation/widgets/download_status_label.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/file_display_name.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/segmented_choice.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/tap_row.dart';

class DownloadSelectionView extends StatelessWidget {
  const DownloadSelectionView({super.key});

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
          final DownloadSelectionReady ready => _FileList(state: ready),
          DownloadSelectionFailure(:final type) => _FailureState(type: type),
        };
      },
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({required this.state});

  final DownloadSelectionReady state;

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
          notAdded: state.notAdded.contains(file.index),
        );
      },
    );
    final qualities = state.source.qualities;
    if (qualities.isEmpty) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QualityChoice(qualities: qualities, quality: state.quality),
        Expanded(child: list),
      ],
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
    required this.notAdded,
  });

  final DownloadableFile file;
  final DownloadItem? download;
  final bool adding;
  final bool notAdded;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cubit = context.read<DownloadSelectionCubit>();
    final download = this.download;
    final status = adding ? null : download?.status;
    // A tap queues the file, or takes a stopped download up again.
    final actionable =
        !adding &&
        (download == null ||
            status == DownloadStatus.paused ||
            status == DownloadStatus.failed);
    final onTap = actionable ? () => unawaited(cubit.download(file)) : null;
    final note = switch (status) {
      _ when adding => l10n.downloadAddingToQueue,
      null when notAdded => l10n.downloadUnableToQueue,
      null => null,
      DownloadStatus.downloading => l10n.downloadSelectionLoading(
        (download!.progress * 100).floor(),
      ),
      final status => downloadStatusLabel(l10n, status),
    };
    final size = download?.totalBytes ?? file.size;
    final details = [
      // An online episode's size is not known until it loads.
      if (size > 0) formatByteSize(l10n, size),
      ?note,
    ].join(' · ');
    return TapRow(
      onTap: onTap,
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
              child: Center(
                child: switch (status) {
                  _ when adding => const SizedBox(
                    width: 28,
                    child: BlockSpinner(height: 4),
                  ),
                  null => IconButton(
                    key: ValueKey('download_file_button_${file.index}'),
                    tooltip: l10n.downloadFileButton,
                    icon: const PixelIcon(PixelGlyph.download, size: 18),
                    onPressed: onTap,
                  ),
                  DownloadStatus.paused || DownloadStatus.failed => IconButton(
                    key: ValueKey('download_file_button_${file.index}'),
                    tooltip: status == DownloadStatus.paused
                        ? l10n.downloadResumeButton
                        : l10n.commonRetry,
                    icon: PixelIcon(
                      PixelGlyph.download,
                      size: 18,
                      fill: download!.progress,
                      color: status == DownloadStatus.failed
                          ? scheme.error
                          : scheme.onSurface,
                    ),
                    onPressed: onTap,
                  ),
                  DownloadStatus.completed => PixelIcon(
                    PixelGlyph.check,
                    key: ValueKey('download_file_done_${file.index}'),
                    size: 18,
                    color: scheme.tertiary,
                    semanticLabel: note,
                  ),
                  DownloadStatus.queued ||
                  DownloadStatus.downloading => PixelIcon(
                    PixelGlyph.download,
                    key: ValueKey('download_file_progress_${file.index}'),
                    size: 18,
                    fill: download!.progress,
                    color: scheme.tertiary,
                    trackColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    semanticLabel: note,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The quality the next episodes load in, over the episodes.
class _QualityChoice extends StatelessWidget {
  const _QualityChoice({required this.qualities, required this.quality});

  final List<int> qualities;
  final int? quality;

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
            onSelected: cubit.chooseQuality,
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
