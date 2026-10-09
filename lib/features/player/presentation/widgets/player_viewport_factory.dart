import 'package:flutter/material.dart';

import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';

/// The file after the playing one.
class PlayerNextFile {
  const PlayerNextFile({required this.title, required this.play});

  final String title;
  final VoidCallback play;
}

/// Builds the episodes list shown in the immersive player's drawer;
/// [close] hides the drawer.
typedef PlayerEpisodesBuilder =
    Widget Function(BuildContext context, VoidCallback close);

/// A short message over the immersive player, with one action.
class PlayerNotice {
  const PlayerNotice({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.onTimeout,
    this.timeout,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  /// How long it stays, counted from when this is first set; null keeps it,
  /// e.g. while the file starts.
  final Duration? timeout;
  final VoidCallback onTimeout;
}

/// What the immersive player draws around the video: the titles, the way
/// back and the episodes drawer.
class PlayerChrome {
  const PlayerChrome({
    required this.title,
    required this.onBack,
    this.titleDetail,
    this.overline,
    this.details,
    this.episodes,
    this.episodesCaption,
    this.notice,
  });

  /// The episode, the largest line.
  final String title;

  /// Dimmed after [title] on its line, e.g. "of 37".
  final String? titleDetail;

  /// The anime, or the release's title, above [title].
  final String? overline;

  /// The episode's place in the release, below [title].
  final String? details;

  final VoidCallback onBack;

  /// Null when the torrent has a single file.
  final PlayerEpisodesBuilder? episodes;

  /// Under the episodes' heading, e.g. the full release name.
  final String? episodesCaption;

  /// Shown above the timeline while set, e.g. the automatic resume.
  final PlayerNotice? notice;
}

/// Creates the page's media player and the widget that renders it.
abstract interface class PlayerViewportFactory {
  /// One engine per player page; [PlayerCubit] owns and closes it.
  PlayerEngine createEngine({
    required PlayerSubtitlePreferencesCubit subtitlePreferences,
    required PlayerDecodingPreferencesCubit decodingPreferences,
  });

  /// Renders [engine]. The widget owns nothing, so rebuilding or moving it
  /// (layout changes, full screen) never interrupts playback.
  ///
  /// [next] is offered in the player's own controls and when a file ends,
  /// also in full screen; null when there is no next file.
  ///
  /// With [chrome] the widget fills its box and draws immersive controls
  /// (titles, back, episodes drawer, keyboard shortcuts) over the video;
  /// full screen then only switches the window, without a separate route.
  Widget build({
    required PlayerEngine engine,
    PlayerNextFile? next,
    PlayerChrome? chrome,
  });
}
