import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_args.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/player/presentation/widgets/player_source_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class PlayerSourcePage extends StatelessWidget {
  const PlayerSourcePage({required this.args, super.key});

  final AnimePlayerSourceArgs args;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return BlocListener<PlayerSourceCubit, PlayerSourceState>(
      listenWhen: (_, state) => state is PlayerSourceReady,
      listener: (context, state) {
        final readyState = state as PlayerSourceReady;
        if (readyState.preparedSource.files.length != 1) {
          return;
        }

        _openPlayer(
          context,
          file: readyState.preparedSource.files.single,
          sessionId: readyState.preparedSource.sessionId,
        );
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.appName)),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.playerSourceTitle,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                args.sourceTitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: PlayerSourceView(
                  onFileSelected: (file) => _openPlayer(
                    context,
                    file: file,
                    sessionId:
                        (context.read<PlayerSourceCubit>().state
                                as PlayerSourceReady)
                            .preparedSource
                            .sessionId,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPlayer(
    BuildContext context, {
    required PlayerVideoFile file,
    required String sessionId,
  }) {
    final cubit = context.read<PlayerSourceCubit>();
    cubit.transferSessionOwnership();
    try {
      context.pushReplacementNamed(
        'anime-player',
        pathParameters: {'id': args.animeId},
        extra: AnimePlayerArgs(
          animeId: args.animeId,
          animeTitle: args.animeTitle,
          sourceTitle: args.sourceTitle,
          sessionId: sessionId,
          fileIndex: file.index,
          fileName: file.name,
        ),
      );
    } catch (_) {
      cubit.reclaimSessionOwnership();
      developer.log(
        'Failed to open the player route. Ownership was reclaimed.',
        name: 'iris.player.source_page',
      );
    }
  }
}
