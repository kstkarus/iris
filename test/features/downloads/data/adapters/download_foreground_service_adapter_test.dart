import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/adapters/download_foreground_service_adapter.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('iris/download_service');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('sends the notification texts in the app language', () async {
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    final adapter = MethodChannelDownloadForegroundServiceAdapter(
      localizations: () => lookupAppLocalizations(const Locale('en')),
    );

    await adapter.start(text: 'Episode 1.mkv');

    expect(calls.single.method, 'start');
    expect(calls.single.arguments, {
      'title': 'Downloading',
      'text': 'Episode 1.mkv',
      'channelName': 'Downloads',
      'channelDescription': 'Download progress for offline viewing',
    });
  });
}
