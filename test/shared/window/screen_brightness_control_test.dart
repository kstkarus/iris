import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris/shared/window/screen_brightness_control.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('github.com/aaassseee/screen_brightness');
  const control = PluginScreenBrightnessControl();
  late double platformBrightness;
  late List<MethodCall> calls;

  setUp(() {
    platformBrightness = 0.5;
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'getApplicationScreenBrightness':
              return platformBrightness;
            case 'setApplicationScreenBrightness':
              platformBrightness =
                  (call.arguments as Map)['brightness'] as double;
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test('HLG maps and restores the slider on $platform', () async {
      debugDefaultTargetPlatformOverride = platform;
      final values = {
        0.0: 0.0,
        0.25: 1 / 48,
        0.5: 1 / 12,
        0.75: 0.26496256,
        1.0: 1.0,
      };

      for (final entry in values.entries) {
        await control.set(entry.key);
        expect(platformBrightness, closeTo(entry.value, 0.000001));
        expect(await control.current(), closeTo(entry.key, 0.000001));
      }

      var previous = -1.0;
      for (var i = 0; i <= 100; i++) {
        final slider = i / 100;
        await control.set(slider);
        expect(platformBrightness, greaterThan(previous));
        expect(await control.current(), closeTo(slider, 0.000001));
        previous = platformBrightness;
      }

      await control.set(-1);
      expect(platformBrightness, 0);
      await control.set(2);
      expect(platformBrightness, 1);
      await control.reset();
      expect(calls.last.method, 'resetApplicationScreenBrightness');
    });
  }

  test('iOS disables the plugin animation before reading brightness', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await control.current();

    expect(calls.map((call) => call.method), [
      'setAnimate',
      'getApplicationScreenBrightness',
    ]);
    expect(calls.first.arguments, {'isAnimate': false});
  });
}
