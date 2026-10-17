import 'dart:ffi' show Abi;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/app_update/data/github_app_update_repository.dart';
import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';

import '../../helpers/fake_http_adapter.dart';

final _release = {
  'tag_name': 'v1.3.0',
  'body': 'Bug fixes and performance improvements.',
  'assets': [
    {
      'name': 'iris-1.3.0-windows-x64.zip',
      'browser_download_url': 'https://example.org/iris-1.3.0-windows-x64.zip',
    },
    for (final abi in ['arm64-v8a', 'armeabi-v7a', 'universal', 'x86_64'])
      {
        'name': 'iris-1.3.0-android-$abi.apk',
        'browser_download_url':
            'https://example.org/iris-1.3.0-android-$abi.apk',
        if (abi == 'arm64-v8a') ...{
          'size': 1024,
          'digest': 'sha256:${'a' * 64}',
        },
      },
  ],
};

void main() {
  late FakeHttpAdapter adapter;

  Future<GitHubAppUpdateRepository> repository(
    FakeReply reply, {
    AppBuildTarget? target,
  }) async {
    SharedPreferences.setMockInitialValues({});
    adapter = FakeHttpAdapter((_) => reply);
    return GitHubAppUpdateRepository(
      dio: Dio(BaseOptions(baseUrl: AppReleasesApi.baseUrl))
        ..httpClientAdapter = adapter,
      preferences: await SharedPreferences.getInstance(),
      target: target ?? AppBuildTarget.android('arm64-v8a'),
      installed: () async => '1.2.0',
    );
  }

  test('offers the build for this platform from the latest release', () async {
    final android = await repository(FakeReply(200, _release));
    final latest = await android.latestRelease();
    expect(
      latest,
      AppRelease(
        version: const AppVersion(1, 3, 0),
        downloadUrl: Uri.parse(
          'https://example.org/iris-1.3.0-android-arm64-v8a.apk',
        ),
        notes: 'Bug fixes and performance improvements.',
        sizeBytes: 1024,
        sha256: 'a' * 64,
        assetName: 'iris-1.3.0-android-arm64-v8a.apk',
      ),
    );
    expect(latest?.notes, 'Bug fixes and performance improvements.');
    expect(latest?.sizeBytes, 1024);
    expect(latest?.sha256, 'a' * 64);
    expect(latest?.assetName, 'iris-1.3.0-android-arm64-v8a.apk');
    expect(
      latest,
      isNot(
        AppRelease(
          version: const AppVersion(1, 3, 0),
          downloadUrl: Uri.parse(
            'https://example.org/iris-1.3.0-android-arm64-v8a.apk',
          ),
        ),
      ),
    );
    expect(adapter.requests.single.path, AppReleasesApi.latestPath);

    final arm = await repository(
      FakeReply(200, _release),
      target: AppBuildTarget.android('armeabi-v7a'),
    );
    expect(
      (await arm.latestRelease())?.downloadUrl.path,
      '/iris-1.3.0-android-armeabi-v7a.apk',
    );

    final windows = await repository(
      FakeReply(200, _release),
      target: const AppBuildTarget.windows(),
    );
    expect(
      (await windows.latestRelease())?.downloadUrl.path,
      '/iris-1.3.0-windows-x64.zip',
    );
  });

  test('names the APK of the ABI the app runs as', () {
    expect(AppBuildTarget.androidAbiName(Abi.androidArm64), 'arm64-v8a');
    expect(AppBuildTarget.androidAbiName(Abi.androidArm), 'armeabi-v7a');
    expect(AppBuildTarget.androidAbiName(Abi.androidX64), 'x86_64');
    expect(AppBuildTarget.androidAbiName(Abi.androidIA32), isNull);
  });

  test('a release from before the APKs per ABI is no update', () async {
    final old = await repository(
      const FakeReply(200, {
        'tag_name': 'v1.1.0',
        'assets': [
          {
            'name': 'iris-1.1.0-android.apk',
            'browser_download_url':
                'https://example.org/iris-1.1.0-android.apk',
          },
        ],
      }),
    );
    expect(await old.latestRelease(), isNull);
  });

  test(
    'accepts only HTTPS URLs and normalizes GitHub SHA-256 digests',
    () async {
      final insecure = await repository(
        FakeReply(200, {
          'tag_name': 'v1.3.0',
          'assets': [
            {
              'name': 'iris-1.3.0-android-arm64-v8a.apk',
              'browser_download_url': 'file:///tmp/update.apk',
              'digest': 'sha256:${'A' * 64}',
            },
          ],
        }),
      );
      expect(await insecure.latestRelease(), isNull);

      final secure = await repository(
        FakeReply(200, {
          'tag_name': 'v1.3.0',
          'assets': [
            {
              'name': 'iris-1.3.0-android-arm64-v8a.apk',
              'browser_download_url':
                  'https://example.org/iris-1.3.0-android-arm64-v8a.apk',
              'digest': 'sha256:${'A' * 64}',
            },
          ],
        }),
      );
      expect((await secure.latestRelease())?.sha256, 'a' * 64);
    },
  );

  test('nothing published, or no build here, is no update', () async {
    final unpublished = await repository(const FakeReply(404));
    expect(await unpublished.latestRelease(), isNull);

    final noBuild = await repository(
      const FakeReply(200, {'tag_name': 'v1.3.0', 'assets': []}),
    );
    expect(await noBuild.latestRelease(), isNull);
  });

  test('reads the running version and keeps the one put off', () async {
    final updates = await repository(FakeReply(200, _release));

    expect(await updates.installedVersion(), const AppVersion(1, 2, 0));
    expect(updates.dismissedVersion, isNull);
    await updates.dismiss(const AppVersion(1, 3, 0));
    expect(updates.dismissedVersion, const AppVersion(1, 3, 0));
  });
}
