import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Player slider position, from 0 to 1. [reset] restores the previous level.
abstract interface class ScreenBrightnessControl {
  Future<double> current();

  Future<void> set(double brightness);

  Future<void> reset();
}

/// Phones and tablets: brightness through the screen_brightness plugin.
class PluginScreenBrightnessControl implements ScreenBrightnessControl {
  const PluginScreenBrightnessControl();

  ScreenBrightness get _plugin => ScreenBrightness.instance;

  @override
  Future<double> current() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        // The plugin's animation can stop short of the requested brightness.
        await _plugin.setAnimate(false);
      } catch (error) {
        _log('configure', error);
      }
    }
    try {
      return _brightnessToSlider(await _plugin.application);
    } catch (error) {
      _log('read', error);
      return 0.5;
    }
  }

  @override
  Future<void> set(double brightness) async {
    try {
      await _plugin.setApplicationScreenBrightness(
        _sliderToBrightness(brightness),
      );
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

// The same HLG curve used by Android's brightness slider.
const _hlgA = 0.17883277;
const _hlgB = 0.28466892;
const _hlgC = 0.55991073;

double _sliderToBrightness(double slider) {
  final value = slider.clamp(0.0, 1.0);
  if (value == 0 || value == 1) return value;
  final scaled = value <= 0.5
      ? math.pow(value / 0.5, 2).toDouble()
      : math.exp((value - _hlgC) / _hlgA) + _hlgB;
  return (scaled / 12).clamp(0.0, 1.0);
}

double _brightnessToSlider(double brightness) {
  final value = brightness.clamp(0.0, 1.0);
  if (value == 0 || value == 1) return value;
  final scaled = value * 12;
  return (scaled <= 1
          ? math.sqrt(scaled) * 0.5
          : _hlgA * math.log(scaled - _hlgB) + _hlgC)
      .clamp(0.0, 1.0);
}
