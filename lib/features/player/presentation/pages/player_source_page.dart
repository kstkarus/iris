import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_args.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/player/presentation/widgets/player_source_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';

class PlayerSourcePage extends StatelessWidget {
  const PlayerSourcePage({required this.args, super.key});

  final AnimePlayerSourceArgs args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOnline = OnlineSourceLink.tryParse(args.magnet) != null;

    return BlocListener<PlayerSourceCubit, PlayerSourceState>(
      listenWhen: (_, state) => state is PlayerSourceReady,
      listener: (context, state) {
        final preparedSource = (state as PlayerSourceReady).preparedSource;
        final file = _fileToOpenImmediately(preparedSource.files);
        if (file == null) return;

        _openPlayer(
          context,
          file: file,
          sessionId: preparedSource.sessionId,
          files: preparedSource.files,
        );
      },
      child: Scaffold(
        appBar: FramedAppBar(
          title: PageTitle(
            title: isOnline
                ? l10n.playerSourceEpisodesTitle
                : l10n.playerSourceTitle,
            subtitle: args.sourceTitle,
          ),
        ),
        body: SafeArea(
          child: PageFrame.subPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: PlayerSourceView(
                    isOnline: isOnline,
                    progressByFile: progressByFile(
                      context.watchWatchProgress(),
                      sourceProgressKey(args.magnet),
                    ),
                    onFileSelected: (file) {
                      final preparedSource =
                          (context.read<PlayerSourceCubit>().state
                                  as PlayerSourceReady)
                              .preparedSource;
                      _openPlayer(
                        context,
                        file: file,
                        sessionId: preparedSource.sessionId,
                        files: preparedSource.files,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A single-file torrent, or the file a "Continue" action asked for.
  PlayerVideoFile? _fileToOpenImmediately(List<PlayerVideoFile> files) {
    if (files.length == 1) return files.single;
    final wanted = args.autoOpenFileIndex;
    if (wanted == null) return null;
    for (final file in files) {
      if (file.index == wanted) return file;
    }
    return null;
  }

  void _openPlayer(
    BuildContext context, {
    required PlayerVideoFile file,
    required String sessionId,
    required List<PlayerVideoFile> files,
  }) {
    final cubit = context.read<PlayerSourceCubit>();
    cubit.transferSessionOwnership();
    try {
      context.pushReplacementNamed(
        'player',
        extra: AnimePlayerArgs(
          AnimePlayerSource(
            animeId: args.animeId,
            animeTitle: args.animeTitle,
            sourceTitle: args.sourceTitle,
            sessionId: sessionId,
            fileIndex: file.index,
            fileName: file.name,
            magnet: args.magnet,
            files: files,
          ),
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
