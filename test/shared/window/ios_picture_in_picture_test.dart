import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris/shared/window/ios_picture_in_picture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(IOSPictureInPicture.channelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late IOSPictureInPicture window;

  Future<void> event(String method, Object? args) =>
      messenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(MethodCall(method, args)),
        (_) {},
      );

  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'isSupported' || 'attachPlayer' || 'enter' => true,
        _ => null,
      };
    });
    window = IOSPictureInPicture();
  });
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('iOS before 15 has no native PiP channel', () async {
    messenger.setMockMethodCallHandler(channel, null);
    expect(await window.isSupported(), isFalse);
    expect(await window.enter(), isFalse);
  });

  test('an event without an attached player cannot activate PiP', () async {
    await event('modeChanged', {'active': true});
    expect(window.active.value, isFalse);
  });

  test('binds the existing native player and reports its timeline', () async {
    expect(await window.isSupported(), isTrue);
    expect(await window.attachPlayer(42), isTrue);
    await window.setPlayer(
      playing: true,
      aspectRatio: 16 / 9,
      playLabel: 'Play',
      pauseLabel: 'Pause',
    );
    await window.setPlayback(
      position: const Duration(seconds: 24),
      duration: const Duration(minutes: 24),
      rate: 1.5,
    );
    expect(await window.enter(), isTrue);
    await window.completeSeek(8);
    expect(calls.map((call) => call.method), [
      'isSupported',
      'attachPlayer',
      'setPlayer',
      'setPlayback',
      'enter',
      'seekCompleted',
    ]);
    expect(calls[3].arguments, {
      'handle': '42',
      'position': 24000,
      'duration': 1440000,
      'rate': 1.5,
    });
    await window.clearPlayer();
    expect(calls.last.arguments, {'handle': '42'});
  });

  test(
    'restore and close differ; stale and malformed events are ignored',
    () async {
      await window.attachPlayer(42);
      var dismissals = 0;
      final playing = <bool>[];
      final seeks = <({int id, Duration interval})>[];
      final subscriptions = [
        window.dismissed.listen((_) => dismissals++),
        window.playingRequested.listen(playing.add),
        window.seekRequested.listen(seeks.add),
      ];
      await event('modeChanged', {'handle': '42', 'active': true});
      expect(window.active.value, isTrue);
      await event('modeChanged', {'handle': '42', 'active': false});
      expect(window.active.value, isFalse);
      expect(dismissals, 0);
      await event('setPlaying', {'handle': '42', 'playing': false});
      await event('seek', {'handle': '42', 'id': 8, 'milliseconds': -10000});
      await event('seek', {'handle': '42', 'id': 'bad', 'milliseconds': 10000});
      await event('modeChanged', null);
      await window.attachPlayer(43);
      await event('modeChanged', {
        'handle': '42',
        'active': true,
        'dismissed': true,
      });
      await event('setPlaying', {'handle': '42', 'playing': true});
      await event('seek', {'handle': '42', 'id': 9, 'milliseconds': 10000});
      await event('modeChanged', {
        'handle': '43',
        'active': false,
        'dismissed': true,
      });
      await Future<void>.delayed(Duration.zero);
      expect(playing, [false]);
      expect(seeks, [(id: 8, interval: const Duration(seconds: -10))]);
      expect(dismissals, 1);
      expect(window.active.value, isFalse);
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );

  test('clearing during entry rejects late success and events', () async {
    final entering = Completer<bool>();
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'enter' ? entering.future : true,
    );
    await window.attachPlayer(42);
    final result = window.enter();
    await window.clearPlayer();
    entering.complete(true);
    expect(await result, isFalse);
    await event('modeChanged', {'handle': '42', 'active': true});
    expect(window.active.value, isFalse);
  });

  test('a refused attachment cannot open PiP', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => false);
    expect(await window.attachPlayer(42), isFalse);
    expect(await window.enter(), isFalse);
  });
}
