import 'dart:convert';
import 'dart:io';

import 'package:iris/features/downloads/data/models/download_item_model.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/shared/utils/serial_queue.dart';

class DownloadRegistryDataSource {
  DownloadRegistryDataSource({required File registryFile})
    : _registryFile = registryFile;

  final File _registryFile;
  final _writes = SerialQueue();

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
    return _writes.run(() => _writeDownloads(snapshot));
  }

  File get _temporaryFile => File('${_registryFile.path}.tmp');
  File get _backupFile => File('${_registryFile.path}.bak');

  /// The downloads [file] lists, or null when it is missing or unreadable
  /// as a list. A file that cannot be read now (the disk, not the content)
  /// throws, so nothing is written over it and the next read tries again.
  /// What does not parse is kept aside, as the next write replaces it.
  Future<List<DownloadItem>?> _tryRead(File file) async {
    if (!await file.exists()) {
      return null;
    }
    // Bytes first: a read that fails throws, broken text does not.
    final bytes = await file.readAsBytes();
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      await _keepAside(file);
      return null;
    }
    if (decoded is! List<Object?>) {
      await _keepAside(file);
      return null;
    }

    final downloads = <DownloadItem>[];
    var skipped = false;
    for (final entry in decoded) {
      try {
        final json = (entry! as Map<Object?, Object?>).cast<String, Object?>();
        downloads.add(DownloadItemModel.fromJson(json));
      } on Object {
        skipped = true;
      }
    }
    if (skipped) await _keepAside(file);
    return List<DownloadItem>.unmodifiable(downloads);
  }

  /// A copy of [file] next to it, for whoever wants to look into it.
  Future<void> _keepAside(File file) async {
    try {
      await file.copy('${file.path}.corrupt');
    } on FileSystemException {
      // Only a courtesy.
    }
  }

  Future<void> _writeDownloads(List<DownloadItem> downloads) async {
    await _registryFile.parent.create(recursive: true);
    await _recoverInterruptedReplacement();

    final temporaryFile = _temporaryFile;
    try {
      final encoded = jsonEncode(
        downloads.map(DownloadItemModel.toJson).toList(growable: false),
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
