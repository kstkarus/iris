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
  Widget build({required PlayerEngine engine, PlayerNextFile? next});
}
