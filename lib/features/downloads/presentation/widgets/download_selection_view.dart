import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/file_display_name.dart';

class DownloadSelectionView extends StatelessWidget {
  const DownloadSelectionView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DownloadSelectionCubit, DownloadSelectionState>(
      builder: (context, state) {
        return switch (state) {
          DownloadSelectionInitial() ||
          DownloadSelectionLoading() => const _LoadingState(),
          DownloadSelectionReady(:final source) => _FileList(
            files: source.files,
          ),
          DownloadSelectionEnqueuing(:final source, :final file) => _FileList(
            files: source.files,
            enqueuingFile: file,
          ),
          DownloadSelectionQueued() => const _LoadingState(),
          DownloadSelectionFailure(:final type) => _FailureState(type: type),
        };
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context).downloadSelectionPreparing,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _FileList extends StatelessWidget {
  const _FileList({required this.files, this.enqueuingFile});

  final List<DownloadableFile> files;
  final DownloadableFile? enqueuingFile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final cubit = context.read<DownloadSelectionCubit>();
    final idle = enqueuingFile == null;
    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, index) {
        final file = files[index];
        final isEnqueuing = enqueuingFile == file;
        final enqueue = idle ? () => cubit.enqueue(file) : null;
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsetsDirectional.only(start: 16, end: 8),
          title: Text(
            fileDisplayName(file.name),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            isEnqueuing
                ? l10n.downloadAddingToQueue
                : formatByteSize(file.size),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: isEnqueuing
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  key: ValueKey('download_file_button_${file.index}'),
                  tooltip: l10n.downloadFileButton,
                  icon: const Icon(Icons.download_outlined),
                  onPressed: enqueue,
                ),
          onTap: enqueue,
        );
      },
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: context.read<DownloadSelectionCubit>().load,
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}
