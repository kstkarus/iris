import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/user_rate/presentation/user_rate_cubit.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_state.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/listed_episodes.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/models/anime_player_args.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_controls.dart';
import 'package:iris/features/player/presentation/widgets/player_source_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

class PlayerSourcePage extends StatelessWidget {
  const PlayerSourcePage({required this.args, super.key});

  final AnimePlayerSourceArgs args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isOnline = OnlineSourceLink.tryParse(args.magnet) != null;
    final expanded = WindowSizeClass.of(
      context,
    ).isAtLeast(WindowSizeClass.expanded);
    // Pages without an account or an anime have no list (null cubit).
    final listedEpisodes = context.select<UserRateCubit?, int>(
      (cubit) => switch (cubit?.state) {
        UserRateLoaded(:final rate?) => rate.episodes,
        _ => 0,
      },
    );
    final progress = progressByFile(
      context.watchWatchProgress(),
      sourceProgressKey(args.magnet),
      animeId: args.animeId,
    );
    final cubit = context.watch<PlayerSourceCubit>();
    final state = cubit.state;
    final ready = state is PlayerSourceReady ? state : null;
    final selecting = ready?.selecting ?? false;
    final singleFile = ready?.files.length == 1;
    final canCancelSelection = selecting && !ready!.addingBatch;
    final cancel = canCancelSelection ? cubit.cancelSelection : null;
    final compactSelection = selecting && !expanded;
    final selectionTitle = downloadSelectionTitle(l10n, isOnline);
    final appBar = compactSelection
        ? FramedAppBar(
            key: const ValueKey('select_downloads'),
            showBackButton: false,
            title: Row(
              children: [
                Transform.translate(
                  offset: const Offset(-10, 0),
                  child: IconButton(
                    tooltip: l10n.commonCancel,
                    icon: const PixelIcon(PixelGlyph.close, size: 16),
                    onPressed: cancel,
                  ),
                ),
                Expanded(
                  child: Transform.translate(
                    offset: const Offset(-6, 0),
                    child: PageTitle(
                      title: ready!.selected.isEmpty
                          ? selectionTitle
                          : l10n.playerSourceSelectedCount(
                              ready.selected.length,
                            ),
                    ),
                  ),
                ),
              ],
            ),
            trailing: DownloadPresetsMenu(
              state: ready,
              isOnline: isOnline,
              progressByFile: progress,
              listed: filesCountedInList(ready.files, listedEpisodes),
              outlined: false,
            ),
          )
        : FramedAppBar(
            key: ValueKey(selecting ? 'download_toolbar' : 'watch_release'),
            title: PageTitle(
              title: selecting
                  ? selectionTitle
                  : isOnline && singleFile
                  ? args.sourceTitle
                  : isOnline
                  ? l10n.playerSourceEpisodesTitle
                  : l10n.playerSourceTitle,
              subtitle: isOnline && singleFile ? null : args.sourceTitle,
            ),
            trailing: selecting
                ? TextButton(onPressed: cancel, child: Text(l10n.commonCancel))
                : !singleFile && ready?.hasNewDownloads == true
                ? TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    onPressed: () {
                      final before = cubit.state;
                      cubit.startSelection();
                      if (cubit.state != before) AppHaptics.selection();
                    },
                    icon: const PixelIcon(PixelGlyph.download, size: 15),
                    label: Text(l10n.downloadsOpenButton),
                  )
                : null,
          );

    return BlocListener<PlayerSourceCubit, PlayerSourceState>(
      listenWhen: (previous, next) =>
          previous is! PlayerSourceReady && next is PlayerSourceReady,
      listener: (context, state) {
        final wanted = args.autoOpenFileIndex;
        if (wanted == null || ModalRoute.isCurrentOf(context) == false) return;
        final source = state as PlayerSourceReady;
        final file = source.files
            .where((file) => file.index == wanted)
            .firstOrNull;
        if (file == null) return;
        _openPlayer(
          context,
          file: file,
          source: source,
          listedEpisodes: listedEpisodes,
          autoOpen: true,
        );
      },
      child: PopScope(
        canPop: !canCancelSelection,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) cancel?.call();
        },
        child: CallbackShortcuts(
          bindings: {const SingleActivator(LogicalKeyboardKey.escape): ?cancel},
          child: FocusScope(
            autofocus: true,
            child: Scaffold(
              appBar: PreferredSize(
                preferredSize: appBar.preferredSize,
                child: DitherSwitcher(
                  expand: true,
                  duration: const Duration(milliseconds: 200),
                  child: appBar,
                ),
              ),
              body: SafeArea(
                child: PageFrame.subPage(
                  child: PlayerSourceView(
                    isOnline: isOnline,
                    progressByFile: progress,
                    listedEpisodes: listedEpisodes,
                    onOpenDownloads: () => context.goNamed('downloads'),
                    onFileSelected: (file) {
                      if (cubit.state case final PlayerSourceReady source) {
                        _openPlayer(
                          context,
                          file: file,
                          source: source,
                          listedEpisodes: listedEpisodes,
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openPlayer(
    BuildContext context, {
    required PlayerVideoFile file,
    required PlayerSourceReady source,
    required int listedEpisodes,
    bool autoOpen = false,
  }) {
    if (ModalRoute.isCurrentOf(context) == false) return;
    final player = AnimePlayerArgs(
      AnimePlayerSource(
        animeId: args.animeId,
        animeTitle: args.animeTitles.name,
        animeRussian: args.animeTitles.russian,
        animeEnglish: args.animeTitles.english,
        sourceTitle: args.sourceTitle,
        sessionId: source.localSessionId ?? 'release',
        fileIndex: file.index,
        fileName: file.name,
        magnet: args.magnet,
        files: source.files,
        listedEpisodes: listedEpisodes,
      ),
      playFromRelease: source.localSessionId == null,
    );
    try {
      if (autoOpen) {
        context.pushReplacementNamed('player', extra: player);
      } else {
        context.pushNamed('player', extra: player);
      }
    } catch (_) {
      developer.log(
        'Failed to open the player route.',
        name: 'iris.player.source_page',
      );
    }
  }
}
