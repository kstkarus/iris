import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/window/picture_in_picture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel(AndroidPictureInPicture.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'isSupported' || 'enter' => true,
        _ => null,
      };
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  /// A call from the activity, as Kotlin's invokeMethod sends it.
  Future<void> fromActivity(String method, [Object? arguments]) =>
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );

  test('tells the activity what plays', () async {
    final window = AndroidPictureInPicture();

    expect(await window.isSupported(), isTrue);
    await window.setPlayer(
      playing: true,
      aspectRatio: 16 / 9,
      playLabel: 'Play',
      pauseLabel: 'Pause',
    );
    expect(await window.enter(), isTrue);
    await window.clearPlayer();

    expect(calls.map((call) => call.method), [
      'isSupported',
      'setPlayer',
      'enter',
      'clearPlayer',
    ]);
    expect(calls[1].arguments, {
      'playing': true,
      'aspectRatio': 16 / 9,
      'playLabel': 'Play',
      'pauseLabel': 'Pause',
    });
  });

  test(
    'Windows uses the shared player protocol and its window commands',
    () async {
      final window = WindowsPictureInPicture();

      expect(await window.isSupported(), isTrue);
      await window.setPlayer(
        playing: false,
        aspectRatio: 4 / 3,
        playLabel: 'Play',
        pauseLabel: 'Pause',
      );
      expect(await window.enter(), isTrue);
      await window.restore();
      await window.dismiss();
      await window.startDragging();
      await window.clearPlayer();

      expect(calls.map((call) => call.method), [
        'isSupported',
        'setPlayer',
        'enter',
        'restore',
        'dismiss',
        'startDragging',
        'clearPlayer',
      ]);
      expect(calls[1].arguments, {
        'playing': false,
        'aspectRatio': 4 / 3,
        'playLabel': 'Play',
        'pauseLabel': 'Pause',
      });

      var dismissals = 0;
      final subscription = window.dismissed.listen((_) => dismissals++);
      await fromActivity('modeChanged', {'active': true, 'dismissed': false});
      expect(window.active.value, isTrue);
      await fromActivity('modeChanged', {'active': false, 'dismissed': true});
      await Future<void>.delayed(Duration.zero);
      expect(window.active.value, isFalse);
      expect(dismissals, 1);
      await subscription.cancel();
    },
  );

  test('follows the mode, and tells a closed window from an expanded '
      'one', () async {
    final window = AndroidPictureInPicture();
    var dismissals = 0;
    final subscription = window.dismissed.listen((_) => dismissals++);

    await fromActivity('modeChanged', {'active': true, 'dismissed': false});
    expect(window.active.value, isTrue);

    await fromActivity('modeChanged', {'active': false, 'dismissed': false});
    expect(window.active.value, isFalse);
    expect(dismissals, 0);

    await fromActivity('modeChanged', {'active': false, 'dismissed': true});
    await Future<void>.delayed(Duration.zero);
    expect(dismissals, 1);
    await subscription.cancel();
  });

  test('passes on play/pause pressed in the window', () async {
    final window = AndroidPictureInPicture();
    final pressed = window.playPausePressed.first;

    await fromActivity('playPause');

    await expectLater(pressed, completes);
  });
}
