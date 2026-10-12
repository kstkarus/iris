import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
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
          DownloadSelectionLoading() ||
          DownloadSelectionQueued() => LoadingView(
            label: episodes
                ? l10n.downloadSelectionPreparingEpisodes
                : l10n.downloadSelectionPreparing,
          ),
          DownloadSelectionReady(:final source, :final quality) => _FileList(
            files: source.files,
            qualities: source.qualities,
            quality: quality,
          ),
          DownloadSelectionEnqueuing(
            :final source,
            :final file,
            :final quality,
          ) =>
            _FileList(
              files: source.files,
              qualities: source.qualities,
              quality: quality,
              enqueuingFile: file,
            ),
          DownloadSelectionFailure(:final type) => _FailureState(type: type),
        };
      },
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({
    required this.files,
    required this.qualities,
    required this.quality,
    this.enqueuingFile,
  });

  final List<DownloadableFile> files;

  /// The heights an online release offers; empty for a torrent.
  final List<int> qualities;
  final int? quality;
  final DownloadableFile? enqueuingFile;

  @override
  Widget build(BuildContext context) {
    final list = _list(context);
    if (qualities.isEmpty) return list;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _QualityChoice(
          qualities: qualities,
          quality: quality,
          enabled: enqueuingFile == null,
        ),
        Expanded(child: list),
      ],
    );
  }

  Widget _list(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<DownloadSelectionCubit>();
    final idle = enqueuingFile == null;
    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (_, _) => const SegmentedRule(),
      itemBuilder: (context, index) {
        final file = files[index];
        final isEnqueuing = enqueuingFile == file;
        final enqueue = idle ? () => cubit.enqueue(file) : null;
        return TapRow(
          onTap: enqueue,
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
                      // An online episode's size is not known yet.
                      if (isEnqueuing || file.size > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          isEnqueuing
                              ? l10n.downloadAddingToQueue
                              : formatByteSize(l10n, file.size),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isEnqueuing)
                  const SizedBox(
                    width: 44,
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        child: BlockSpinner(height: 4),
                      ),
                    ),
                  )
                else
                  IconButton(
                    key: ValueKey('download_file_button_${file.index}'),
                    tooltip: l10n.downloadFileButton,
                    icon: const PixelIcon(PixelGlyph.download, size: 18),
                    onPressed: enqueue,
                  ),
              ],
            ),
          ),
        );
      },
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
          IgnorePointer(
            ignoring: !enabled,
            child: SegmentedChoice<int?>(
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
      DownloadSelectionFailureType.unableToQueue => l10n.downloadUnableToQueue,
      DownloadSelectionFailureType.unableToPrepare =>
        l10n.downloadSelectionUnableToPrepare,
    };
    return RetryView(
      message: message,
      onRetry: context.read<DownloadSelectionCubit>().load,
    );
  }
}
