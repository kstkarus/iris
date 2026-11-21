import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps the native frame in step with the app, with mounted players taking
/// precedence in the order they were opened.
class WindowsTitleBarTheme {
  static const _channel = MethodChannel('iris/window');

  final _players = <Object, ColorScheme>{};
  ColorScheme? _app;
  ({bool dark, int caption, int text, int border})? _sent;

  void setAppTheme(ColorScheme scheme) {
    _app = scheme;
    _sync();
  }

  void setPlayerTheme(Object player, ColorScheme scheme) {
    _players[player] = scheme;
    _sync();
  }

  void clearPlayerTheme(Object player) {
    if (_players.remove(player) != null) _sync();
  }

  void _sync() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.windows) return;
    final scheme = _players.isEmpty ? _app : _players.values.last;
    if (scheme == null) return;
    final theme = (
      dark: scheme.brightness == Brightness.dark,
      caption: scheme.surface.toARGB32(),
      text: scheme.onSurface.toARGB32(),
      border: scheme.outlineVariant.toARGB32(),
    );
    if (theme == _sent) return;
    _sent = theme;
    unawaited(_apply(theme));
  }

  Future<void> _apply(
    ({bool dark, int caption, int text, int border}) theme,
  ) async {
    try {
      await _channel.invokeMethod<void>('setTitleBarTheme', {
        'dark': theme.dark,
        'captionColor': theme.caption,
        'textColor': theme.text,
        'borderColor': theme.border,
      });
    } on MissingPluginException {
      // The window channel is absent in widget tests.
    }
  }
}
