import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

abstract final class AppHaptics {
  static const _android = MethodChannel('iris/haptics');
  static Future<bool>? _capability;

  static ({
    Future<bool> Function() canVibrate,
    Future<void> Function(HapticsType) vibrate,
  })?
  _override;

  @visibleForTesting
  static set debugOverride(
    ({
      Future<bool> Function() canVibrate,
      Future<void> Function(HapticsType) vibrate,
    })?
    backend,
  ) {
    _override = backend;
    _capability = null;
  }

  static void selection() => _trigger(HapticsType.selection);
  static void light() => _trigger(HapticsType.light);
  static void medium() => _trigger(HapticsType.medium);
  static void success() => _trigger(HapticsType.success);
  static void warning() => _trigger(HapticsType.warning);
  static void error() => _trigger(HapticsType.error);

  static void _trigger(HapticsType type) {
    if (kIsWeb) return;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android || TargetPlatform.iOS:
        unawaited(_vibrate(type));
      default:
        break;
    }
  }

  static Future<void> _vibrate(HapticsType type) async {
    final backend = _override;
    try {
      if (!await (_capability ??=
          (backend?.canVibrate ?? Haptics.canVibrate)())) {
        return;
      }
      if (backend != null) {
        await backend.vibrate(type);
      } else {
        if (defaultTargetPlatform == TargetPlatform.android &&
            await _android.invokeMethod<bool>('touchFeedbackEnabled') != true) {
          return;
        }
        await Haptics.vibrate(
          type,
          usage: HapticsUsage.touch,
          useAndroidHapticConstants: true,
        );
      }
    } on MissingPluginException {
      _capability = Future.value(false);
    } on PlatformException {
      _capability = Future.value(false);
    }
  }
}
