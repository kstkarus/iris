import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_download_repository.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/platform/download_foreground_service_adapter.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/serial_queue.dart';

class AndroidAppUpdateDownloadRepository
    implements AppUpdateDownloadRepository {
  AndroidAppUpdateDownloadRepository({
    required Dio dio,
    required DownloadForegroundServiceAdapter foregroundService,
    Future<Directory> Function()? supportDirectory,
    MethodChannel installer = const MethodChannel('iris/app_update'),
    TargetPlatform? platform,
  }) : _dio = dio,
       _foregroundService = foregroundService,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _installer = installer,
       _platform = platform ?? defaultTargetPlatform;

  static final _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
  static final _ownedFilePattern = RegExp(
    r'^iris-(\d+\.\d+\.\d+)-[0-9a-f]{64}\.apk(?:\.part)?$',
  );

  final Dio _dio;
  final DownloadForegroundServiceAdapter _foregroundService;
  final Future<Directory> Function() _supportDirectory;
  final MethodChannel _installer;
  final TargetPlatform _platform;
  CancelToken? _activeToken;
  Future<String>? _activeDownload;
  final _fileOperations = SerialQueue();

  @override
  Future<String?> restore(AppRelease release) {
    final digest = _digest(release);
    if (digest == null) return Future.value(null);
    return _fileOperations.run(() => _restore(release, digest));
  }

  Future<String?> _restore(AppRelease release, String digest) async {
    try {
      final directory = await _updatesDirectory();
      final file = File(_filePath(directory, release, digest));
      if (await directory.exists()) {
        await _cleanupOtherUpdateFiles(directory, file, release.version);
      }
      if (!await file.exists()) return null;
      if (await _matchesFile(file, release, digest)) return file.path;
      await file.delete();
      return null;
    } on AppUpdateFailure {
      rethrow;
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.storage);
    }
  }

  @override
  Future<String> download(
    AppRelease release, {
    required void Function(int received, int total) onProgress,
  }) {
    if (_activeToken != null) {
      throw const AppUpdateFailure(AppUpdateFailureKind.storage);
    }
    final digest = _digest(release);
    if (digest == null ||
        release.sizeBytes < 0 ||
        release.downloadUrl.scheme != 'https' ||
        release.downloadUrl.host.isEmpty) {
      throw const AppUpdateFailure(AppUpdateFailureKind.invalidFile);
    }
    if (_platform != TargetPlatform.android) {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }

    final token = CancelToken();
    _activeToken = token;
    final task = _fileOperations.run(
      () => _download(release, digest, token, onProgress),
    );
    _activeDownload = task;
    return task.whenComplete(() {
      if (identical(_activeToken, token)) {
        _activeToken = null;
        _activeDownload = null;
      }
    });
  }

  Future<String> _download(
    AppRelease release,
    String digest,
    CancelToken token,
    void Function(int received, int total) onProgress,
  ) async {
    File? part;
    var serviceStarted = false;
    try {
      _throwIfCancelled(token);
      final directory = await _updatesDirectory();
      final destination = File(_filePath(directory, release, digest));
      if (await destination.exists()) {
        if (await _matchesFile(destination, release, digest)) {
          await _cleanupOtherUpdateFiles(
            directory,
            destination,
            release.version,
          );
          final bytes = await destination.length();
          onProgress(bytes, release.sizeBytes > 0 ? release.sizeBytes : bytes);
          return destination.path;
        }
        await destination.delete();
      }

      _throwIfCancelled(token);
      await directory.create(recursive: true);
      await _cleanupOtherUpdateFiles(directory, destination, release.version);
      part = File('${destination.path}.part');
      if (await part.exists()) await part.delete();
      serviceStarted = true;
      await _foregroundService.start(text: '${release.version}');

      final response = await _dio.get<ResponseBody>(
        release.downloadUrl.toString(),
        cancelToken: token,
        options: Options(responseType: ResponseType.stream),
      );
      final body = response.data;
      if (body == null) {
        throw const AppUpdateFailure(AppUpdateFailureKind.network);
      }
      if (response.statusCode == null ||
          response.statusCode! < 200 ||
          response.statusCode! >= 300) {
        throw const AppUpdateFailure(AppUpdateFailureKind.network);
      }
      if (response.realUri.scheme != 'https' ||
          response.redirects.any(
            (redirect) => redirect.location.scheme != 'https',
          )) {
        throw const AppUpdateFailure(AppUpdateFailureKind.invalidFile);
      }

      final digestSink = _DigestSink();
      final hasher = sha256.startChunkedConversion(digestSink);
      final output = await part.open(mode: FileMode.write);
      final localizations = _systemLocalizations();
      int? lastNotificationPercent;
      var received = 0;
      try {
        await for (final chunk in body.stream) {
          _throwIfCancelled(token);
          await output.writeFrom(chunk);
          hasher.add(chunk);
          received += chunk.length;
          final total = release.sizeBytes > 0
              ? release.sizeBytes
              : int.tryParse(
                      response.headers.value(Headers.contentLengthHeader) ?? '',
                    ) ??
                    -1;
          onProgress(received, total);
          if (total > 0) {
            final percent = (received * 100 ~/ total).clamp(0, 100);
            if (percent != lastNotificationPercent) {
              lastNotificationPercent = percent;
              await _foregroundService.update(
                text:
                    '${release.version} · ${formatByteSize(localizations, received, compact: true)} / ${formatByteSize(localizations, total, compact: true)}',
              );
            }
          }
        }
      } finally {
        try {
          await output.close();
        } finally {
          hasher.close();
        }
      }

      _throwIfCancelled(token);
      if (received == 0 ||
          (release.sizeBytes > 0 && received != release.sizeBytes) ||
          digestSink.value.toString() != digest) {
        throw const AppUpdateFailure(AppUpdateFailureKind.invalidFile);
      }
      await part.rename(destination.path);
      return destination.path;
    } on AppUpdateFailure {
      await _deletePart(part);
      rethrow;
    } on DioException catch (error) {
      await _deletePart(part);
      if (token.isCancelled || error.type == DioExceptionType.cancel) {
        throw const AppUpdateFailure(AppUpdateFailureKind.cancelled);
      }
      throw const AppUpdateFailure(AppUpdateFailureKind.network);
    } on FileSystemException {
      await _deletePart(part);
      throw const AppUpdateFailure(AppUpdateFailureKind.storage);
    } on Object {
      await _deletePart(part);
      if (token.isCancelled) {
        throw const AppUpdateFailure(AppUpdateFailureKind.cancelled);
      }
      throw const AppUpdateFailure(AppUpdateFailureKind.network);
    } finally {
      if (serviceStarted) {
        try {
          await _foregroundService.stop();
        } on Object {
          // Service cleanup must not replace the download result.
        }
      }
    }
  }

  @override
  Future<void> cancel() async {
    final token = _activeToken;
    if (token == null) return;
    token.cancel('App update cancelled');
    await _activeDownload?.then<void>((_) {}, onError: (_, _) {});
  }

  @override
  Future<bool> canInstall() async {
    if (_platform != TargetPlatform.android) return false;
    try {
      return await _installer.invokeMethod<bool>('canInstall') ?? false;
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.permission);
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    if (_platform != TargetPlatform.android) {
      throw const AppUpdateFailure(AppUpdateFailureKind.permission);
    }
    try {
      await _installer.invokeMethod<void>('openInstallPermissionSettings');
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.permission);
    }
  }

  @override
  Future<void> install(String filePath) async {
    if (_platform != TargetPlatform.android) {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }
    try {
      final directory = await _updatesDirectory();
      final root = path.canonicalize(directory.path);
      final candidate = path.canonicalize(path.absolute(filePath));
      final file = File(candidate);
      if (!path.isWithin(root, candidate) ||
          !candidate.toLowerCase().endsWith('.apk') ||
          !await file.exists()) {
        throw const AppUpdateFailure(AppUpdateFailureKind.invalidFile);
      }
      await _installer.invokeMethod<void>('install', {'path': candidate});
    } on AppUpdateFailure {
      rethrow;
    } on PlatformException catch (error) {
      throw AppUpdateFailure(switch (error.code) {
        'invalid_apk' => AppUpdateFailureKind.invalidFile,
        'install_permission_required' => AppUpdateFailureKind.permission,
        _ => AppUpdateFailureKind.install,
      });
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }
  }

  Future<Directory> _updatesDirectory() async =>
      Directory(path.join((await _supportDirectory()).path, 'app_updates'));

  bool _validRelease(AppRelease release, String digest) =>
      release.downloadUrl.scheme == 'https' &&
      release.downloadUrl.host.isNotEmpty &&
      release.sizeBytes >= 0 &&
      _sha256Pattern.hasMatch(digest);

  Future<bool> _matchesFile(
    File file,
    AppRelease release,
    String digest,
  ) async {
    if (!_validRelease(release, digest)) return false;
    final length = await file.length();
    if (release.sizeBytes > 0 && length != release.sizeBytes) return false;
    final digestSink = _DigestSink();
    final hasher = sha256.startChunkedConversion(digestSink);
    await for (final chunk in file.openRead()) {
      hasher.add(chunk);
    }
    hasher.close();
    return digestSink.value.toString() == digest;
  }

  String _filePath(Directory directory, AppRelease release, String digest) =>
      path.join(directory.path, 'iris-${release.version}-$digest.apk');

  String? _digest(AppRelease release) {
    final digest = release.sha256;
    return digest != null && _sha256Pattern.hasMatch(digest) ? digest : null;
  }

  Future<void> _deletePart(File? part) async {
    if (part == null) return;
    try {
      if (await part.exists()) await part.delete();
    } on FileSystemException {
      // A leftover .part is removed before the next attempt.
    }
  }

  Future<void> _cleanupOtherUpdateFiles(
    Directory directory,
    File keep,
    AppVersion currentVersion,
  ) async {
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = path.basename(entity.path);
      final match = _ownedFilePattern.firstMatch(name);
      final version = AppVersion.tryParse(match?.group(1) ?? '');
      if (match == null ||
          version == null ||
          version.compareTo(currentVersion) >= 0 ||
          name == path.basename(keep.path) ||
          name == '${path.basename(keep.path)}.part') {
        continue;
      }
      await entity.delete();
    }
  }
}

AppLocalizations _systemLocalizations() => lookupAppLocalizations(
  basicLocaleListResolution(
    PlatformDispatcher.instance.locales,
    AppLocalizations.supportedLocales,
  ),
);

void _throwIfCancelled(CancelToken token) {
  final error = token.cancelError;
  if (error != null) throw error;
}

class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest digest) => value = digest;

  @override
  void close() {}
}
