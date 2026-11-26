import 'package:flutter/widgets.dart';

import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';

/// Slot builders supplied by `app_router.dart` so `AnimeDetailsPage` can host
/// inline desktop Watch Sources and Episode Picker steps inside its shared
/// dossier frame without coupling `anime_details` to other features' cubits or
/// presentation widgets.
class AnimeDesktopWatchHost {
  const AnimeDesktopWatchHost({
    required this.buildSourcesScope,
    required this.buildEpisodesScope,
  });

  /// Lazily provides Watch Sources cubits and builds the sources pane + bar
  /// action, keeping the scope alive while the user switches between Overview,
  /// Sources, and Episodes.
  final Widget Function(
    BuildContext context, {
    required AnimeWatchSourcesArgs args,
    required bool active,
    required bool desktopSplit,
    required ValueChanged<AnimePlayerSourceArgs> onOpenSource,
    required Widget Function(
      BuildContext context, {
      required Widget pane,
      required Widget addButton,
    })
    builder,
  })
  buildSourcesScope;

  /// Provides Episode Picker cubits for the selected release and exposes its
  /// app bar, rail details, workspace pane, and Escape/Back selection hook.
  final Widget Function(
    BuildContext context, {
    required AnimePlayerSourceArgs args,
    required bool active,
    required bool desktopSplit,
    required Widget backAction,
    required VoidCallback onBackStep,
    required Widget Function(
      BuildContext context, {
      required PreferredSizeWidget appBar,
      required Widget railDetails,
      required Widget pane,
      required VoidCallback onEscape,
    })
    builder,
  })
  buildEpisodesScope;
}
