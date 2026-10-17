import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:iris/features/app_update/data/repositories/android_app_update_download_repository.dart';
import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/shared/platform/download_foreground_service_adapter.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const installerChannel = MethodChannel('iris/app_update');

  late Directory support;
  late _ForegroundService foregroundService;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('iris-update-test-');
    foregroundService = _ForegroundService();
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(installerChannel, null);
    if (await support.exists()) await support.delete(recursive: true);
  });

  AndroidAppUpdateDownloadRepository repository(
    Dio dio, {
    TargetPlatform platform = TargetPlatform.android,
  }) => AndroidAppUpdateDownloadRepository(
    dio: dio,
    foregroundService: foregroundService,
    supportDirectory: () async => support,
    platform: platform,
  );

  test('downloads, verifies, and restores a durable APK', () async {
    final bytes = utf8.encode('apk payload');
    final adapter = FakeHttpAdapter((_) => FakeReply.text(200, 'apk payload'));
    final updates = repository(Dio()..httpClientAdapter = adapter);
    final release = _release(bytes);
    final progress = <(int, int)>[];

    final downloaded = await updates.download(
      release,
      onProgress: (received, total) => progress.add((received, total)),
    );

    expect(await File(downloaded).readAsBytes(), bytes);
    expect(path.basename(downloaded), 'iris-1.4.0-${release.sha256}.apk');
    expect(progress, [(bytes.length, bytes.length)]);
    expect(foregroundService.starts, 1);
    expect(foregroundService.stops, 1);
    expect(await updates.restore(release), downloaded);
  });

  test(
    'rejects a truncated or hash-mismatched APK and removes the part',
    () async {
      final expected = utf8.encode('the expected complete APK');
      final adapter = FakeHttpAdapter((_) => FakeReply.text(200, 'short file'));
      final updates = repository(Dio()..httpClientAdapter = adapter);
      final release = _release(expected);

      await expectLater(
        updates.download(release, onProgress: (_, _) {}),
        throwsA(
          isA<AppUpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            AppUpdateFailureKind.invalidFile,
          ),
        ),
      );
      expect(
        await Directory(path.join(support.path, 'app_updates')).list().toList(),
        isEmpty,
      );
    },
  );

  test('maps a file write failure to storage failure', () async {
    final bytes = utf8.encode('apk payload');
    final adapter = FakeHttpAdapter((_) => FakeReply.text(200, 'apk payload'));
    final updates = repository(Dio()..httpClientAdapter = adapter);
    final release = _release(bytes);
    final directory = Directory(path.join(support.path, 'app_updates'));
    await directory.create(recursive: true);
    final destination = path.join(
      directory.path,
      'iris-${release.version}-${release.sha256}.apk',
    );
    await Directory('$destination.part').create();

    await expectLater(
      updates.download(release, onProgress: (_, _) {}),
      throwsA(
        isA<AppUpdateFailure>().having(
          (failure) => failure.kind,
          'kind',
          AppUpdateFailureKind.storage,
        ),
      ),
    );
  });

  test('rejects same-sized content with the wrong SHA-256', () async {
    const expectedText = 'the expected complete APK';
    const changedText = 'the expected complete BAD';
    expect(
      utf8.encode(changedText),
      hasLength(utf8.encode(expectedText).length),
    );
    final adapter = FakeHttpAdapter((_) => FakeReply.text(200, changedText));
    final updates = repository(Dio()..httpClientAdapter = adapter);
    final release = _release(utf8.encode(expectedText));

    await expectLater(
      updates.download(release, onProgress: (_, _) {}),
      throwsA(
        isA<AppUpdateFailure>().having(
          (failure) => failure.kind,
          'kind',
          AppUpdateFailureKind.invalidFile,
        ),
      ),
    );
  });

  test('cancel deletes the partial file and a retry succeeds', () async {
    final bytes = utf8.encode('apk payload');
    final adapter = FakeHttpAdapter((_) => FakeReply.text(200, 'apk payload'));
    final updates = repository(Dio()..httpClientAdapter = adapter);
    final release = _release(bytes);
    var cancelled = false;

    await expectLater(
      updates.download(
        release,
        onProgress: (_, _) {
          if (cancelled) return;
          cancelled = true;
          unawaited(updates.cancel());
        },
      ),
      throwsA(
        isA<AppUpdateFailure>().having(
          (failure) => failure.kind,
          'kind',
          AppUpdateFailureKind.cancelled,
        ),
      ),
    );
    expect(
      await Directory(path.join(support.path, 'app_updates')).list().toList(),
      isEmpty,
    );

    final downloaded = await updates.download(release, onProgress: (_, _) {});
    expect(await File(downloaded).exists(), isTrue);
  });

  test(
    'restore removes a file whose digest does not match the release',
    () async {
      final release = _release(utf8.encode('expected content'));
      final directory = Directory(path.join(support.path, 'app_updates'));
      await directory.create(recursive: true);
      final file = File(
        path.join(
          directory.path,
          'iris-${release.version}-${release.sha256}.apk',
        ),
      );
      await file.writeAsString('changed content');

      final restored = await repository(Dio()).restore(release);

      expect(restored, isNull);
      expect(await file.exists(), isFalse);
    },
  );

  test('restore prunes only old app update APKs and partial files', () async {
    final bytes = utf8.encode('current update');
    final release = _release(bytes);
    final directory = Directory(path.join(support.path, 'app_updates'));
    await directory.create(recursive: true);
    final current = File(
      path.join(
        directory.path,
        'iris-${release.version}-${release.sha256}.apk',
      ),
    );
    await current.writeAsBytes(bytes);
    final old = File(path.join(directory.path, 'iris-1.3.0-${'b' * 64}.apk'));
    final oldPart = File('${old.path}.part');
    await old.writeAsString('old');
    await oldPart.writeAsString('old partial');
    final unrelated = File(path.join(directory.path, 'notes.txt'));
    await unrelated.writeAsString('keep');

    expect(await repository(Dio()).restore(release), current.path);

    expect(await current.exists(), isTrue);
    expect(await old.exists(), isFalse);
    expect(await oldPart.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
  });

  test(
    'restore waits for an in-flight download before inspecting its APK',
    () async {
      final requestStarted = Completer<void>();
      final response = Completer<FakeReply>();
      final adapter = FakeHttpAdapter((_) {
        requestStarted.complete();
        return response.future;
      });
      final updates = repository(Dio()..httpClientAdapter = adapter);
      final release = _release(utf8.encode('apk payload'));
      final download = updates.download(release, onProgress: (_, _) {});
      await requestStarted.future;
      final restore = updates.restore(release);

      response.complete(FakeReply.text(200, 'apk payload'));

      expect(await restore, await download);
    },
  );

  test(
    'stale restore of an older release keeps the newer verified APK',
    () async {
      final latestBytes = utf8.encode('new apk payload');
      final updates = repository(
        Dio()
          ..httpClientAdapter = FakeHttpAdapter(
            (_) => FakeReply.text(200, 'new apk payload'),
          ),
      );
      final latest = AppRelease(
        version: const AppVersion(1, 4, 0),
        downloadUrl: Uri.parse('https://example.org/latest.apk'),
        sizeBytes: latestBytes.length,
        sha256: sha256.convert(latestBytes).toString(),
      );
      final olderBytes = utf8.encode('old apk payload');
      final older = AppRelease(
        version: const AppVersion(1, 3, 0),
        downloadUrl: Uri.parse('https://example.org/older.apk'),
        sizeBytes: olderBytes.length,
        sha256: sha256.convert(olderBytes).toString(),
      );

      final downloaded = await updates.download(latest, onProgress: (_, _) {});

      expect(await updates.restore(older), isNull);
      expect(await File(downloaded).exists(), isTrue);
      expect(await updates.restore(latest), downloaded);
    },
  );

  test(
    'installer methods use the native channel and scoped APK path',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(installerChannel, (call) async {
            calls.add(call);
            return call.method == 'canInstall' ? true : null;
          });
      final updates = repository(Dio());
      final apk = File(path.join(support.path, 'app_updates', 'ready.apk'));
      await apk.parent.create(recursive: true);
      await apk.writeAsString('apk');

      expect(await updates.canInstall(), isTrue);
      await updates.openInstallPermissionSettings();
      await updates.install(apk.path);

      expect(calls.map((call) => call.method), [
        'canInstall',
        'openInstallPermissionSettings',
        'install',
      ]);
      expect(calls.last.arguments, {'path': path.canonicalize(apk.path)});
    },
  );

  test('maps native APK validation and permission failures', () async {
    var errorCode = 'invalid_apk';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(installerChannel, (call) async {
          if (call.method == 'install') {
            throw PlatformException(code: errorCode);
          }
          return null;
        });
    final updates = repository(Dio());
    final apk = File(path.join(support.path, 'app_updates', 'ready.apk'));
    await apk.parent.create(recursive: true);
    await apk.writeAsString('apk');

    await expectLater(
      updates.install(apk.path),
      throwsA(
        isA<AppUpdateFailure>().having(
          (failure) => failure.kind,
          'kind',
          AppUpdateFailureKind.invalidFile,
        ),
      ),
    );
    errorCode = 'install_permission_required';
    await expectLater(
      updates.install(apk.path),
      throwsA(
        isA<AppUpdateFailure>().having(
          (failure) => failure.kind,
          'kind',
          AppUpdateFailureKind.permission,
        ),
      ),
    );
  });

  test('does not offer installer permission checks off Android', () async {
    final updates = repository(Dio(), platform: TargetPlatform.windows);

    expect(await updates.canInstall(), isFalse);
    await expectLater(
      updates.install('C:/outside/update.apk'),
      throwsA(isA<AppUpdateFailure>()),
    );
  });
}

AppRelease _release(List<int> bytes) => AppRelease(
  version: const AppVersion(1, 4, 0),
  downloadUrl: Uri.parse(
    'https://example.org/iris-1.4.0-android-arm64-v8a.apk',
  ),
  sizeBytes: bytes.length,
  sha256: sha256.convert(bytes).toString(),
  assetName: 'iris-1.4.0-android-arm64-v8a.apk',
);

class _ForegroundService implements DownloadForegroundServiceAdapter {
  int starts = 0;
  int stops = 0;

  @override
  Future<void> start({required String text}) async {
    starts++;
  }

  @override
  Future<void> update({required String text}) async {}

  @override
  Future<void> stop() async {
    stops++;
  }
}
