import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:libtorrent_flutter/libtorrent_flutter.dart';
import 'package:media_kit/media_kit.dart';

/// Fixed listen port instead of libtorrent's random `:0` default: on Windows
/// a random port often lands in ranges reserved by Hyper-V/WSL and the bind
/// fails. libtorrent falls back to an OS-assigned port if this one is busy.
const _torrentListenPort = 6890;
const _torrentListenInterfaces =
    '0.0.0.0:$_torrentListenPort,[::]:$_torrentListenPort';

/// Session settings shared by streams and downloads. They are applied as soon
/// as the engine starts, so downloads restored at launch run with them too.
const torrentSessionConfig = BtConfig(
  cacheSize: 256 * 1024 * 1024,
  readerReadAhead: 95,
  preloadCache: 60,
  responsiveMode: true,
  // With IPv6 disabled the native bridge rebinds the session to
  // 0.0.0.0:6881, overriding the listen interfaces set at init.
  enableIpv6: true,
);

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
    await startTorrentEngine(
      init: () =>
          LibtorrentFlutter.init(listenInterface: _torrentListenInterfaces),
      configureSession: (config) =>
          LibtorrentFlutter.instance.configureSession(config),
    );
    _initialized = true;
    developer.log(
      'Playback runtime initialized successfully.',
      name: 'iris.player.runtime',
    );
  }
}

/// Starts the engine and applies [torrentSessionConfig] before anything can
/// add a torrent.
@visibleForTesting
Future<void> startTorrentEngine({
  required Future<void> Function() init,
  required void Function(BtConfig config) configureSession,
}) async {
  await init();
  configureSession(torrentSessionConfig);
}
