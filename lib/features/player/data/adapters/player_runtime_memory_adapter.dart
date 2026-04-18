import 'dart:developer' as developer;

import 'package:flutter/services.dart';

const playerRuntimeMemoryChannelName = 'iris/player_runtime_stats';

abstract interface class PlayerRuntimeMemoryAdapter {
  Future<int?> getAppMemoryBytes();
}

class MethodChannelPlayerRuntimeMemoryAdapter
    implements PlayerRuntimeMemoryAdapter {
  const MethodChannelPlayerRuntimeMemoryAdapter();

  static const MethodChannel _channel = MethodChannel(
    playerRuntimeMemoryChannelName,
  );

  @override
  Future<int?> getAppMemoryBytes() async {
    try {
      return await _channel.invokeMethod<int>('getAppMemoryBytes');
    } catch (error, stackTrace) {
      developer.log(
        'Failed to read app memory usage from the native runtime channel.',
        name: 'iris.player.runtime_stats',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
