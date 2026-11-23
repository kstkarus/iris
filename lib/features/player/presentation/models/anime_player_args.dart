import 'package:iris/features/player/domain/entities/anime_player_source.dart';

/// The `player` route's argument.
class AnimePlayerArgs {
  const AnimePlayerArgs(this.source, {this.playFromRelease = false});

  final AnimePlayerSource source;
  final bool playFromRelease;
}
