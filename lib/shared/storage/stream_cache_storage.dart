import 'dart:developer' as developer;
import 'dart:io';

import 'package:iris/shared/storage/directory_size.dart';
import 'package:iris/shared/utils/serial_queue.dart';

/// Owns the folder where streamed torrent pieces are written.
///
/// Streaming sessions delete their data when the player closes; whatever
/// survives a crash or a killed process is garbage by the next launch, so the
/// folder is wiped once per process before the first torrent is added.
class StreamCacheStorage {
  StreamCacheStorage({
    required this.directory,
    Future<void> Function(FileSystemEntity entity)? delete,
  }) : _delete = delete ?? _deleteRecursively;

  final Directory directory;
  final Future<void> Function(FileSystemEntity entity) _delete;
  bool _prepared = false;
  // Operations run one after another, so prepare() returns only once a clear
  // that is still deleting has finished.
  final _operations = SerialQueue();

  /// Wipes leftovers from previous runs, once. Safe to call repeatedly; waits
  /// for a clear that is still deleting.
  Future<void> prepare() {
    return _operations.run(() async {
      if (_prepared) return;
      _prepared = true;
      await _wipe();
    });
  }

  /// Deletes everything in the folder. Returns false when some entry could not
  /// be deleted, for example a file still held open on Windows.
  Future<bool> clear() {
    return _operations.run(() {
      _prepared = true;
      return _wipe();
    });
  }

  Future<int> sizeBytes() => directorySize(directory);

  Future<bool> _wipe() async {
    var complete = true;
    try {
      if (await directory.exists()) {
        await for (final entity in directory.list(followLinks: false)) {
          try {
            await _delete(entity);
          } on FileSystemException catch (error) {
            complete = false;
            developer.log(
              'Skipping stream cache entry that is still in use: ${entity.path}',
              name: 'iris.storage.stream_cache',
              error: error,
            );
          }
        }
      }
      await directory.create(recursive: true);
    } on FileSystemException catch (error, stackTrace) {
      developer.log(
        'Unable to clean the stream cache folder.',
        name: 'iris.storage.stream_cache',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
    return complete;
  }
}

Future<void> _deleteRecursively(FileSystemEntity entity) async {
  await entity.delete(recursive: true);
}
