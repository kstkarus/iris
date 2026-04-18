import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/anime_player_source.dart';
import 'package:iris/features/player/domain/entities/player_session.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';

class MockPlayerViewportFactory implements PlayerViewportFactory {
  const MockPlayerViewportFactory();

  @override
  Widget build({
    required AnimePlayerSource source,
    required PlayerSession session,
  }) {
    return Center(
      child: Container(
        key: const Key('mock_player_surface'),
        width: double.infinity,
        height: 220,
        color: Colors.black,
        alignment: Alignment.center,
        child: const Text(
          'Mock Player Surface',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
