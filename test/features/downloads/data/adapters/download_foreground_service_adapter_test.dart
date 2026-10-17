import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/platform/download_foreground_service_adapter.dart';
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
      'owner': 'downloads',
      'title': 'Downloading',
      'text': 'Episode 1.mkv',
      'channelName': 'Downloads',
      'channelDescription': 'Download progress for episodes and app updates',
    });
  });

  test(
    'update owner is preserved and service errors reach the downloader',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'start') {
              throw PlatformException(code: 'unavailable');
            }
            return null;
          });
      final adapter = MethodChannelDownloadForegroundServiceAdapter(
        owner: 'app_update',
        localizations: () => lookupAppLocalizations(const Locale('en')),
      );
      await expectLater(
        adapter.start(text: '1.4.5'),
        throwsA(isA<PlatformException>()),
      );
      await adapter.stop();
      expect(
        calls.map((call) => call.arguments['owner']),
        everyElement('app_update'),
      );
      expect(calls.first.arguments['title'], 'Iris update');
    },
  );
}
