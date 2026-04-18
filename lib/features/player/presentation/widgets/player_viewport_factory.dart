import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';

abstract interface class PlayerViewportFactory {
  Widget build({
    required AnimePlayerSource source,
    required PlayerSession session,
  });
}
