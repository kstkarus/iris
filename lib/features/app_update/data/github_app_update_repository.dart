import 'dart:ffi' show Abi;

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

/// Which file of a release is this build's, by the name the release
/// workflow gives it.
final class AppBuildTarget {
  /// `iris-1.2.3-android-arm64-v8a.apk`: the APK for one ABI. A build
  /// installed from the universal APK is offered its own ABI's next time.
  AppBuildTarget.android(String abi) : _suffix = '-android-$abi.apk';

  /// `iris-1.2.3-windows-x64.zip`
  const AppBuildTarget.windows() : _suffix = '-windows-x64.zip';

  final String _suffix;

  bool matches(String assetName) => assetName.toLowerCase().endsWith(_suffix);

  /// The ABI as a release's APK names it, or null for one it has no APK for.
  static String? androidAbiName(Abi abi) => switch (abi) {
    Abi.androidArm64 => 'arm64-v8a',
    Abi.androidArm => 'armeabi-v7a',
    Abi.androidX64 => 'x86_64',
    _ => null,
  };
}

/// Reads the latest GitHub release. GitHub leaves drafts and pre-releases
/// out of "latest", so only a published release is offered.
class GitHubAppUpdateRepository implements AppUpdateRepository {
  GitHubAppUpdateRepository({
    required Dio dio,
    required SharedPreferences preferences,
    required AppBuildTarget target,
    Future<String> Function()? installed,
  }) : _dio = dio,
       _preferences = preferences,
       _target = target,
       _installed = installed ?? _packageVersion;

  static const _dismissedKey = 'app_update.dismissed';

  final Dio _dio;
  final SharedPreferences _preferences;
  final AppBuildTarget _target;
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
      final name = jsonString(fields['name']);
      if (url != null &&
          url.scheme == 'https' &&
          url.host.isNotEmpty &&
          _target.matches(name)) {
        final digest = jsonString(fields['digest']);
        final sha256 = RegExp(
          r'^sha256:([0-9a-fA-F]{64})$',
        ).firstMatch(digest)?.group(1)?.toLowerCase();
        return AppRelease(
          version: version,
          downloadUrl: url,
          notes: jsonString(release['body']),
          sizeBytes: jsonInt(fields['size']),
          sha256: sha256,
          assetName: name,
        );
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
