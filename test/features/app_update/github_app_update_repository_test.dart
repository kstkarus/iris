import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/app_update/data/github_app_update_repository.dart';
import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';

import '../../helpers/fake_http_adapter.dart';

const _release = {
  'tag_name': 'v1.3.0',
  'assets': [
    {
      'name': 'iris-1.3.0-windows-x64.zip',
      'browser_download_url': 'https://example.org/iris-1.3.0-windows-x64.zip',
    },
    {
      'name': 'iris-1.3.0-android.apk',
      'browser_download_url': 'https://example.org/iris-1.3.0-android.apk',
    },
  ],
};

void main() {
  late FakeHttpAdapter adapter;

  Future<GitHubAppUpdateRepository> repository(
    FakeReply reply, {
    AppBuildPlatform platform = AppBuildPlatform.android,
  }) async {
    SharedPreferences.setMockInitialValues({});
    adapter = FakeHttpAdapter((_) => reply);
    return GitHubAppUpdateRepository(
      dio: Dio(BaseOptions(baseUrl: AppReleasesApi.baseUrl))
        ..httpClientAdapter = adapter,
      preferences: await SharedPreferences.getInstance(),
      platform: platform,
      installed: () async => '1.2.0',
    );
  }

  test('offers the build for this platform from the latest release', () async {
    final android = await repository(const FakeReply(200, _release));
    expect(
      await android.latestRelease(),
      AppRelease(
        version: const AppVersion(1, 3, 0),
        downloadUrl: Uri.parse('https://example.org/iris-1.3.0-android.apk'),
      ),
    );
    expect(adapter.requests.single.path, AppReleasesApi.latestPath);

    final windows = await repository(
      const FakeReply(200, _release),
      platform: AppBuildPlatform.windows,
    );
    expect(
      (await windows.latestRelease())?.downloadUrl.path,
      '/iris-1.3.0-windows-x64.zip',
    );
  });

  test('nothing published, or no build here, is no update', () async {
    final unpublished = await repository(const FakeReply(404));
    expect(await unpublished.latestRelease(), isNull);

    final noBuild = await repository(
      const FakeReply(200, {'tag_name': 'v1.3.0', 'assets': []}),
    );
    expect(await noBuild.latestRelease(), isNull);
  });

  test('reads the running version and keeps the one put off', () async {
    final updates = await repository(const FakeReply(200, _release));

    expect(await updates.installedVersion(), const AppVersion(1, 2, 0));
    expect(updates.dismissedVersion, isNull);
    await updates.dismiss(const AppVersion(1, 3, 0));
    expect(updates.dismissedVersion, const AppVersion(1, 3, 0));
  });
}
