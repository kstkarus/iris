import 'dart:developer' as developer;
import 'dart:io';

import 'package:iris/shared/storage/directory_size.dart';

/// Owns the folder where streamed torrent pieces are written.
///
/// Streaming sessions delete their data when the player closes; whatever
/// survives a crash or a killed process is garbage by the next launch, so the
/// folder is wiped once per process before the first torrent is added.
class StreamCacheStorage {
  StreamCacheStorage({required this.directory});

  final Directory directory;
  Future<void>? _preparation;

  /// Wipes leftovers from previous runs. Safe to call repeatedly.
  Future<void> prepare() => _preparation ??= _wipe();

  /// Deletes everything in the folder. Files still held open by the engine
  /// (Windows) are skipped.
  Future<void> clear() async {
    await prepare();
    await _wipe();
  }

  Future<int> sizeBytes() => directorySize(directory);

  Future<void> _wipe() async {
    try {
      if (await directory.exists()) {
        await for (final entity in directory.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } on FileSystemException catch (error) {
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
    }
  }
}
