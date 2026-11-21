import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'package:iris/features/player/domain/player_media_controls.dart';

class MethodChannelPlayerMediaControls implements PlayerMediaControls {
  static const _channel = MethodChannel('iris/player_media_controls');
  static int _lastSession = 0;
  static int? _activeSession;

  int? _session;
  PlayerMediaCommandHandler? _onCommand;

  @override
  Future<void> update({
    required PlayerMediaTitles titles,
    required PlayerMediaPlayback playback,
    required bool canNext,
    required PlayerMediaCommandHandler onCommand,
  }) async {
    if (_session == null) {
      _session = _activeSession = ++_lastSession;
      _channel.setMethodCallHandler(_handleCommand);
    }
    if (_session != _activeSession) return;
    _onCommand = onCommand;
    await _invoke('update', {
      'session': _session,
      'title': titles.title,
      'episode': titles.episode,
      'canNext': canNext,
      'playing': playback.playing,
      'buffering': playback.buffering,
      'positionMs': playback.position.inMilliseconds,
      'durationMs': playback.duration.inMilliseconds,
      'rate': playback.rate,
    });
  }

  @override
  Future<void> deactivate() async {
    final session = _session;
    _session = null;
    _onCommand = null;
    if (session == null || session != _activeSession) return;
    _activeSession = null;
    _channel.setMethodCallHandler(null);
    await _invoke('deactivate', {'session': session});
  }

  Future<void> _handleCommand(MethodCall call) async {
    final session = _session;
    final arguments = call.arguments;
    if (session == null ||
        session != _activeSession ||
        arguments is! Map ||
        arguments['session'] != session) {
      return;
    }
    final command = PlayerMediaCommand.values
        .where((command) => command.name == call.method)
        .firstOrNull;
    if (command == null) return;
    final positionMs = arguments['positionMs'];
    await _onCommand?.call(
      command,
      positionMs is int ? Duration(milliseconds: positionMs) : null,
    );
  }

  Future<void> _invoke(String method, Map<String, Object?> arguments) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // The player still works when the system media session is unavailable.
    } on PlatformException catch (error) {
      developer.log(
        'Media controls $method failed.',
        name: 'iris.player',
        error: error,
      );
    }
  }
}
