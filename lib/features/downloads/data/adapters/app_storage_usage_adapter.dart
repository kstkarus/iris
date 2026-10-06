import 'dart:developer' as developer;

import 'package:flutter/services.dart';

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
        appBytes: _readInt(result['appBytes']),
        dataBytes: _readInt(result['dataBytes']),
        cacheBytes: _readInt(result['cacheBytes']),
        totalBytes: _readInt(result['totalBytes']),
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

int _readInt(Object? value) => value is int ? value : 0;
