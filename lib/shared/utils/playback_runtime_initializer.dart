import 'dart:developer' as developer;

import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:media_kit/media_kit.dart';

abstract final class PlaybackRuntimeInitializer {
  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) {
      developer.log(
        'Playback runtime already initialized.',
        name: 'iris.player.runtime',
      );
      return;
    }

    developer.log(
      'Initializing playback runtime.',
      name: 'iris.player.runtime',
    );
    MediaKit.ensureInitialized();
    await LibtorrentFlutter.init();
    _initialized = true;
    developer.log(
      'Playback runtime initialized successfully.',
      name: 'iris.player.runtime',
    );
  }
}
