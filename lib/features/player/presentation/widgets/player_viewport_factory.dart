import 'package:flutter/material.dart';

import 'package:iris/features/player/presentation/cubit/player_decoding_preferences_cubit.dart';
import 'package:iris/features/player/presentation/cubit/player_subtitle_preferences_cubit.dart';
import 'package:iris/features/player/presentation/playback/player_engine.dart';

/// How the viewer drives the player: a mouse and keyboard (desktop), or a
/// finger (phones and tablets). One layout serves both, sized for each.
enum PlayerInputMode { pointer, touch }

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

/// What the player draws around the video: the titles, the way back and
/// the episodes drawer.
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

  /// Renders [engine], filling its box, with immersive controls drawn
  /// over the video: [chrome]'s titles, the way back and the episodes
  /// drawer. The widget owns nothing, so rebuilding it (rotation, window
  /// resize, full screen) never interrupts playback.
  ///
  /// [input] sizes the controls for a pointer or a finger; only a pointer
  /// gets keyboard full screen and the volume, which phones keep on their
  /// own buttons. [next] is offered in the controls and when a file ends;
  /// null when there is no next file.
  Widget build({
    required PlayerEngine engine,
    required PlayerChrome chrome,
    PlayerInputMode input = PlayerInputMode.pointer,
    PlayerNextFile? next,
  });
}
