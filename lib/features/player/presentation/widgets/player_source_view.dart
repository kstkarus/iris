import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class PlayerSourceView extends StatelessWidget {
  const PlayerSourceView({required this.onFileSelected, super.key});

  final ValueChanged<PlayerVideoFile> onFileSelected;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerSourceCubit, PlayerSourceState>(
      builder: (context, state) {
        return switch (state) {
          PlayerSourceInitial() || PlayerSourceLoading() => _LoadingState(
            message: AppLocalizations.of(context).playerSourcePreparing,
          ),
          PlayerSourceReady(:final preparedSource) => _SuccessState(
            files: preparedSource.files,
            onFileSelected: onFileSelected,
          ),
          PlayerSourceFailure(:final type) => _FailureState(type: type),
        };
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({required this.files, required this.onFileSelected});

  final List<PlayerVideoFile> files;
  final ValueChanged<PlayerVideoFile> onFileSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final file = files[index];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${AppLocalizations.of(context).playerFileSizeLabel}: ${_formatFileSize(file.size)}',
                ),
                const SizedBox(height: 4),
                Text(
                  '${AppLocalizations.of(context).playerFileTypeLabel}: ${file.extension.toUpperCase()}',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => onFileSelected(file),
                    child: Text(
                      AppLocalizations.of(context).playerWatchFileButton,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.type});

  final PlayerSourceFailureType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = type == PlayerSourceFailureType.unsupportedSource
        ? l10n.playerSourceUnsupported
        : l10n.playerSourceUnableToPrepare;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.read<PlayerSourceCubit>().loadSource(),
              child: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatFileSize(int size) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = size.toDouble();
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final fractionDigits = unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}
