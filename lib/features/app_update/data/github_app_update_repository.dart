import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/utils/json_read.dart';

/// Where releases are published: the app's public GitHub repository, whose
/// release workflow attaches a build per platform.
abstract final class AppReleasesApi {
  static const baseUrl = 'https://api.github.com';
  static const latestPath = '/repos/kstkarus/iris/releases/latest';
}

/// The platforms a release carries a build for, and how its file is named
/// by the release workflow.
enum AppBuildPlatform {
  /// `iris-1.2.3-android.apk`
  android,

  /// `iris-1.2.3-windows-x64.zip`
  windows;

  bool matches(String assetName) {
    final name = assetName.toLowerCase();
    return switch (this) {
      android => name.endsWith('.apk'),
      windows => name.contains('windows') && name.endsWith('.zip'),
    };
  }
}

/// Reads the latest GitHub release. GitHub leaves drafts and pre-releases
/// out of "latest", so only a published release is offered.
class GitHubAppUpdateRepository implements AppUpdateRepository {
  GitHubAppUpdateRepository({
    required Dio dio,
    required SharedPreferences preferences,
    required AppBuildPlatform platform,
    Future<String> Function()? installed,
  }) : _dio = dio,
       _preferences = preferences,
       _platform = platform,
       _installed = installed ?? _packageVersion;

  static const _dismissedKey = 'app_update.dismissed';

  final Dio _dio;
  final SharedPreferences _preferences;
  final AppBuildPlatform _platform;
  final Future<String> Function() _installed;

  @override
  Future<AppRelease?> latestRelease() async {
    final Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(
        AppReleasesApi.latestPath,
        options: Options(
          headers: const {'Accept': 'application/vnd.github+json'},
        ),
      );
    } on DioException catch (error) {
      // Nothing published yet.
      if (error.response?.statusCode == 404) return null;
      throw mapDioException(error);
    }
    final release = jsonMap(response.data);
    final version = AppVersion.tryParse(jsonString(release['tag_name']));
    if (version == null) return null;
    final assets = release['assets'];
    if (assets is! List) return null;
    for (final asset in assets) {
      final fields = jsonMap(asset);
      final url = Uri.tryParse(jsonString(fields['browser_download_url']));
      if (url != null &&
          url.hasScheme &&
          _platform.matches(jsonString(fields['name']))) {
        return AppRelease(version: version, downloadUrl: url);
      }
    }
    return null;
  }

  @override
  Future<AppVersion?> installedVersion() async =>
      AppVersion.tryParse(await _installed());

  @override
  AppVersion? get dismissedVersion =>
      AppVersion.tryParse(_preferences.getString(_dismissedKey) ?? '');

  @override
  Future<void> dismiss(AppVersion version) =>
      _preferences.setString(_dismissedKey, '$version');

  static Future<String> _packageVersion() async =>
      (await PackageInfo.fromPlatform()).version;
}

/// For platforms a release has no build for, and the mock build.
class NoAppUpdateRepository implements AppUpdateRepository {
  const NoAppUpdateRepository();

  @override
  Future<AppRelease?> latestRelease() async => null;

  @override
  Future<AppVersion?> installedVersion() async => null;

  @override
  AppVersion? get dismissedVersion => null;

  @override
  Future<void> dismiss(AppVersion version) async {}
}
