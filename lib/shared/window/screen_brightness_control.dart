import 'dart:developer' as developer;

import 'package:screen_brightness/screen_brightness.dart';

/// The screen's brightness while the app is in front, from 0 to 1. A
/// change holds for this app only and [reset] gives the system's back.
abstract interface class ScreenBrightnessControl {
  Future<double> current();

  Future<void> set(double brightness);

  Future<void> reset();
}

/// Phones and tablets: the window's own brightness through the
/// screen_brightness plugin; no permission is needed, and the system's
/// setting stays as the user left it.
class PluginScreenBrightnessControl implements ScreenBrightnessControl {
  const PluginScreenBrightnessControl();

  ScreenBrightness get _plugin => ScreenBrightness.instance;

  @override
  Future<double> current() async {
    try {
      return await _plugin.application;
    } catch (error) {
      _log('read', error);
      return 0.5;
    }
  }

  @override
  Future<void> set(double brightness) async {
    try {
      await _plugin.setApplicationScreenBrightness(brightness.clamp(0.0, 1.0));
    } catch (error) {
      _log('set', error);
    }
  }

  @override
  Future<void> reset() async {
    try {
      await _plugin.resetApplicationScreenBrightness();
    } catch (error) {
      _log('reset', error);
    }
  }

  void _log(String action, Object error) => developer.log(
    'Failed to $action the screen brightness.',
    name: 'iris.window',
    error: error,
  );
}
