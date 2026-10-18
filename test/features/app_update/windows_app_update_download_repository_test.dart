import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:iris/features/app_update/data/repositories/windows_app_update_download_repository.dart';
import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';

import '../../helpers/fake_http_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const installerChannel = MethodChannel('iris/app_update');

  late Directory support;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() async {
    support = await Directory.systemTemp.createTemp('iris-update-windows-');
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(installerChannel, null);
    if (await support.exists()) await support.delete(recursive: true);
  });

  WindowsAppUpdateDownloadRepository repository(
    Dio dio, {
    TargetPlatform platform = TargetPlatform.windows,
    Future<void> Function()? prepareForRestart,
  }) => WindowsAppUpdateDownloadRepository(
    dio: dio,
    prepareForRestart: prepareForRestart ?? () async {},
    supportDirectory: () async => support,
    platform: platform,
  );

  test('downloads and restores the verified Windows executable', () async {
    final bytes = utf8.encode('setup payload');
    final adapter = FakeHttpAdapter(
      (_) => FakeReply.text(200, 'setup payload'),
    );
    final updates = repository(Dio()..httpClientAdapter = adapter);
    final release = _release(bytes);
    final downloaded = await updates.download(release, onProgress: (_, _) {});

    expect(path.basename(downloaded), 'iris-1.4.0-${release.sha256}.exe');
    expect(await File(downloaded).readAsBytes(), bytes);
    expect(await repository(Dio()).restore(release), downloaded);
  });

  test(
    'rejects HTTP and mismatched executable bytes, cleaning partial files',
    () async {
      final bytes = utf8.encode('expected setup');
      var body = 'short setup';
      final adapter = FakeHttpAdapter((_) => FakeReply.text(200, body));
      final updates = repository(Dio()..httpClientAdapter = adapter);
      final release = _release(bytes);

      await expectLater(
        updates.download(
          AppRelease(
            version: release.version,
            downloadUrl: Uri.parse('http://example.org/setup.exe'),
            sizeBytes: release.sizeBytes,
            sha256: release.sha256,
          ),
          onProgress: (_, _) {},
        ),
        throwsA(isA<AppUpdateFailure>()),
      );
      expect(adapter.requests, isEmpty);

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

      body = 'expected steup';
      expect(utf8.encode(body), hasLength(bytes.length));
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

  test('cancels and removes the partial executable before retry', () async {
    final updates = repository(
      Dio()
        ..httpClientAdapter = FakeHttpAdapter(
          (_) => FakeReply.text(200, 'setup payload'),
        ),
    );
    final release = _release(utf8.encode('setup payload'));
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
    expect(await updates.download(release, onProgress: (_, _) {}), isNotEmpty);
  });

  test(
    'flushes state, launches setup, and exits only after launch succeeds',
    () async {
      final events = <String>[];
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(installerChannel, (call) async {
        events.add(call.method);
        calls.add(call);
        return switch (call.method) {
          'installationDirectory' => r'C:\Program Files\Iris',
          'install' => true,
          _ => null,
        };
      });
      final downloader = repository(
        Dio()
          ..httpClientAdapter = FakeHttpAdapter(
            (_) => FakeReply.text(200, 'setup payload'),
          ),
      );
      final updates = repository(
        Dio(),
        prepareForRestart: () async => events.add('flush'),
      );
      final release = _release(utf8.encode('setup payload'));
      final downloaded = await downloader.download(
        release,
        onProgress: (_, _) {},
      );
      expect(await updates.restore(release), downloaded);

      expect(await updates.canInstall(), isTrue);
      events.clear();
      await updates.install(downloaded);

      expect(events, ['installationDirectory', 'flush', 'install', 'exit']);
      expect(calls.firstWhere((call) => call.method == 'install').arguments, {
        'path': path.canonicalize(downloaded),
      });
    },
  );

  test(
    'refuses changed or outside-cache files before flushing state',
    () async {
      final events = <String>[];
      messenger.setMockMethodCallHandler(installerChannel, (call) async {
        events.add(call.method);
        return r'C:\Program Files\Iris';
      });
      final updates = repository(
        Dio()
          ..httpClientAdapter = FakeHttpAdapter(
            (_) => FakeReply.text(200, 'setup payload'),
          ),
        prepareForRestart: () async => events.add('flush'),
      );
      final release = _release(utf8.encode('setup payload'));
      final downloaded = await updates.download(release, onProgress: (_, _) {});
      await File(downloaded).writeAsString('edited setup');

      await expectLater(
        updates.install(downloaded),
        throwsA(isA<AppUpdateFailure>()),
      );
      final outside = File(path.join(support.path, 'outside.exe'));
      await outside.writeAsString('setup payload');
      await expectLater(
        updates.install(outside.path),
        throwsA(isA<AppUpdateFailure>()),
      );
      expect(events, isEmpty);
    },
  );

  test('portable installs do not flush, launch, or exit', () async {
    final events = <String>[];
    messenger.setMockMethodCallHandler(installerChannel, (call) async {
      events.add(call.method);
      return null;
    });
    final updates = repository(
      Dio()
        ..httpClientAdapter = FakeHttpAdapter(
          (_) => FakeReply.text(200, 'setup payload'),
        ),
      prepareForRestart: () async => events.add('flush'),
    );
    final release = _release(utf8.encode('setup payload'));
    final downloaded = await updates.download(release, onProgress: (_, _) {});

    expect(await updates.canInstall(), isFalse);
    await expectLater(
      updates.openInstallPermissionSettings(),
      throwsA(
        isA<AppUpdateFailure>().having(
          (failure) => failure.kind,
          'kind',
          AppUpdateFailureKind.install,
        ),
      ),
    );
    await expectLater(
      updates.install(downloaded),
      throwsA(
        isA<AppUpdateFailure>().having(
          (failure) => failure.kind,
          'kind',
          AppUpdateFailureKind.install,
        ),
      ),
    );
    expect(events, ['installationDirectory', 'installationDirectory']);
  });

  test('a failed setup launch never asks native code to exit Iris', () async {
    final events = <String>[];
    messenger.setMockMethodCallHandler(installerChannel, (call) async {
      events.add(call.method);
      if (call.method == 'installationDirectory') {
        return r'C:\Program Files\Iris';
      }
      if (call.method == 'install') {
        throw PlatformException(code: 'installer_start_failed');
      }
      return null;
    });
    final updates = repository(
      Dio()
        ..httpClientAdapter = FakeHttpAdapter(
          (_) => FakeReply.text(200, 'setup payload'),
        ),
      prepareForRestart: () async => events.add('flush'),
    );
    final release = _release(utf8.encode('setup payload'));
    final downloaded = await updates.download(release, onProgress: (_, _) {});

    await expectLater(
      updates.install(downloaded),
      throwsA(isA<AppUpdateFailure>()),
    );
    expect(events, ['installationDirectory', 'flush', 'install']);
  });

  test(
    'the Windows target guard rejects downloads on other platforms',
    () async {
      final adapter = FakeHttpAdapter(
        (_) => FakeReply.text(200, 'setup payload'),
      );
      final updates = repository(
        Dio()..httpClientAdapter = adapter,
        platform: TargetPlatform.android,
      );

      expect(await updates.canInstall(), isFalse);
      await expectLater(
        updates.download(
          _release(utf8.encode('setup payload')),
          onProgress: (_, _) {},
        ),
        throwsA(
          isA<AppUpdateFailure>().having(
            (failure) => failure.kind,
            'kind',
            AppUpdateFailureKind.install,
          ),
        ),
      );
      expect(adapter.requests, isEmpty);
    },
  );
}

AppRelease _release(List<int> bytes) => AppRelease(
  version: const AppVersion(1, 4, 0),
  downloadUrl: Uri.parse('https://example.org/iris-1.4.0-windows-x64.exe'),
  sizeBytes: bytes.length,
  sha256: sha256.convert(bytes).toString(),
  assetName: 'iris-1.4.0-windows-x64.exe',
);
