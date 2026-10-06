import 'package:flutter/services.dart';

/// Full screen for the app's window on Windows, switched by the runner
/// (`windows/runner/flutter_window.cpp`). Unlike media_kit's own switch it
/// changes the frame and the bounds as one step, without an unthemed title
/// bar flashing in between.
abstract final class WindowsFullscreen {
  static const _channel = MethodChannel('iris/window');

  static Future<void> enter() => _channel.invokeMethod<void>('enterFullscreen');

  static Future<void> exit() => _channel.invokeMethod<void>('exitFullscreen');
}
