import 'dart:developer' as developer;
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

abstract interface class DownloadForegroundServiceAdapter {
  Future<void> start({required String text});

  Future<void> update({required String text});

  Future<void> stop();
}

class MethodChannelDownloadForegroundServiceAdapter
    implements DownloadForegroundServiceAdapter {
  /// [localizations] defaults to the system language, which the app's UI
  /// follows too.
  const MethodChannelDownloadForegroundServiceAdapter({
    this.owner = 'downloads',
    AppLocalizations Function() localizations = _systemLocalizations,
  }) : _localizations = localizations;

  static const _channel = MethodChannel('iris/download_service');

  final AppLocalizations Function() _localizations;
  final String owner;

  @override
  Future<void> start({required String text}) => _invoke('start', text: text);

  @override
  Future<void> stop() => _invoke('stop');

  @override
  Future<void> update({required String text}) => _invoke('update', text: text);

  Future<void> _invoke(String method, {String? text}) async {
    final l10n = _localizations();
    try {
      await _channel.invokeMethod<void>(method, {
        'owner': owner,
        'title': owner == 'app_update'
            ? l10n.appUpdateNotificationTitle
            : l10n.downloadNotificationTitle,
        'text': ?text,
        'channelName': l10n.downloadNotificationChannelName,
        'channelDescription': l10n.downloadNotificationChannelDescription,
      });
    } catch (error, stackTrace) {
      developer.log(
        'Download foreground service command failed.',
        name: 'iris.downloads.foreground_service',
        error: error,
        stackTrace: stackTrace,
      );
      if (owner == 'app_update') rethrow;
    }
  }
}

AppLocalizations _systemLocalizations() => lookupAppLocalizations(
  basicLocaleListResolution(
    PlatformDispatcher.instance.locales,
    AppLocalizations.supportedLocales,
  ),
);

class NoopDownloadForegroundServiceAdapter
    implements DownloadForegroundServiceAdapter {
  const NoopDownloadForegroundServiceAdapter();

  @override
  Future<void> start({required String text}) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> update({required String text}) async {}
}
