import 'dart:developer' as developer;

import 'package:flutter/services.dart';

abstract interface class DownloadForegroundServiceAdapter {
  Future<void> start({required String title, required String text});

  Future<void> update({required String title, required String text});

  Future<void> stop();
}

class MethodChannelDownloadForegroundServiceAdapter
    implements DownloadForegroundServiceAdapter {
  const MethodChannelDownloadForegroundServiceAdapter();

  static const _channel = MethodChannel('iris/download_service');

  @override
  Future<void> start({required String title, required String text}) {
    return _invoke('start', title: title, text: text);
  }

  @override
  Future<void> stop() => _invoke('stop');

  @override
  Future<void> update({required String title, required String text}) {
    return _invoke('update', title: title, text: text);
  }

  Future<void> _invoke(String method, {String? title, String? text}) async {
    try {
      await _channel.invokeMethod<void>(method, {
        'title': ?title,
        'text': ?text,
      });
    } catch (error, stackTrace) {
      developer.log(
        'Download foreground service command failed.',
        name: 'iris.downloads.foreground_service',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

class NoopDownloadForegroundServiceAdapter
    implements DownloadForegroundServiceAdapter {
  const NoopDownloadForegroundServiceAdapter();

  @override
  Future<void> start({required String title, required String text}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> update({required String title, required String text}) async {}
}
