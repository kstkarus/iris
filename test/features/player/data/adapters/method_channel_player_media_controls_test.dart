import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/player/data/adapters/method_channel_player_media_controls.dart';
import 'package:iris/features/player/domain/player_media_controls.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = binding.defaultBinaryMessenger;
  const channel = MethodChannel('iris/player_media_controls');

  test(
    'sends the system clock and routes commands only to the active session',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      final old = MethodChannelPlayerMediaControls();
      final current = MethodChannelPlayerMediaControls();
      addTearDown(current.deactivate);
      addTearDown(old.deactivate);
      final commands =
          <({String player, PlayerMediaCommand command, Duration? position})>[];

      Future<int> publish(
        MethodChannelPlayerMediaControls controls,
        String player, {
        bool buffering = false,
      }) async {
        await controls.update(
          titles: (title: player, episode: 'Episode 3'),
          playback: (
            position: const Duration(milliseconds: 750),
            duration: const Duration(minutes: 5),
            playing: true,
            buffering: buffering,
            rate: 1.25,
          ),
          canNext: true,
          onCommand: (command, position) async {
            commands.add((
              player: player,
              command: command,
              position: position,
            ));
          },
        );
        return calls.last.arguments['session'] as int;
      }

      Future<void> receive(String method, int id, [int? milliseconds]) =>
          messenger.handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(
              MethodCall(method, {'session': id, 'positionMs': milliseconds}),
            ),
            (_) {},
          );

      final first = await publish(old, 'First');
      expect(calls.single.method, 'update');
      expect(calls.single.arguments, {
        'session': first,
        'title': 'First',
        'episode': 'Episode 3',
        'canNext': true,
        'playing': true,
        'buffering': false,
        'positionMs': 750,
        'durationMs': 300000,
        'rate': 1.25,
      });
      final second = await publish(current, 'Second', buffering: true);
      expect(calls.last.arguments['buffering'], isTrue);
      await old.deactivate();
      expect(calls, hasLength(2));

      await receive('play', first);
      await receive('unknown', second);
      await receive('pause', second);
      await receive('seekTo', second, 8000);
      await receive('pauseImmediately', second);
      expect(commands, [
        (player: 'Second', command: PlayerMediaCommand.pause, position: null),
        (
          player: 'Second',
          command: PlayerMediaCommand.seekTo,
          position: const Duration(seconds: 8),
        ),
        (
          player: 'Second',
          command: PlayerMediaCommand.pauseImmediately,
          position: null,
        ),
      ]);

      await current.deactivate();
      expect(calls.last.method, 'deactivate');
      expect(calls.last.arguments, {'session': second});
      await receive('pause', second);
      expect(commands, hasLength(3));
    },
  );
}
