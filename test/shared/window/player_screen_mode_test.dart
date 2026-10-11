import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/window/player_screen_mode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('a phone plays in landscape with the system bars hidden', () async {
    await const PhonePlayerScreenMode().enter();

    expect(calls.map((call) => '${call.method} ${call.arguments}'), [
      'SystemChrome.setPreferredOrientations '
          '[DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]',
      'SystemChrome.setEnabledSystemUIMode SystemUiMode.immersiveSticky',
    ]);
  });

  test('leaving gives back free rotation and edge-to-edge bars', () async {
    await const PhonePlayerScreenMode().leave();

    expect(calls.map((call) => '${call.method} ${call.arguments}'), [
      'SystemChrome.setPreferredOrientations []',
      'SystemChrome.setEnabledSystemUIMode SystemUiMode.edgeToEdge',
    ]);
  });

  test('desktop leaves the screen alone', () async {
    await const NoPlayerScreenMode().enter();
    await const NoPlayerScreenMode().leave();

    expect(calls, isEmpty);
  });
}
