import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'package:iris/shared/utils/json_read.dart';

abstract interface class AppStorageUsageAdapter {
  /// What the app takes on the device in all; null where the platform does
  /// not tell.
  Future<int?> totalBytes();
}

class MethodChannelAppStorageUsageAdapter implements AppStorageUsageAdapter {
  const MethodChannelAppStorageUsageAdapter();

  static const _channel = MethodChannel('iris/app_storage_stats');

  @override
  Future<int?> totalBytes() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getUsage',
      );
      if (result == null) return null;
      return jsonInt(result['totalBytes']);
    } catch (error, stackTrace) {
      developer.log(
        'Unable to read Android app storage usage.',
        name: 'iris.downloads.storage',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
