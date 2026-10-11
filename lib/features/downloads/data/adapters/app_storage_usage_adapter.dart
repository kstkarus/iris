import 'dart:developer' as developer;

import 'package:flutter/services.dart';

import 'package:iris/shared/utils/json_read.dart';

class AppStorageUsage {
  const AppStorageUsage({
    required this.appBytes,
    required this.dataBytes,
    required this.cacheBytes,
    required this.totalBytes,
  });

  final int appBytes;
  final int dataBytes;
  final int cacheBytes;
  final int totalBytes;
}

abstract interface class AppStorageUsageAdapter {
  Future<AppStorageUsage?> getUsage();
}

class MethodChannelAppStorageUsageAdapter implements AppStorageUsageAdapter {
  const MethodChannelAppStorageUsageAdapter();

  static const _channel = MethodChannel('iris/app_storage_stats');

  @override
  Future<AppStorageUsage?> getUsage() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'getUsage',
      );
      if (result == null) return null;
      return AppStorageUsage(
        appBytes: jsonInt(result['appBytes']),
        dataBytes: jsonInt(result['dataBytes']),
        cacheBytes: jsonInt(result['cacheBytes']),
        totalBytes: jsonInt(result['totalBytes']),
      );
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
