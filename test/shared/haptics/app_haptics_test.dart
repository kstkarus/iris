import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'package:iris/shared/haptics/app_haptics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late TargetPlatform? originalPlatform;

  setUp(() {
    originalPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    AppHaptics.debugOverride = null;
    debugDefaultTargetPlatformOverride = originalPlatform;
  });

  test('only mobile platforms consult the haptics backend', () {
    fakeAsync((async) {
      var probes = 0;
      final effects = <HapticsType>[];
      AppHaptics.debugOverride = (
        canVibrate: () async {
          probes++;
          return true;
        },
        vibrate: (type) async => effects.add(type),
      );
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        debugDefaultTargetPlatformOverride = platform;
        AppHaptics.selection();
      }
      async.flushMicrotasks();
      expect(probes, 0);
      expect(effects, isEmpty);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      AppHaptics.selection();
      async.flushMicrotasks();
      expect(probes, 1);
      expect(effects, [HapticsType.selection]);
    });
  });

  test('maps intents and shares one lazy capability check', () {
    fakeAsync((async) {
      final capability = Completer<bool>();
      final effects = <HapticsType>[];
      var probes = 0;
      AppHaptics.debugOverride = (
        canVibrate: () {
          probes++;
          return capability.future;
        },
        vibrate: (type) async => effects.add(type),
      );
      expect(probes, 0);

      AppHaptics.selection();
      AppHaptics.light();
      AppHaptics.medium();
      expect(probes, 1);
      expect(effects, isEmpty);

      capability.complete(true);
      async.flushMicrotasks();
      AppHaptics.success();
      AppHaptics.warning();
      AppHaptics.error();
      async.flushMicrotasks();
      expect(probes, 1);
      expect(effects, [
        HapticsType.selection,
        HapticsType.light,
        HapticsType.medium,
        HapticsType.success,
        HapticsType.warning,
        HapticsType.error,
      ]);
    });
  });

  test('Android checks touch feedback again after it is toggled', () async {
    const settings = MethodChannel('iris/haptics');
    const plugin = MethodChannel('haptic_feedback');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    var enabled = false;
    var checks = 0;
    messenger.setMockMethodCallHandler(settings, (call) async {
      expect(call.method, 'touchFeedbackEnabled');
      checks++;
      return enabled;
    });
    messenger.setMockMethodCallHandler(plugin, (call) async {
      calls.add(call.method);
      return call.method == 'canVibrate' ? true : null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(settings, null);
      messenger.setMockMethodCallHandler(plugin, null);
    });

    AppHaptics.warning();
    AppHaptics.success();
    AppHaptics.error();
    await pumpEventQueue();
    expect(calls, ['canVibrate']);
    expect(checks, 3);

    enabled = true;
    AppHaptics.warning();
    await pumpEventQueue();
    expect(calls, ['canVibrate', 'warning']);
    expect(checks, 4);

    enabled = false;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    AppHaptics.error();
    await pumpEventQueue();
    expect(calls, ['canVibrate', 'warning', 'error']);
    expect(checks, 4);
  });

  test('caches lack of capability and refreshes for a new test backend', () {
    fakeAsync((async) {
      var probes = 0;
      final effects = <HapticsType>[];
      Future<void> vibrate(HapticsType type) async => effects.add(type);

      AppHaptics.debugOverride = (
        canVibrate: () async {
          probes++;
          return false;
        },
        vibrate: vibrate,
      );
      AppHaptics.selection();
      async.flushMicrotasks();
      AppHaptics.error();
      async.flushMicrotasks();
      expect(probes, 1);
      expect(effects, isEmpty);

      AppHaptics.debugOverride = (
        canVibrate: () async => true,
        vibrate: vibrate,
      );
      AppHaptics.light();
      async.flushMicrotasks();
      expect(effects, [HapticsType.light]);
    });
  });

  for (final failure in [
    MissingPluginException(),
    PlatformException(code: 'unavailable'),
  ]) {
    test('stays silent after ${failure.runtimeType} checking capability', () {
      fakeAsync((async) {
        var probes = 0;
        AppHaptics.debugOverride = (
          canVibrate: () async {
            probes++;
            throw failure;
          },
          vibrate: (_) async => fail('no vibration without capability'),
        );
        AppHaptics.light();
        async.flushMicrotasks();
        AppHaptics.error();
        async.flushMicrotasks();
        expect(probes, 1);
      });
    });

    test('stays silent after ${failure.runtimeType} playing feedback', () {
      fakeAsync((async) {
        var attempts = 0;
        AppHaptics.debugOverride = (
          canVibrate: () async => true,
          vibrate: (_) async {
            attempts++;
            throw failure;
          },
        );
        AppHaptics.light();
        async.flushMicrotasks();
        AppHaptics.error();
        async.flushMicrotasks();
        expect(attempts, 1);
      });
    });
  }
}
