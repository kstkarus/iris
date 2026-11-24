import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/presentation/widgets/download_selection_footer.dart';
import 'package:iris/features/player/domain/entities/episode_metadata.dart';
import 'package:iris/features/player/domain/entities/player_video_file.dart';
import 'package:iris/features/player/domain/listed_episodes.dart';
import 'package:iris/features/player/domain/player_continue_target.dart';
import 'package:iris/features/player/domain/player_episode_names.dart';
import 'package:iris/features/player/presentation/cubit/player_source_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_source_state.dart';
import 'package:iris/features/player/presentation/widgets/episode_tag_badge.dart';
import 'package:iris/features/player/presentation/widgets/player_episode_grid.dart';
import 'package:iris/features/player/presentation/widgets/player_episodes_list.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_controls.dart';
import 'package:iris/features/player/presentation/widgets/player_source_download_status.dart';
import 'package:iris/features/settings/domain/entities/app_settings.dart';
import 'package:iris/features/settings/presentation/anime_title_labels.dart';
import 'package:iris/features/settings/presentation/cubit/app_settings_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/haptics/app_haptics.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/poster_image.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';

class PlayerSourceView extends StatelessWidget {
  const PlayerSourceView({
    required this.onFileSelected,
    this.progressByFile = const {},
    this.listedEpisodes = 0,
    this.episodeMetadata = const {},
    this.horizontalPadding = 0,
    this.animeTitles,
    this.sourceTitle = '',
    this.posterUrl = '',
    this.isOnline = false,
    super.key,
  });

  static const continueBarKey = Key('player_source_continue_bar');
  static const continueButtonKey = Key('player_source_continue_button');

  static const _desktopSplitMinWidth = 1000.0;
  static const _desktopSplitMinHeight = 500.0;

  static bool isDesktopSplit(BuildContext context) {
    final sizeClass = WindowSizeClass.of(context);
    if (!sizeClass.isAtLeast(WindowSizeClass.expanded)) return false;
    final size = MediaQuery.sizeOf(context);
    return size.width >= _desktopSplitMinWidth &&
        size.height >= _desktopSplitMinHeight;
  }

  /// Desktop split puts selection actions directly into `FramedAppBar` so the
  /// episode list never shifts vertically; large text falls back to the inline
  /// toolbar so scaled buttons never clip inside the 56 dp bar.
  static bool usesDesktopAppBarSelection(BuildContext context) =>
      isDesktopSplit(context) && !DetailLayout.isLargeText(context);

  final ValueChanged<PlayerVideoFile> onFileSelected;

  /// Watch progress of this torrent's files, keyed by file index.
  final Map<int, WatchProgress> progressByFile;

  /// Episodes of the anime the user's Shikimori list counts as watched.
  final int listedEpisodes;

  /// Optional episode metadata (titles, filler/recap), keyed by episode number.
  final Map<int, EpisodeMetadata> episodeMetadata;

  /// Horizontal page gutter passed inside scrollable rows so selection fills
  /// can bleed edge-to-edge while text rails stay aligned with `FramedAppBar`.
  final double horizontalPadding;

  /// Title and cover context shown in the desktop dossier rail.
  final AnimeTitles? animeTitles;
  final String sourceTitle;
  final String posterUrl;

  /// An online release, whose episodes come from a server, not a torrent.
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlayerSourceCubit, PlayerSourceState>(
      builder: (context, state) {
        final (Object key, Widget view) = switch (state) {
          PlayerSourceInitial() || PlayerSourceLoading() => (
            'loading',
            LoadingView(
              semanticsLabel: isOnline
                  ? AppLocalizations.of(context).playerSourceEpisodesPreparing
                  : AppLocalizations.of(context).playerSourcePreparing,
            ),
          ),
          final PlayerSourceReady ready => (
            'ready',
            _SuccessState(
              state: ready,
              progressByFile: progressByFile,
              listed: filesCountedInList(ready.files, listedEpisodes),
              metadataByFile: episodeMetadataForFiles(
                ready.files,
                episodeMetadata,
              ),
              horizontalPadding: horizontalPadding,
              animeTitles: animeTitles,
              sourceTitle: sourceTitle,
              posterUrl: posterUrl,
              isOnline: isOnline,
              onFileSelected: onFileSelected,
            ),
          ),
          PlayerSourceFailure(:final type) => (
            'failure',
            Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: _FailureState(type: type),
            ),
          ),
        };
        return DitherSwitcher(
          expand: true,
          duration: const Duration(milliseconds: 320),
          child: KeyedSubtree(key: ValueKey(key), child: view),
        );
      },
    );
  }
}

class _SuccessState extends StatelessWidget {
  const _SuccessState({
    required this.state,
    required this.progressByFile,
    required this.listed,
    required this.metadataByFile,
    required this.horizontalPadding,
    required this.animeTitles,
    required this.sourceTitle,
    required this.posterUrl,
    required this.onFileSelected,
    required this.isOnline,
  });

  static const _desktopListMaxWidth = 920.0;

  final PlayerSourceReady state;
  final Map<int, WatchProgress> progressByFile;
  final Set<int> listed;
  final Map<int, EpisodeMetadata> metadataByFile;
  final double horizontalPadding;
  final AnimeTitles? animeTitles;
  final String sourceTitle;
  final String posterUrl;
  final ValueChanged<PlayerVideoFile> onFileSelected;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final files = state.files;
    final sizeClass = WindowSizeClass.of(context);
    final topGap = sizeClass.isCompact ? 16.0 : 24.0;

    final cubit = context.read<PlayerSourceCubit>();
    final target = continueTarget(files, progressByFile, listed: listed);
    final names = distinctEpisodeNames(files, metadata: metadataByFile);
    final expanded = sizeClass.isAtLeast(WindowSizeClass.expanded);
    final selecting = state.selecting;
    final scheme = Theme.of(context).colorScheme;
    final desktopSplit = PlayerSourceView.isDesktopSplit(context);
    final episodeListLayout = context
        .select<AppSettingsCubit?, EpisodeListLayout>(
          (cubit) => cubit?.state.episodeListLayout ?? EpisodeListLayout.auto,
        );
    final useList = switch (episodeListLayout) {
      EpisodeListLayout.auto => hasEpisodeTitles(
        files,
        metadata: metadataByFile,
      ),
      EpisodeListLayout.list => true,
      EpisodeListLayout.grid => false,
    };

    void onSelected(PlayerVideoFile file) {
      if (cubit.state case PlayerSourceReady(selecting: true)) {
        final before = cubit.state;
        cubit.toggleSelection(
          file.index,
          range: HardwareKeyboard.instance.isShiftPressed,
        );
        if (cubit.state != before) AppHaptics.selection();
      } else {
        onFileSelected(file);
      }
    }

    void onLongPressed(PlayerVideoFile file) {
      final before = cubit.state;
      cubit.startSelection(index: file.index);
      if (cubit.state != before) AppHaptics.medium();
    }

    if (desktopSplit) {
      final isLarge = sizeClass.isAtLeast(WindowSizeClass.large);
      final railWidth = isLarge ? 276.0 : 244.0;
      final rightGap = isLarge ? 28.0 : 20.0;
      final rule = DetailLayout.ruleColor(scheme);
      final tabular = !DetailLayout.isLargeText(context);
      final listHorizontalPadding = useList ? 12.0 : 0.0;
      final appBarSelection = PlayerSourceView.usesDesktopAppBarSelection(
        context,
      );
      final showInlineToolbar = selecting && !appBarSelection;
      final showAppBarError =
          selecting && appBarSelection && state.enqueueFailed;

      return Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: railWidth,
              child: _DesktopDossierRail(
                animeTitles: animeTitles,
                sourceTitle: sourceTitle,
                posterUrl: posterUrl,
                episodeCount: files.length,
                selecting: selecting,
                target: target,
                targetTitle: target == null
                    ? null
                    : (names[target.file.index] ?? target.file.displayName),
                targetNumber: target == null
                    ? null
                    : episodeNumberLabel(
                        target.file,
                        files.indexOf(target.file),
                      ),
                targetMetadata: target == null
                    ? null
                    : metadataByFile[target.file.index],
                targetProgress: target == null || target.isNext
                    ? null
                    : progressByFile[target.file.index],
                targetDownloaded:
                    target != null &&
                    state.downloadFor(target.file.index)?.status ==
                        DownloadStatus.completed,
                onContinue: target == null
                    ? null
                    : () => onFileSelected(target.file),
              ),
            ),
            VerticalDivider(width: 1, thickness: 1, color: rule),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: rightGap),
                child: Align(
                  alignment: AlignmentDirectional.topStart,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: _desktopListMaxWidth,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DitherSwitcher(
                          collapse: true,
                          resizeDuration: const Duration(milliseconds: 200),
                          duration: const Duration(milliseconds: 200),
                          child: showInlineToolbar
                              ? Padding(
                                  key: const ValueKey('selection_toolbar'),
                                  padding: const EdgeInsets.only(
                                    top: 16,
                                    bottom: 8,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: listHorizontalPadding,
                                        ),
                                        child: _SelectionToolbar(
                                          state: state,
                                          isOnline: isOnline,
                                          progressByFile: progressByFile,
                                          listed: listed,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: rule,
                                      ),
                                    ],
                                  ),
                                )
                              : showAppBarError
                              ? Padding(
                                  key: const ValueKey('appbar_enqueue_error'),
                                  padding: EdgeInsets.fromLTRB(
                                    listHorizontalPadding,
                                    12,
                                    listHorizontalPadding,
                                    0,
                                  ),
                                  child: const ReleaseEnqueueError(),
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('no_header'),
                                ),
                        ),
                        Expanded(
                          child: DitherSwitcher(
                            expand: true,
                            duration: const Duration(milliseconds: 260),
                            child: KeyedSubtree(
                              key: ValueKey(
                                useList ? 'episode_list' : 'episode_grid',
                              ),
                              child: useList
                                  ? PlayerEpisodesList(
                                      source: state,
                                      highlightedFileIndex: target?.file.index,
                                      progressByFile: progressByFile,
                                      listed: listed,
                                      metadataByFile: metadataByFile,
                                      horizontalPadding: listHorizontalPadding,
                                      tabular: tabular,
                                      topPadding: showInlineToolbar ? 6 : 16,
                                      isOnline: isOnline,
                                      onSelected: onSelected,
                                      onLongPressed: onLongPressed,
                                      onQuickDownload: (file) =>
                                          enqueueReleaseDownloads(
                                            context,
                                            singleIndex: file.index,
                                          ),
                                    )
                                  : PlayerEpisodeGrid(
                                      source: state,
                                      highlightedFileIndex: target?.file.index,
                                      progressByFile: progressByFile,
                                      listed: listed,
                                      metadataByFile: metadataByFile,
                                      topPadding: showInlineToolbar ? 12 : 20,
                                      desktop: true,
                                      isOnline: isOnline,
                                      onSelected: onSelected,
                                      onLongPressed: onLongPressed,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final showTopContinue = expanded && !selecting && target != null;
    final hasTopHeader = expanded && (selecting || target != null);
    final Widget topHeader = selecting && expanded
        ? DecoratedBox(
            key: const ValueKey('selection_toolbar'),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                bottom: BorderSide(color: DetailLayout.ruleColor(scheme)),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 10,
              ),
              child: _SelectionToolbar(
                state: state,
                isOnline: isOnline,
                progressByFile: progressByFile,
                listed: listed,
              ),
            ),
          )
        : showTopContinue
        ? _ContinueBar(
            key: PlayerSourceView.continueBarKey,
            title: names[target.file.index] ?? target.file.displayName,
            number: episodeNumberLabel(target.file, files.indexOf(target.file)),
            episodeMetadata: metadataByFile[target.file.index],
            progress: target.isNext ? null : progressByFile[target.file.index],
            isNext: target.isNext,
            downloaded:
                state.downloadFor(target.file.index)?.status ==
                DownloadStatus.completed,
            horizontalPadding: horizontalPadding,
            dockedTop: true,
            onPressed: () => onFileSelected(target.file),
          )
        : const SizedBox.shrink(key: ValueKey('no_header'));

    final Widget bottomContinueBar = !expanded && !selecting && target != null
        ? _ContinueBar(
            key: PlayerSourceView.continueBarKey,
            title: names[target.file.index] ?? target.file.displayName,
            number: episodeNumberLabel(target.file, files.indexOf(target.file)),
            episodeMetadata: metadataByFile[target.file.index],
            progress: target.isNext ? null : progressByFile[target.file.index],
            isNext: target.isNext,
            downloaded:
                state.downloadFor(target.file.index)?.status ==
                DownloadStatus.completed,
            horizontalPadding: horizontalPadding,
            dockedTop: false,
            onPressed: () => onFileSelected(target.file),
          )
        : const SizedBox.shrink(key: ValueKey('no_continue_bar'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DitherSwitcher(
          collapse: true,
          resizeDuration: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 200),
          child: topHeader,
        ),
        Expanded(
          child: DitherSwitcher(
            expand: true,
            duration: const Duration(milliseconds: 260),
            child: KeyedSubtree(
              key: ValueKey(useList ? 'episode_list' : 'episode_grid'),
              child: useList
                  ? PlayerEpisodesList(
                      source: state,
                      highlightedFileIndex: target?.file.index,
                      progressByFile: progressByFile,
                      listed: listed,
                      metadataByFile: metadataByFile,
                      horizontalPadding: horizontalPadding,
                      tabular: expanded && !DetailLayout.isLargeText(context),
                      topPadding: hasTopHeader ? 4 : 8,
                      isOnline: isOnline,
                      onSelected: onSelected,
                      onLongPressed: onLongPressed,
                    )
                  : Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: PlayerEpisodeGrid(
                        source: state,
                        highlightedFileIndex: target?.file.index,
                        progressByFile: progressByFile,
                        listed: listed,
                        metadataByFile: metadataByFile,
                        topPadding: hasTopHeader ? 16 : topGap,
                        isOnline: isOnline,
                        onSelected: onSelected,
                        onLongPressed: onLongPressed,
                      ),
                    ),
            ),
          ),
        ),
        if (!expanded) ...[
          DitherSwitcher(
            collapse: true,
            resizeDuration: const Duration(milliseconds: 200),
            duration: const Duration(milliseconds: 200),
            child: bottomContinueBar,
          ),
          DownloadSelectionFooter(
            visible: selecting,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: ReleaseDownloadActions(state: state, isOnline: isOnline),
            ),
          ),
        ],
      ],
    );
  }
}

/// Sticky left dossier rail on desktop windows: poster, anime title, release
/// summary and the primary Continue / Play next action, mirroring
/// `AnimeDetailsDesktopLayout` and `DownloadManagerView`.
class _DesktopDossierRail extends StatelessWidget {
  const _DesktopDossierRail({
    required this.animeTitles,
    required this.sourceTitle,
    required this.posterUrl,
    required this.episodeCount,
    required this.selecting,
    required this.target,
    required this.targetTitle,
    required this.targetNumber,
    required this.targetMetadata,
    required this.targetProgress,
    required this.targetDownloaded,
    required this.onContinue,
  });

  final AnimeTitles? animeTitles;
  final String sourceTitle;
  final String posterUrl;
  final int episodeCount;
  final bool selecting;
  final ({PlayerVideoFile file, bool isNext})? target;
  final String? targetTitle;
  final String? targetNumber;
  final EpisodeMetadata? targetMetadata;
  final WatchProgress? targetProgress;
  final bool targetDownloaded;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rule = DetailLayout.ruleColor(scheme);
    final titles = animeTitles;
    final primaryTitle = titles == null
        ? ''
        : watchAnimeTitleLabels(context, titles).primary;
    final releaseFacts = [
      if (sourceTitle.trim().isNotEmpty) sourceTitle.trim(),
      l10n.animeEpisodeCount('$episodeCount', episodeCount),
    ];
    final sansSmall = theme.textTheme.bodySmall?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: scheme.onSurfaceVariant,
    );
    final monoSmall = DetailLayout.monoTelemetryStyle(
      theme.textTheme.bodySmall,
      color: scheme.onSurfaceVariant,
    );
    final showContinue =
        !selecting &&
        target != null &&
        targetTitle != null &&
        targetNumber != null &&
        onContinue != null;

    final maxPosterHeight = (MediaQuery.sizeOf(context).height - 310).clamp(
      160.0,
      420.0,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 20, 24, 32),
      children: [
        if (posterUrl.isNotEmpty) ...[
          Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxPosterHeight),
              child: PosterImage(url: posterUrl, borderColor: rule),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (primaryTitle.isNotEmpty) ...[
          Text(
            primaryTitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontFamily: DetailLayout.sansFont,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (releaseFacts.isNotEmpty)
          PixelSeparatedText.parts(
            releaseFacts,
            cleanLineWrap: true,
            sansStyle: sansSmall,
            monoStyle: monoSmall,
          ),
        DitherSwitcher(
          collapse: true,
          resizeDuration: const Duration(milliseconds: 200),
          duration: const Duration(milliseconds: 200),
          child: showContinue
              ? _ContinueRailSection(
                  key: PlayerSourceView.continueBarKey,
                  title: targetTitle!,
                  number: targetNumber!,
                  episodeMetadata: targetMetadata,
                  progress: targetProgress,
                  isNext: target!.isNext,
                  downloaded: targetDownloaded,
                  onPressed: onContinue!,
                )
              : const SizedBox.shrink(key: ValueKey('no_continue_rail')),
        ),
      ],
    );
  }
}

class _ContinueRailSection extends StatelessWidget {
  const _ContinueRailSection({
    required this.title,
    required this.number,
    required this.episodeMetadata,
    required this.progress,
    required this.isNext,
    required this.downloaded,
    required this.onPressed,
    super.key,
  });

  final String title;
  final String number;
  final EpisodeMetadata? episodeMetadata;
  final WatchProgress? progress;
  final bool isNext;
  final bool downloaded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = this.progress;
    final showName = !nameIsJustNumber(title, number);
    final tags = episodeTags(episodeMetadata);
    final facts = [
      if (progress != null) releaseWatchPosition(l10n, progress),
      if (downloaded) l10n.playerSourceDownloaded,
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        Divider(height: 1, thickness: 1, color: DetailLayout.ruleColor(scheme)),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1, right: 10),
              child: Text(
                number,
                maxLines: 1,
                style: DetailLayout.monoTelemetryStyle(
                  theme.textTheme.titleSmall,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ),
            if (showName)
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: DetailLayout.sansFont,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ),
          ],
        ),
        if (facts.isNotEmpty || tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (facts.isNotEmpty)
                PixelSeparatedText.parts(
                  facts,
                  cleanLineWrap: true,
                  sansStyle: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: DetailLayout.sansFont,
                    color: scheme.onSurfaceVariant,
                  ),
                  monoStyle: DetailLayout.monoTelemetryStyle(
                    theme.textTheme.bodySmall,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              for (final tag in tags) EpisodeTagBadge(tag),
            ],
          ),
        ],
        if (progress != null && progress.duration > Duration.zero) ...[
          const SizedBox(height: 10),
          SegmentedBar(
            value: progress.fraction,
            height: 3,
            segment: 6,
            gap: 0,
            color: scheme.tertiary,
            trackColor: DetailLayout.progressTrackColor(
              scheme,
            ).withValues(alpha: 0.45),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: PlayerSourceView.continueButtonKey,
          onPressed: onPressed,
          child: Text(
            isNext
                ? l10n.watchProgressPlayNextButton
                : l10n.watchProgressContinueButton,
          ),
        ),
      ],
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({
    required this.state,
    required this.isOnline,
    required this.progressByFile,
    required this.listed,
  });

  final PlayerSourceReady state;
  final bool isOnline;
  final Map<int, WatchProgress> progressByFile;
  final Set<int> listed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final label = state.selected.isEmpty
        ? downloadSelectionTitle(l10n, isOnline)
        : l10n.playerSourceSelectedCount(state.selected.length);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
    );
    return Row(
      children: [
        Expanded(
          flex: 4,
          child: Row(
            children: [
              Flexible(
                child: MixedDataText(
                  label,
                  sansStyle: style?.copyWith(fontFamily: DetailLayout.sansFont),
                  monoStyle: DetailLayout.monoTelemetryStyle(style),
                ),
              ),
              const SizedBox(width: 14),
              DownloadPresetsMenu(
                state: state,
                isOnline: isOnline,
                progressByFile: progressByFile,
                listed: listed,
                outlined: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 5,
          child: ReleaseDownloadActions(
            state: state,
            isOnline: isOnline,
            inline: true,
          ),
        ),
      ],
    );
  }
}

/// Docked bar for resuming or playing the next episode on compact/medium
/// screens (and narrow landscape windows), aligned to the same horizontal rails
/// as `FramedAppBar` and `PlayerEpisodesList`.
class _ContinueBar extends StatelessWidget {
  const _ContinueBar({
    required this.title,
    required this.number,
    required this.episodeMetadata,
    required this.progress,
    required this.isNext,
    required this.downloaded,
    required this.horizontalPadding,
    required this.dockedTop,
    required this.onPressed,
    super.key,
  });

  final String title;

  /// As the list shows it: "04", "12.5".
  final String number;
  final EpisodeMetadata? episodeMetadata;

  /// Where the file stopped; null for the next, unwatched file.
  final WatchProgress? progress;
  final bool isNext;
  final bool downloaded;
  final double horizontalPadding;
  final bool dockedTop;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final progress = this.progress;
    final showName = !nameIsJustNumber(title, number);
    final tags = episodeTags(episodeMetadata);
    final facts = [
      if (progress != null) releaseWatchPosition(l10n, progress),
      if (downloaded) l10n.playerSourceDownloaded,
    ];
    final hasDetails = showName || facts.isNotEmpty || tags.isNotEmpty;
    final factsText = facts.isEmpty
        ? null
        : PixelSeparatedText.parts(
            facts,
            cleanLineWrap: true,
            sansStyle: theme.textTheme.bodySmall?.copyWith(
              fontFamily: DetailLayout.sansFont,
              color: scheme.onSurfaceVariant,
            ),
            monoStyle: DetailLayout.monoTelemetryStyle(
              theme.textTheme.bodySmall,
              color: scheme.onSurfaceVariant,
            ),
          );
    final titleStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
      fontWeight: FontWeight.w500,
      fontSize: 14.5,
      height: 1.28,
    );
    final stacked = !dockedTop && DetailLayout.isLargeText(context);
    final button = FilledButton(
      key: PlayerSourceView.continueButtonKey,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        minimumSize: const Size(0, 42),
      ),
      onPressed: onPressed,
      child: Text(
        isNext
            ? l10n.watchProgressPlayNextButton
            : l10n.watchProgressContinueButton,
      ),
    );
    final numberWidth = MediaQuery.textScalerOf(
      context,
    ).scale(42).clamp(42.0, 56.0);
    final numberWidget = SizedBox(
      width: numberWidth,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            number,
            maxLines: 1,
            style: DetailLayout.monoTelemetryStyle(
              theme.textTheme.titleSmall,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
      ),
    );
    final rule = BorderSide(color: DetailLayout.ruleColor(scheme));

    return LayoutBuilder(
      builder: (context, constraints) {
        final wideRow =
            dockedTop &&
            constraints.maxWidth >= WindowSizeClass.expandedMinWidth &&
            !DetailLayout.isLargeText(context);
        if (wideRow) {
          return DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(bottom: rule),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  numberWidget,
                  Expanded(
                    child: Row(
                      children: [
                        if (showName)
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle,
                            ),
                          ),
                        for (final tag in tags) ...[
                          if (showName || tag != tags.first)
                            const SizedBox(width: 8),
                          EpisodeTagBadge(tag),
                        ],
                      ],
                    ),
                  ),
                  if (factsText != null) ...[
                    const SizedBox(width: 16),
                    Flexible(flex: 0, child: factsText),
                  ],
                  const SizedBox(width: 16),
                  button,
                ],
              ),
            ),
          );
        }

        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showName)
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            if (factsText != null || tags.isNotEmpty) ...[
              if (showName) const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ?factsText,
                  for (final tag in tags) EpisodeTagBadge(tag),
                ],
              ),
            ],
          ],
        );

        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: dockedTop ? Border(bottom: rule) : Border(top: rule),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: dockedTop ? 10 : 12,
            ),
            child: stacked
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          numberWidget,
                          if (hasDetails) Expanded(child: details),
                        ],
                      ),
                      const SizedBox(height: 10),
                      button,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      numberWidget,
                      if (hasDetails)
                        Expanded(child: details)
                      else
                        const Spacer(),
                      const SizedBox(width: 12),
                      button,
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

    return RetryView(
      message: message,
      onRetry: () => context.read<PlayerSourceCubit>().loadSource(),
    );
  }
}
