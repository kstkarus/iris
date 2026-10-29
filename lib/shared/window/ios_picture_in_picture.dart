import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:iris/shared/window/picture_in_picture.dart';

/// AVKit displays the current mpv renderer's frames on iOS 15 and later.
class IOSPictureInPicture implements PictureInPicture {
  IOSPictureInPicture({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName) {
    _channel.setMethodCallHandler(_onCall);
  }

  static const channelName = 'iris/picture_in_picture';
  final MethodChannel _channel;
  final _active = ValueNotifier(false);
  final _dismissed = StreamController<void>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _seeks = StreamController<({int id, Duration interval})>.broadcast();
  int? _handle;

  Stream<bool> get playingRequested => _playing.stream;
  Stream<({int id, Duration interval})> get seekRequested => _seeks.stream;

  Future<void> _onCall(MethodCall call) async {
    final arguments = call.arguments;
    if (arguments is! Map<Object?, Object?>) return;
    final handle = _handle;
    if (handle == null || arguments['handle'] != handle.toString()) return;
    switch (call.method) {
      case 'modeChanged':
        _active.value = arguments['active'] == true;
        if (arguments['dismissed'] == true) _dismissed.add(null);
      case 'setPlaying':
        final playing = arguments['playing'];
        if (playing is bool) _playing.add(playing);
      case 'seek':
        final id = arguments['id'];
        final milliseconds = arguments['milliseconds'];
        if (id is int && milliseconds is int) {
          _seeks.add((id: id, interval: Duration(milliseconds: milliseconds)));
        }
    }
  }

  @override
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<bool> attachPlayer(int handle) async {
    if (_handle != handle) _active.value = false;
    _handle = handle;
    final attached =
        await _channel.invokeMethod<bool>('attachPlayer', {
          'handle': handle.toString(),
        }) ??
        false;
    if (!attached && _handle == handle) _handle = null;
    return attached && _handle == handle;
  }

  Future<void> setPlayback({
    required Duration position,
    required Duration duration,
    required double rate,
  }) => _channel.invokeMethod<void>('setPlayback', {
    'handle': _handle?.toString(),
    'position': position.inMilliseconds,
    'duration': duration.inMilliseconds,
    'rate': rate,
  });

  Future<void> completeSeek(int id) => _channel.invokeMethod<void>(
    'seekCompleted',
    {'handle': _handle?.toString(), 'id': id},
  );

  @override
  ValueListenable<bool> get active => _active;

  @override
  Stream<void> get playPausePressed => const Stream.empty();

  @override
  Stream<void> get dismissed => _dismissed.stream;

  @override
  Future<void> setPlayer({
    required bool playing,
    required double? aspectRatio,
    required String playLabel,
    required String pauseLabel,
  }) => _channel.invokeMethod<void>('setPlayer', {
    'handle': _handle?.toString(),
    'playing': playing,
    'aspectRatio': aspectRatio,
  });

  @override
  Future<bool> enter() async {
    final handle = _handle;
    if (handle == null) return false;
    final entered =
        await _channel.invokeMethod<bool>('enter', {
          'handle': handle.toString(),
        }) ??
        false;
    return entered && _handle == handle;
  }

  @override
  Future<void> clearPlayer() async {
    final handle = _handle;
    _handle = null;
    _active.value = false;
    await _channel.invokeMethod<void>('clearPlayer', {
      'handle': handle?.toString(),
    });
  }
}
