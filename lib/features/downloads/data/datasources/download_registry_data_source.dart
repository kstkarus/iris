import 'dart:convert';
import 'dart:io';

import 'package:iris/features/downloads/data/models/download_item_model.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';

class DownloadRegistryDataSource {
  DownloadRegistryDataSource({required File registryFile})
    : _registryFile = registryFile;

  final File _registryFile;
  Future<void> _pendingWrite = Future.value();

  Future<List<DownloadItem>> readDownloads() async {
    final primary = await _tryRead(_registryFile);
    if (primary != null) {
      return primary;
    }

    final backup = await _tryRead(_backupFile);
    return backup ?? const [];
  }

  Future<void> writeDownloads(List<DownloadItem> downloads) {
    final snapshot = List<DownloadItem>.unmodifiable(downloads);
    final operation = _pendingWrite.then(
      (_) => _writeDownloads(snapshot),
      onError: (_, _) => _writeDownloads(snapshot),
    );
    _pendingWrite = operation;
    return operation;
  }

  File get _temporaryFile => File('${_registryFile.path}.tmp');
  File get _backupFile => File('${_registryFile.path}.bak');

  Future<List<DownloadItem>?> _tryRead(File file) async {
    try {
      if (!await file.exists()) {
        return null;
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List<Object?>) {
        return null;
      }

      final downloads = <DownloadItem>[];
      for (final entry in decoded) {
        if (entry is! Map<Object?, Object?>) {
          continue;
        }

        try {
          final json = entry.cast<String, Object?>();
          downloads.add(DownloadItemModel.fromJson(json).toDomain());
        } on Object {
          continue;
        }
      }
      return List<DownloadItem>.unmodifiable(downloads);
    } on Object {
      return null;
    }
  }

  Future<void> _writeDownloads(List<DownloadItem> downloads) async {
    await _registryFile.parent.create(recursive: true);
    await _recoverInterruptedReplacement();

    final temporaryFile = _temporaryFile;
    try {
      final encoded = jsonEncode(
        downloads
            .map(DownloadItemModel.fromDomain)
            .map((model) => model.toJson())
            .toList(growable: false),
      );
      await temporaryFile.writeAsString(encoded, flush: true);
      await _replaceWith(temporaryFile);
    } finally {
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
    }
  }

  Future<void> _recoverInterruptedReplacement() async {
    final backupFile = _backupFile;
    if (!await backupFile.exists()) {
      return;
    }

    if (await _registryFile.exists()) {
      await backupFile.delete();
      return;
    }

    await backupFile.rename(_registryFile.path);
  }

  Future<void> _replaceWith(File temporaryFile) async {
    final backupFile = _backupFile;
    final hadRegistry = await _registryFile.exists();
    if (hadRegistry) {
      await _registryFile.rename(backupFile.path);
    }

    try {
      await temporaryFile.rename(_registryFile.path);
    } on Object {
      if (hadRegistry &&
          !await _registryFile.exists() &&
          await backupFile.exists()) {
        await backupFile.rename(_registryFile.path);
      }
      rethrow;
    }

    if (await backupFile.exists()) {
      await backupFile.delete();
    }
  }
}
