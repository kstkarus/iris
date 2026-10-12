import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The player in a small window over everything else: the system's picture
/// in picture on Android.
abstract interface class PictureInPicture {
  /// Whether this device can show it.
  Future<bool> isSupported();

  /// True while the player is in the small window.
  ValueListenable<bool> get active;

  /// Play or pause was pressed in the small window.
  Stream<void> get playPausePressed;

  /// The small window was closed, rather than opened back to full size.
  Stream<void> get dismissed;

  /// The player page tells what plays: the window takes the video's
  /// [aspectRatio] (width over height), its button shows play or pause, and
  /// while [playing] the system opens the window on its own when the user
  /// leaves the app.
  Future<void> setPlayer({
    required bool playing,
    required double? aspectRatio,
    required String playLabel,
    required String pauseLabel,
  });

  /// The player page closed: nothing to open the window for any more.
  Future<void> clearPlayer();

  /// Into the small window now; false when the system refuses, as when the
  /// user turned picture in picture off for the app.
  Future<bool> enter();
}

/// Android's picture in picture, run by `MainActivity` (Android 8 and
/// later) over the `iris/picture_in_picture` channel.
class AndroidPictureInPicture implements PictureInPicture {
  AndroidPictureInPicture({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const channelName = 'iris/picture_in_picture';

  final MethodChannel _channel;
  final _active = ValueNotifier<bool>(false);
  final _playPause = StreamController<void>.broadcast();
  final _dismissed = StreamController<void>.broadcast();

  Future<void> _onCall(MethodCall call) async {
    switch (call.method) {
      case 'playPause':
        _playPause.add(null);
      case 'modeChanged':
        final arguments = call.arguments as Map<Object?, Object?>;
        _active.value = arguments['active'] == true;
        if (arguments['dismissed'] == true) _dismissed.add(null);
    }
  }

  @override
  Future<bool> isSupported() async =>
      await _channel.invokeMethod<bool>('isSupported') ?? false;

  @override
  ValueListenable<bool> get active => _active;

  @override
  Stream<void> get playPausePressed => _playPause.stream;

  @override
  Stream<void> get dismissed => _dismissed.stream;

  @override
  Future<void> setPlayer({
    required bool playing,
    required double? aspectRatio,
    required String playLabel,
    required String pauseLabel,
  }) => _channel.invokeMethod<void>('setPlayer', {
    'playing': playing,
    'aspectRatio': aspectRatio,
    'playLabel': playLabel,
    'pauseLabel': pauseLabel,
  });

  @override
  Future<void> clearPlayer() => _channel.invokeMethod<void>('clearPlayer');

  @override
  Future<bool> enter() async =>
      await _channel.invokeMethod<bool>('enter') ?? false;
}
