import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:iris/features/app_update/data/repositories/app_update_file_downloader.dart';
import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_download_repository.dart';

class WindowsAppUpdateDownloadRepository
    implements AppUpdateDownloadRepository {
  WindowsAppUpdateDownloadRepository({
    required Dio dio,
    required Future<void> Function() prepareForRestart,
    Future<Directory> Function()? supportDirectory,
    MethodChannel installer = const MethodChannel('iris/app_update'),
    TargetPlatform? platform,
  }) : _prepareForRestart = prepareForRestart,
       _installer = installer,
       _platform = platform ?? defaultTargetPlatform,
       _files = AppUpdateFileDownloader(
         dio: dio,
         supportDirectory: supportDirectory ?? getApplicationSupportDirectory,
         extension: '.exe',
       );

  final Future<void> Function() _prepareForRestart;
  final MethodChannel _installer;
  final TargetPlatform _platform;
  final AppUpdateFileDownloader _files;
  final _knownReleases = <String, AppRelease>{};

  @override
  Future<String?> restore(AppRelease release) async {
    final filePath = await _files.restore(release);
    if (filePath != null) _knownReleases[_pathKey(filePath)] = release;
    return filePath;
  }

  @override
  Future<String> download(
    AppRelease release, {
    required void Function(int received, int total) onProgress,
  }) async {
    final filePath = await _files.download(
      release,
      onProgress: onProgress,
      platformAllowed: _platform == TargetPlatform.windows,
    );
    _knownReleases[_pathKey(filePath)] = release;
    return filePath;
  }

  @override
  Future<void> cancel() => _files.cancel();

  @override
  Future<bool> canInstall() async {
    if (_platform != TargetPlatform.windows) return false;
    try {
      return await _installationDirectory() != null;
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    if (_platform != TargetPlatform.windows) {
      throw const AppUpdateFailure(AppUpdateFailureKind.permission);
    }
    throw const AppUpdateFailure(AppUpdateFailureKind.install);
  }

  @override
  Future<void> install(String filePath) async {
    if (_platform != TargetPlatform.windows) {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }
    final release = _knownReleases[_pathKey(filePath)];
    if (release == null) {
      throw const AppUpdateFailure(AppUpdateFailureKind.invalidFile);
    }
    final String candidate;
    try {
      candidate = await _files.verifyOwnedFile(filePath, release);
    } on AppUpdateFailure {
      rethrow;
    } on FileSystemException {
      throw const AppUpdateFailure(AppUpdateFailureKind.storage);
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.invalidFile);
    }
    final String? installationDirectory;
    try {
      installationDirectory = await _installationDirectory();
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }
    if (installationDirectory == null) {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }
    try {
      await _prepareForRestart();
      final launched = await _installer.invokeMethod<bool>('install', {
        'path': candidate,
      });
      if (launched != true) {
        throw const AppUpdateFailure(AppUpdateFailureKind.install);
      }
      await _installer.invokeMethod<void>('exit');
    } on AppUpdateFailure {
      rethrow;
    } on PlatformException catch (error) {
      throw AppUpdateFailure(
        error.code == 'invalid_file'
            ? AppUpdateFailureKind.invalidFile
            : AppUpdateFailureKind.install,
      );
    } on Object {
      throw const AppUpdateFailure(AppUpdateFailureKind.install);
    }
  }

  Future<String?> _installationDirectory() =>
      _installer.invokeMethod<String>('installationDirectory');

  String _pathKey(String value) => path.canonicalize(path.absolute(value));
}
