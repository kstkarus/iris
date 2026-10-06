import 'dart:developer' as developer;

import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:media_kit/media_kit.dart';

/// Fixed listen port instead of libtorrent's random `:0` default: on Windows
/// a random port often lands in ranges reserved by Hyper-V/WSL and the bind
/// fails. libtorrent falls back to an OS-assigned port if this one is busy.
const torrentListenPort = 6890;
const torrentListenInterfaces =
    '0.0.0.0:$torrentListenPort,[::]:$torrentListenPort';

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
    await LibtorrentFlutter.init(listenInterface: torrentListenInterfaces);
    _initialized = true;
    developer.log(
      'Playback runtime initialized successfully.',
      name: 'iris.player.runtime',
    );
  }
}
