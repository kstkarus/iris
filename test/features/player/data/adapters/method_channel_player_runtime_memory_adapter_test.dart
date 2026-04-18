import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/adapters/player_runtime_memory_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(playerRuntimeMemoryChannelName);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('returns app memory bytes from the method channel', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'getAppMemoryBytes');
          return 268435456;
        });

    final adapter = const MethodChannelPlayerRuntimeMemoryAdapter();

    expect(await adapter.getAppMemoryBytes(), 268435456);
  });

  test('returns null when the native channel throws', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw PlatformException(code: 'unavailable');
        });

    final adapter = const MethodChannelPlayerRuntimeMemoryAdapter();

    expect(await adapter.getAppMemoryBytes(), isNull);
  });
}
