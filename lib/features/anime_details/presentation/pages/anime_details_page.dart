import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/anime/domain/anime_titles.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_cubit.dart';
import 'package:iris/features/anime_details/presentation/cubit/anime_details_state.dart';
import 'package:iris/features/anime_details/presentation/models/anime_desktop_watch_host.dart';
import 'package:iris/features/anime_details/presentation/models/anime_details_preview.dart';
import 'package:iris/features/anime_details/presentation/widgets/anime_details_view.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/settings/presentation/anime_title_labels.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/headline_page.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

enum _AnimeDesktopStep { overview, sources, episodes }

/// The anime name heads the content, so the bar only navigates back until
/// the name scrolls under it; then the bar shows the name.
///
/// On desktop windows (when [desktopWatchHost] is supplied by the router),
/// choosing sources or episodes swaps the right column and lower rail in place
/// inside the same poster frame, stepping backwards on Escape or Back.
class AnimeDetailsPage extends StatefulWidget {
  const AnimeDetailsPage({this.preview, this.desktopWatchHost, super.key});

  /// What the catalog already knows about the title, if it was opened
  /// from there.
  final AnimeDetailsPreview? preview;
  final AnimeDesktopWatchHost? desktopWatchHost;

  static const backToDescriptionKey = Key('anime_details_back_to_description');
  static const backFromEpisodesKey = Key('anime_details_back_from_episodes');

  @override
  State<AnimeDetailsPage> createState() => _AnimeDetailsPageState();
}

class _AnimeDetailsPageState extends State<AnimeDetailsPage> {
  // Keeps HeadlinePage, AnimeDetailsDesktopLayout, scroll controllers,
  // DitherSwitchers, and PosterImage mounted across scope wraps so the poster
  // never blinks and every inline step transition animates smoothly.
  final _shellKey = GlobalKey();
  final List<_AnimeDesktopStep> _stack = [_AnimeDesktopStep.overview];
  AnimeWatchSourcesArgs? _sourcesArgs;
  AnimePlayerSourceArgs? _episodesArgs;
  int _mountedEpisodeSlots = 0;

  _AnimeDesktopStep get _currentStep => _stack.last;

  bool get _hasSourcesInStack => _stack.contains(_AnimeDesktopStep.sources);

  void _onEpisodeSlotMounted() {
    _mountedEpisodeSlots++;
  }

  void _onEpisodeSlotDisposed() {
    if (_mountedEpisodeSlots > 0) _mountedEpisodeSlots--;
    if (_mountedEpisodeSlots == 0 &&
        _currentStep != _AnimeDesktopStep.episodes &&
        _episodesArgs != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _mountedEpisodeSlots > 0 ||
            _currentStep == _AnimeDesktopStep.episodes ||
            _episodesArgs == null) {
          return;
        }
        setState(() => _episodesArgs = null);
      });
    }
  }

  void _openSourcesInline(AnimeDetailsPreview head) {
    final args = AnimeWatchSourcesArgs.forAnime(
      animeId: head.anime.id,
      animeTitles: head.anime.titles,
      posterUrl: head.anime.posterUrl,
    );
    setState(() {
      _sourcesArgs ??= args;
      if (_currentStep != _AnimeDesktopStep.sources) {
        _stack.add(_AnimeDesktopStep.sources);
      }
    });
  }

  void _openEpisodesInline(AnimePlayerSourceArgs args) {
    setState(() {
      _episodesArgs = args;
      if (_currentStep == _AnimeDesktopStep.episodes) {
        // Switching directly to another release replaces the current episode step.
        return;
      }
      _stack.add(_AnimeDesktopStep.episodes);
    });
  }

  void _popStep() {
    if (_stack.length <= 1) return;
    setState(() {
      final popped = _stack.removeLast();
      if (popped == _AnimeDesktopStep.episodes && _mountedEpisodeSlots == 0) {
        _episodesArgs = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loaded = context.select<AnimeDetailsCubit, AnimeTitles?>(
      (cubit) => switch (cubit.state) {
        AnimeDetailsSuccess(:final details) => details.anime.titles,
        _ => null,
      },
    );
    final titles = loaded ?? widget.preview?.anime.titles;
    final primaryTitle = titles == null
        ? ''
        : watchAnimeTitleLabels(context, titles).primary;
    final host = widget.desktopWatchHost;
    final sizeClass = WindowSizeClass.of(context);
    final desktopSplit = sizeClass.isAtLeast(WindowSizeClass.expanded);

    Widget buildShell({
      PreferredSizeWidget? appBarOverride,
      Object stepKey = 'overview',
      Widget? railStepOverride,
      Widget? rightStepOverride,
      VoidCallback? onEscape,
    }) {
      final canPopRoute = _stack.length == 1;
      void handleEscape() {
        if (ModalRoute.of(context)?.isCurrent != true) return;
        if (onEscape != null) {
          onEscape();
        } else {
          _popStep();
        }
      }

      return PopScope(
        key: _shellKey,
        canPop: canPopRoute,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            if (onEscape != null) {
              onEscape();
            } else {
              _popStep();
            }
          }
        },
        child: CallbackShortcuts(
          bindings: {
            if (!canPopRoute)
              const SingleActivator(LogicalKeyboardKey.escape): handleEscape,
          },
          child: FocusScope(
            autofocus: true,
            child: HeadlinePage(
              title: primaryTitle,
              appBarOverride: appBarOverride,
              body: Padding(
                padding: EdgeInsets.symmetric(horizontal: sizeClass.pageMargin),
                child: MaxWidthBox(
                  maxWidth: AdaptiveContentWidth.page,
                  child: AnimeDetailsView(
                    preview: widget.preview,
                    onChooseSources: host != null && desktopSplit
                        ? _openSourcesInline
                        : null,
                    onOpenRecentSource: host != null && desktopSplit
                        ? _openEpisodesInline
                        : null,
                    stepKey: stepKey,
                    railStepOverride: railStepOverride,
                    rightStepOverride: rightStepOverride,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    Widget buildNonEpisodeStep(
      BuildContext context, {
      Widget? sourcesPane,
      Widget? sourcesAddButton,
    }) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      final scheme = theme.colorScheme;

      if (_currentStep == _AnimeDesktopStep.sources && sourcesPane != null) {
        final sourcesRail = Column(
          key: const ValueKey('rail_sources'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              key: AnimeDetailsPage.backToDescriptionKey,
              onPressed: _popStep,
              icon: const PixelIcon(PixelGlyph.arrowLeft, size: 14),
              label: Text(l10n.animeDetailsBackToDescriptionButton),
            ),
          ],
        );
        return buildShell(
          appBarOverride: FramedAppBar(
            key: const ValueKey('inline_sources_bar'),
            title: PageTitle(
              title: l10n.watchSourcesTitle,
              subtitle: desktopSplit ? null : primaryTitle,
            ),
            trailing: sourcesAddButton,
          ),
          stepKey: 'sources',
          railStepOverride: sourcesRail,
          rightStepOverride: sourcesPane,
          onEscape: _popStep,
        );
      }

      return buildShell();
    }

    Widget buildCurrentStep(
      BuildContext context, {
      Widget? sourcesPane,
      Widget? sourcesAddButton,
    }) {
      final episodesArgs = _episodesArgs;
      if (host != null && episodesArgs != null) {
        final l10n = AppLocalizations.of(context);
        final episodesActive = _currentStep == _AnimeDesktopStep.episodes;
        final backAction = OutlinedButton.icon(
          key: AnimeDetailsPage.backFromEpisodesKey,
          onPressed: _popStep,
          icon: const PixelIcon(PixelGlyph.arrowLeft, size: 14),
          label: Text(
            _hasSourcesInStack
                ? l10n.animeDetailsBackToSourcesButton
                : l10n.animeDetailsBackToDescriptionButton,
          ),
        );
        return host.buildEpisodesScope(
          context,
          args: episodesArgs,
          active: episodesActive,
          desktopSplit: desktopSplit,
          backAction: backAction,
          onBackStep: _popStep,
          builder:
              (
                context, {
                required appBar,
                required railDetails,
                required pane,
                required onEscape,
              }) {
                if (episodesActive) {
                  return buildShell(
                    appBarOverride: _TrackedPreferredSizeSlot(
                      key: appBar.key,
                      preferredSize: appBar.preferredSize,
                      onMount: _onEpisodeSlotMounted,
                      onDispose: _onEpisodeSlotDisposed,
                      child: appBar,
                    ),
                    stepKey: ('episodes', episodesArgs.magnet),
                    railStepOverride: _TrackedSlot(
                      onMount: _onEpisodeSlotMounted,
                      onDispose: _onEpisodeSlotDisposed,
                      child: railDetails,
                    ),
                    rightStepOverride: _TrackedSlot(
                      onMount: _onEpisodeSlotMounted,
                      onDispose: _onEpisodeSlotDisposed,
                      child: pane,
                    ),
                    onEscape: onEscape,
                  );
                }
                return buildNonEpisodeStep(
                  context,
                  sourcesPane: sourcesPane,
                  sourcesAddButton: sourcesAddButton,
                );
              },
        );
      }

      return buildNonEpisodeStep(
        context,
        sourcesPane: sourcesPane,
        sourcesAddButton: sourcesAddButton,
      );
    }

    final sourcesArgs = _sourcesArgs;
    if (host != null && sourcesArgs != null) {
      return host.buildSourcesScope(
        context,
        args: sourcesArgs,
        active: _currentStep == _AnimeDesktopStep.sources,
        desktopSplit: desktopSplit,
        onOpenSource: _openEpisodesInline,
        builder: (context, {required pane, required addButton}) =>
            buildCurrentStep(
              context,
              sourcesPane: pane,
              sourcesAddButton: addButton,
            ),
      );
    }

    return buildCurrentStep(context);
  }
}

/// Reports mount/dispose of an inline step slot so its enclosing BLoC scope
/// stays alive until `DitherSwitcher` finishes dissolving the outgoing child.
class _TrackedSlot extends StatefulWidget {
  const _TrackedSlot({
    required this.onMount,
    required this.onDispose,
    required this.child,
  });

  final VoidCallback onMount;
  final VoidCallback onDispose;
  final Widget child;

  @override
  State<_TrackedSlot> createState() => _TrackedSlotState();
}

class _TrackedSlotState extends State<_TrackedSlot> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _TrackedPreferredSizeSlot extends StatelessWidget
    implements PreferredSizeWidget {
  const _TrackedPreferredSizeSlot({
    required this.preferredSize,
    required this.onMount,
    required this.onDispose,
    required this.child,
    super.key,
  });

  @override
  final Size preferredSize;
  final VoidCallback onMount;
  final VoidCallback onDispose;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      _TrackedSlot(onMount: onMount, onDispose: onDispose, child: child);
}
