import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:iris/features/downloads/data/adapters/app_storage_usage_adapter.dart';
import 'package:iris/features/downloads/data/adapters/download_foreground_service_adapter.dart';
import 'package:iris/features/downloads/data/adapters/libtorrent_download_engine_adapter.dart';
import 'package:iris/features/downloads/data/datasources/download_registry_data_source.dart';
import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/shared/storage/directory_size.dart';
import 'package:iris/shared/storage/stream_cache_storage.dart';
import 'package:iris/shared/torrent/preparation_cancelled_exception.dart';
import 'package:iris/shared/torrent/torrent_activity_registry.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/shared/torrent/video_file_extensions.dart';
import 'package:iris/shared/utils/serial_queue.dart';

class DownloadsRepositoryImpl implements DownloadsRepository {
  DownloadsRepositoryImpl({
    required LibtorrentDownloadEngineAdapter engine,
    required DownloadRegistryDataSource registry,
    required Directory downloadsDirectory,
    required DownloadForegroundServiceAdapter foregroundService,
    required AppStorageUsageAdapter storageUsageAdapter,
    StreamCacheStorage? streamCache,
    TorrentActivityRegistry? activityRegistry,
    DateTime Function() now = DateTime.now,
    Future<void> Function(Directory folder)? createMetadataFolder,
  }) : _engine = engine,
       _streamCache = streamCache,
       _activityRegistry = activityRegistry ?? TorrentActivityRegistry(),
       _registry = registry,
       _downloadsDirectory = downloadsDirectory,
       _foregroundService = foregroundService,
       _storageUsageAdapter = storageUsageAdapter,
       _createMetadataFolder = createMetadataFolder ?? _createFolder,
       _now = now;

  final LibtorrentDownloadEngineAdapter _engine;
  final DownloadRegistryDataSource _registry;
  final Directory _downloadsDirectory;
  final DownloadForegroundServiceAdapter _foregroundService;
  final AppStorageUsageAdapter _storageUsageAdapter;
  final StreamCacheStorage? _streamCache;
  final TorrentActivityRegistry _activityRegistry;
  final DateTime Function() _now;
  // Creates the folder of a metadata-only torrent; a seam for tests.
  final Future<void> Function(Directory folder) _createMetadataFolder;
  final StreamController<List<DownloadItem>> _downloadsController =
      StreamController<List<DownloadItem>>.broadcast();
  final Map<String, _PreparedRuntime> _preparedSources = {};
  final Map<String, int> _torrentIdByDownloadId = {};
  // Downloads whose files are being removed; a queued start must skip them.
  final Set<String> _deletingIds = {};

  List<DownloadItem> _downloads = const [];
  StreamSubscription<Map<int, DownloadEngineTorrent>>? _engineSubscription;
  StreamSubscription<String>? _streamingStartedSubscription;
  StreamSubscription<String>? _streamingStoppedSubscription;
  Future<void>? _initialization;
  final _engineUpdates = SerialQueue();
  Timer? _persistTimer;
  bool _restored = false;
  bool _pumping = false;
  bool _pumpRequested = false;
  int _sourceSequence = 0;
  String? _activeDownloadId;
  bool _activeFilePrioritized = false;
  Completer<void>? _activeStartCancellation;
  int? _lastNotificationPercent;

  @override
  Future<DownloadStorageUsage> calculateStorageUsage() async {
    await _downloadsDirectory.create(recursive: true);
    final downloadsBytes = await directorySize(_downloadsDirectory);
    // Only the stream folder: it is what clearCache empties. The rest of the
    // Android app cache, such as posters, still counts in the total.
    final cacheBytes = await _streamCache?.sizeBytes() ?? 0;
    final appUsage = await _storageUsageAdapter.getUsage();
    return DownloadStorageUsage(
      downloadsBytes: downloadsBytes,
      cacheBytes: cacheBytes,
      totalBytes: appUsage?.totalBytes ?? downloadsBytes + cacheBytes,
    );
  }

  @override
  Future<bool> clearCache() async {
    final streamCache = _streamCache;
    if (streamCache == null || _activityRegistry.hasActiveStreaming) {
      return false;
    }
    return streamCache.clear();
  }

  @override
  Future<List<DownloadItem>> currentDownloads() async {
    await restore();
    return List<DownloadItem>.unmodifiable(_downloads);
  }

  @override
  Future<bool> delete({required String id}) async {
    await restore();
    final item = _find(id);
    if (item == null || _deletingIds.contains(id)) return true;

    // Set before any await of the removal, so a queued start cannot pick the
    // item up while its files are going away.
    _deletingIds.add(id);
    var deleted = true;
    try {
      final torrentId = _torrentIdByDownloadId.remove(id);
      if (torrentId != null) {
        _engine.remove(torrentId, deleteFiles: true);
      }
      if (_activeDownloadId == id) {
        _clearActiveDownload();
        await _foregroundService.stop();
      }

      final directory = _downloadDirectory(id);
      if (await directory.exists() && _isInsideDownloadsRoot(directory.path)) {
        await directory.delete(recursive: true);
      }
      _downloads = _downloads.where((download) => download.id != id).toList();
    } on FileSystemException catch (error, stackTrace) {
      developer.log(
        'Unable to delete downloaded files.',
        name: 'iris.downloads.repository',
        error: error,
        stackTrace: stackTrace,
      );
      deleted = false;
      final current = _find(id) ?? item;
      // The torrent is gone, so a file that was loading stops; the record is
      // kept as it was otherwise, and the person can delete it again.
      _replace(
        current.copyWith(
          status: switch (current.status) {
            DownloadStatus.downloading ||
            DownloadStatus.queued => DownloadStatus.paused,
            final status => status,
          },
          downloadRateBytesPerSecond: 0,
          peers: 0,
        ),
      );
    } finally {
      _deletingIds.remove(id);
    }
    await _commit();
    unawaited(_pumpQueue());
    return deleted;
  }

  @override
  Future<void> disposePreparedSource({required String sourceToken}) async {
    final runtime = _preparedSources.remove(sourceToken);
    if (runtime == null) return;
    final directory = runtime.metadataDirectory;
    // A borrowed torrent belongs to the active download; leave it running.
    if (directory == null) return;
    _engine.remove(runtime.torrentId, deleteFiles: true);
    await _deleteMetadataFolder(directory);
    // A queued download of the same torrent may have been waiting for this.
    unawaited(_pumpQueue());
  }

  @override
  Future<DownloadItem> enqueueDownload({
    required PreparedDownloadSource source,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
  }) async {
    await restore();
    final runtime = _preparedSources[source.sourceToken];
    if (runtime == null) {
      throw StateError('Prepared download source is no longer available.');
    }
    if (!source.files.contains(file)) {
      throw ArgumentError.value(file, 'file', 'File is not in the source.');
    }

    final id = _createDownloadId(runtime.magnet, file.index);
    // By torrent and file, not id: an item queued before the hex and base32
    // keys were unified has a base32 id.
    final existing = _findFile(runtime.torrentKey, file.index);
    if (existing != null) {
      await disposePreparedSource(sourceToken: source.sourceToken);
      return existing;
    }

    await disposePreparedSource(sourceToken: source.sourceToken);
    final directory = _downloadDirectory(id);
    await directory.create(recursive: true);
    final localPath = path.normalize(
      path.join(directory.path, file.relativePath),
    );
    if (!_isWithin(directory.path, localPath)) {
      throw const FileSystemException(
        'Torrent file path leaves its directory.',
      );
    }

    final item = DownloadItem(
      id: id,
      animeId: animeId,
      animeTitle: animeTitle,
      sourceTitle: sourceTitle,
      magnet: runtime.magnet,
      fileIndex: file.index,
      fileName: file.name,
      relativePath: file.relativePath,
      localPath: localPath,
      totalBytes: file.size,
      downloadedBytes: 0,
      downloadRateBytesPerSecond: 0,
      peers: 0,
      status: DownloadStatus.queued,
      createdAt: _now(),
    );
    _downloads = [..._downloads, item];
    await _commit();
    unawaited(_pumpQueue());
    return item;
  }

  @override
  Future<DownloadItem?> findCompletedById({required String id}) async {
    await restore();
    final item = _find(id);
    if (item?.status != DownloadStatus.completed) return null;
    final file = File(item!.localPath);
    if (!await file.exists()) return null;
    return item;
  }

  @override
  Future<void> pause({required String id}) async {
    await restore();
    final item = _find(id);
    if (item == null ||
        item.status == DownloadStatus.completed ||
        item.status == DownloadStatus.failed ||
        item.status == DownloadStatus.paused) {
      return;
    }

    final torrentId = _torrentIdByDownloadId.remove(id);
    if (torrentId != null) {
      _engine.pause(torrentId);
      _engine.remove(torrentId, deleteFiles: false);
    }
    if (_activeDownloadId == id) {
      _clearActiveDownload();
      await _foregroundService.stop();
    }
    _replace(
      item.copyWith(
        status: DownloadStatus.paused,
        downloadRateBytesPerSecond: 0,
        peers: 0,
      ),
    );
    await _commit();
    unawaited(_pumpQueue());
  }

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) async {
    if (magnet.trim().isEmpty) {
      throw ArgumentError.value(magnet, 'magnet', 'Magnet must not be empty.');
    }
    await restore();
    final token =
        'source-${++_sourceSequence}-${_now().microsecondsSinceEpoch}';
    final torrentKey = torrentKeyFromMagnet(magnet);
    // A player of the same torrent, also one that is still closing, owns the
    // native torrent and removes it with its files when it ends; an add now
    // would land on that torrent.
    await _untilNotStreaming(torrentKey, cancelled);
    // libtorrent maps a second add of the same info-hash onto the existing
    // torrent, so removing it later would kill the running download too.
    final heldTorrentId = _sharedTorrentId(torrentKey);
    final _PreparedRuntime runtime;
    if (heldTorrentId != null) {
      runtime = _PreparedRuntime.borrowed(
        torrentId: heldTorrentId,
        magnet: magnet,
        torrentKey: torrentKey,
      );
    } else {
      final directory = Directory(
        path.join(_downloadsDirectory.path, '.metadata', token),
      );
      await _createMetadataFolder(directory);
      try {
        // A player may have started on the torrent during the create.
        await _untilNotStreaming(torrentKey, cancelled);
      } catch (_) {
        await _deleteMetadataFolder(directory);
        rethrow;
      }
      // The awaits above may also have let a download of the same torrent
      // start. Nothing is awaited between this check and addMagnet.
      final lateHeldTorrentId = _sharedTorrentId(torrentKey);
      if (lateHeldTorrentId != null) {
        await _deleteMetadataFolder(directory);
        runtime = _PreparedRuntime.borrowed(
          torrentId: lateHeldTorrentId,
          magnet: magnet,
          torrentKey: torrentKey,
        );
      } else {
        final torrentId = _engine.addMagnet(
          magnet: magnet,
          savePath: directory.path,
          metadataOnly: true,
        );
        runtime = _PreparedRuntime(
          torrentId: torrentId,
          magnet: magnet,
          torrentKey: torrentKey,
          metadataDirectory: directory,
        );
      }
    }
    // Registered before the wait: a queued download of the same torrent must
    // not start while the metadata is still pending.
    _preparedSources[token] = runtime;
    try {
      await _waitForMetadata(runtime.torrentId, cancelled);
      // close() disposes the sources that are still pending.
      if (!_preparedSources.containsKey(token)) {
        throw const PreparationCancelledException();
      }
      final files = _downloadableFiles(runtime.torrentId);
      return PreparedDownloadSource(sourceToken: token, files: files);
    } catch (_) {
      await disposePreparedSource(sourceToken: token);
      rethrow;
    }
  }

  @override
  Future<void> restore() {
    if (_restored) return Future<void>.value();
    return _ensureInitialized().then((_) async {
      if (_restored) return;
      final restored = await _registry.readDownloads();
      final reconciled = <DownloadItem>[];
      for (final item in restored) {
        if (item.status == DownloadStatus.completed) {
          final exists = await File(item.localPath).exists();
          reconciled.add(
            exists
                ? item
                : item.copyWith(
                    status: DownloadStatus.failed,
                    errorMessage: downloadFileMissingMessage,
                    completedAt: null,
                  ),
          );
        } else if (item.status == DownloadStatus.downloading ||
            item.status == DownloadStatus.queued) {
          reconciled.add(
            item.copyWith(
              status: DownloadStatus.queued,
              downloadRateBytesPerSecond: 0,
              peers: 0,
            ),
          );
        } else {
          reconciled.add(item);
        }
      }
      _downloads = reconciled;
      _restored = true;
      await _commit();
      unawaited(_pumpQueue());
    });
  }

  @override
  Future<void> resume({required String id}) async {
    await restore();
    final item = _find(id);
    if (item?.status != DownloadStatus.paused) return;
    _replace(item!.copyWith(status: DownloadStatus.queued, errorMessage: null));
    await _commit();
    unawaited(_pumpQueue());
  }

  @override
  Future<void> retry({required String id}) async {
    await restore();
    final item = _find(id);
    if (item?.status != DownloadStatus.failed) return;
    _replace(
      item!.copyWith(
        status: DownloadStatus.queued,
        errorMessage: null,
        completedAt: null,
      ),
    );
    await _commit();
    unawaited(_pumpQueue());
  }

  @override
  Stream<List<DownloadItem>> watchDownloads() async* {
    yield await currentDownloads();
    yield* _downloadsController.stream;
  }

  Future<void> close() async {
    _persistTimer?.cancel();
    _cancelActiveStart();
    await _streamingStartedSubscription?.cancel();
    await _streamingStoppedSubscription?.cancel();
    await _engineSubscription?.cancel();
    await _engineUpdates.idle;
    await _registry.writeDownloads(_downloads);
    for (final sourceToken in _preparedSources.keys.toList()) {
      await disposePreparedSource(sourceToken: sourceToken);
    }
    await _foregroundService.stop();
    await _downloadsController.close();
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= () async {
      await _downloadsDirectory.create(recursive: true);
      await _engine.initialize();
      _streamingStartedSubscription = _activityRegistry.streamingStarted.listen(
        _yieldToStreaming,
      );
      _streamingStoppedSubscription = _activityRegistry.streamingStopped.listen(
        (_) => unawaited(_pumpQueue()),
      );
      _engineSubscription = _engine.torrentUpdates.listen((torrents) {
        unawaited(_engineUpdates.run(() => _handleEngineUpdates(torrents)));
      });
    }();
  }

  Future<void> _handleEngineUpdates(
    Map<int, DownloadEngineTorrent> torrents,
  ) async {
    final activeId = _activeDownloadId;
    if (activeId == null) return;
    final torrentId = _torrentIdByDownloadId[activeId];
    if (torrentId == null) return;
    final torrent = torrents[torrentId];
    final item = _find(activeId);
    if (torrent == null || item == null) return;

    if (torrent.hasError) {
      await _failActive(
        item,
        torrent.errorMessage.trim().isEmpty
            ? 'Torrent download failed.'
            : torrent.errorMessage,
      );
      return;
    }
    // Until only the selected file is wanted, progress and the finished flag
    // describe the whole torrent.
    if (!_activeFilePrioritized) return;

    // `progress` covers wanted bytes only; the torrent's raw done-bytes also
    // count neighbouring files that share boundary pieces.
    final downloadedBytes = (torrent.progress.clamp(0.0, 1.0) * item.totalBytes)
        .round();
    final updated = item.copyWith(
      downloadedBytes: downloadedBytes,
      downloadRateBytesPerSecond: torrent.downloadRateBytesPerSecond,
      peers: torrent.peers,
    );
    _replace(updated);
    _emit();
    _schedulePersist();

    final percent = item.totalBytes <= 0
        ? 0
        : ((downloadedBytes / item.totalBytes) * 100).clamp(0, 100).round();
    if (_lastNotificationPercent != percent) {
      _lastNotificationPercent = percent;
      await _foregroundService.update(
        title: 'Загрузка',
        text: '${item.fileName}: $percent%',
      );
      // Pause, delete or a streaming yield may have happened during the await.
      if (_activeItemOnTorrent(activeId, torrentId) == null) return;
    }

    if (torrent.isFinished) {
      final fileExists = await File(item.localPath).exists();
      // Re-read after the await: the active slot may now belong to the next
      // download, and the item may have changed.
      final current = _activeItemOnTorrent(activeId, torrentId);
      if (current == null) return;
      if (!fileExists) {
        await _failActive(current, 'Downloaded file was not created.');
        return;
      }
      _replace(
        current.copyWith(
          downloadedBytes: current.totalBytes,
          downloadRateBytesPerSecond: 0,
          peers: 0,
          status: DownloadStatus.completed,
          completedAt: _now(),
          errorMessage: null,
        ),
      );
      _engine.remove(torrentId, deleteFiles: false);
      _clearActiveDownload();
      await _foregroundService.stop();
      await _commit();
      unawaited(_pumpQueue());
    }
  }

  Future<void> _failActive(DownloadItem item, String message) async {
    final torrentId = _torrentIdByDownloadId.remove(item.id);
    if (torrentId != null) {
      _engine.remove(torrentId, deleteFiles: false);
    }
    _replace(
      item.copyWith(
        status: DownloadStatus.failed,
        errorMessage: message,
        downloadRateBytesPerSecond: 0,
        peers: 0,
      ),
    );
    _clearActiveDownload();
    await _foregroundService.stop();
    await _commit();
    unawaited(_pumpQueue());
  }

  /// Streaming has priority: an active download of the same torrent goes back
  /// to the queue and resumes when playback ends. Runs synchronously inside
  /// [TorrentActivityRegistry.acquireStreaming] so the native torrent is gone
  /// before the player adds the magnet.
  void _yieldToStreaming(String torrentKey) {
    final activeId = _activeDownloadId;
    if (activeId == null) return;
    final item = _find(activeId);
    if (item == null || torrentKeyFromMagnet(item.magnet) != torrentKey) {
      return;
    }
    final torrentId = _torrentIdByDownloadId.remove(activeId);
    if (torrentId != null) {
      _engine.remove(torrentId, deleteFiles: false);
    }
    _clearActiveDownload();
    _replace(
      item.copyWith(
        status: DownloadStatus.queued,
        downloadRateBytesPerSecond: 0,
        peers: 0,
      ),
    );
    unawaited(_foregroundService.stop());
    unawaited(_commit());
    unawaited(_pumpQueue());
  }

  /// The active item while it still runs [torrentId]. Call this after every
  /// await: a pause, delete or streaming yield may have cleared the slot, and
  /// the next queued download may own it by now.
  DownloadItem? _activeItemOnTorrent(String activeId, int torrentId) {
    if (_activeDownloadId != activeId ||
        _torrentIdByDownloadId[activeId] != torrentId) {
      return null;
    }
    return _find(activeId);
  }

  void _clearActiveDownload() {
    _cancelActiveStart();
    _activeDownloadId = null;
    _activeFilePrioritized = false;
    _lastNotificationPercent = null;
  }

  void _cancelActiveStart() {
    final cancellation = _activeStartCancellation;
    _activeStartCancellation = null;
    if (cancellation != null && !cancellation.isCompleted) {
      cancellation.complete();
    }
  }

  Future<void> _pumpQueue() async {
    if (!_restored) return;
    if (_pumping) {
      _pumpRequested = true;
      return;
    }
    if (_activeDownloadId != null) return;
    _pumping = true;
    try {
      final candidate = _nextStartableDownload();
      if (candidate == null) return;
      final directory = _downloadDirectory(candidate.id);
      try {
        await directory.create(recursive: true);
      } on FileSystemException catch (error, stackTrace) {
        developer.log(
          'Unable to create the folder of a queued download.',
          name: 'iris.downloads.repository',
          error: error,
          stackTrace: stackTrace,
        );
        // Only a still queued item fails: a pause or delete during the create
        // has already moved it on.
        final failed = _find(candidate.id);
        if (failed != null && failed.status == DownloadStatus.queued) {
          _replace(
            failed.copyWith(
              status: DownloadStatus.failed,
              errorMessage: downloadCouldNotStartMessage,
            ),
          );
          await _commit();
        }
        _pumpRequested = true;
        return;
      }
      // The create above is an await: pause, delete, streaming or a selection
      // may have changed the item. Skip the start; the finally pumps again.
      final item = _find(candidate.id);
      if (item == null || !_isStartable(item)) {
        _pumpRequested = true;
        return;
      }
      final int torrentId;
      try {
        // Not metadata-only: that mode makes the native layer zero all file
        // priorities and pause when metadata arrives, racing our priorities.
        torrentId = _engine.addMagnet(
          magnet: item.magnet,
          savePath: directory.path,
          metadataOnly: false,
        );
      } catch (error, stackTrace) {
        developer.log(
          'Unable to add queued download to the engine.',
          name: 'iris.downloads.repository',
          error: error,
          stackTrace: stackTrace,
        );
        _replace(
          item.copyWith(
            status: DownloadStatus.failed,
            errorMessage: downloadCouldNotStartMessage,
          ),
        );
        await _commit();
        _pumpRequested = true;
        return;
      }
      final startCancellation = Completer<void>();
      _activeStartCancellation = startCancellation;
      _activeDownloadId = item.id;
      _activeFilePrioritized = false;
      _torrentIdByDownloadId[item.id] = torrentId;
      _replace(item.copyWith(status: DownloadStatus.downloading));
      await _commit();
      // A pause or delete during the commit has already stopped the service.
      if (startCancellation.isCompleted) return;
      await _foregroundService.start(title: 'Загрузка', text: item.fileName);

      try {
        // Pause/delete cancel the wait so the queue is not blocked until the
        // metadata timeout of a torrent that no longer exists.
        await Future.any([
          _engine.waitForMetadata(torrentId),
          startCancellation.future,
        ]);
        if (startCancellation.isCompleted || _activeDownloadId != item.id) {
          return;
        }
        final files = _engine.getFiles(torrentId);
        final priorities = List<int>.filled(files.length, 0);
        final target = files.where((file) => file.index == item.fileIndex);
        if (target.isEmpty || item.fileIndex >= priorities.length) {
          throw StateError('Selected torrent file is unavailable.');
        }
        // Items queued with a wrong size (e.g. by an engine that reported 0)
        // heal from the metadata on every start.
        final engineSize = target.first.size;
        final current = _find(item.id);
        if (current != null &&
            engineSize > 0 &&
            current.totalBytes != engineSize) {
          _replace(current.copyWith(totalBytes: engineSize));
          await _commit();
          if (startCancellation.isCompleted || _activeDownloadId != item.id) {
            return;
          }
        }
        priorities[item.fileIndex] = 7;
        _engine.setFilePriorities(torrentId, priorities);
        _engine.resume(torrentId);
        _activeFilePrioritized = true;
        if (identical(_activeStartCancellation, startCancellation)) {
          _activeStartCancellation = null;
        }
      } catch (error, stackTrace) {
        developer.log(
          'Unable to start queued download.',
          name: 'iris.downloads.repository',
          error: error,
          stackTrace: stackTrace,
        );
        final current = _find(item.id);
        if (current != null && _activeDownloadId == item.id) {
          await _failActive(current, downloadCouldNotStartMessage);
        }
      }
    } finally {
      _pumping = false;
      if (_pumpRequested) {
        _pumpRequested = false;
        unawaited(_pumpQueue());
      }
    }
  }

  DownloadItem? _nextStartableDownload() {
    for (final item in _downloads) {
      if (_isStartable(item)) return item;
    }
    return null;
  }

  bool _isStartable(DownloadItem item) {
    if (item.status != DownloadStatus.queued) return false;
    if (_deletingIds.contains(item.id)) return false;
    final torrentKey = torrentKeyFromMagnet(item.magnet);
    // Wait until a selection screen or the player holding the same torrent
    // is closed.
    if (_ownedPreparedTorrentId(torrentKey) != null) return false;
    return !_activityRegistry.isStreaming(torrentKey);
  }

  int? _sharedTorrentId(String torrentKey) {
    final activeId = _activeDownloadId;
    if (activeId != null) {
      final active = _find(activeId);
      final torrentId = _torrentIdByDownloadId[activeId];
      if (active != null &&
          torrentId != null &&
          torrentKeyFromMagnet(active.magnet) == torrentKey) {
        return torrentId;
      }
    }
    return _ownedPreparedTorrentId(torrentKey);
  }

  int? _ownedPreparedTorrentId(String torrentKey) {
    for (final runtime in _preparedSources.values) {
      if (runtime.metadataDirectory != null &&
          runtime.torrentKey == torrentKey) {
        return runtime.torrentId;
      }
    }
    return null;
  }

  /// Waits for the metadata of [torrentId], or gives up when [cancelled]
  /// completes first.
  Future<void> _waitForMetadata(int torrentId, Future<void>? cancelled) {
    return _unlessCancelled(_engine.waitForMetadata(torrentId), cancelled);
  }

  /// Waits while [torrentKey] is streamed, or gives up when [cancelled]
  /// completes first.
  Future<void> _untilNotStreaming(String torrentKey, Future<void>? cancelled) {
    if (!_activityRegistry.isStreaming(torrentKey)) return Future.value();
    final stopped = _activityRegistry.streamingStopped
        .firstWhere((key) => key == torrentKey)
        .then<void>((_) {});
    return _unlessCancelled(stopped, cancelled);
  }

  Future<void> _unlessCancelled(Future<void> work, Future<void>? cancelled) {
    if (cancelled == null) return work;
    return Future.any<void>([
      work,
      cancelled.then<void>((_) => throw const PreparationCancelledException()),
    ]);
  }

  List<DownloadableFile> _downloadableFiles(int torrentId) {
    final files =
        _engine
            .getFiles(torrentId)
            .where((file) => file.isStreamable && isVideoFileName(file.name))
            .map(
              (file) => DownloadableFile(
                index: file.index,
                name: file.name,
                relativePath: file.relativePath,
                size: file.size,
                extension: videoFileExtension(file.name),
              ),
            )
            .toList()
          ..sort((left, right) => left.index.compareTo(right.index));
    if (files.isEmpty) {
      throw const FormatException('Torrent has no supported video files.');
    }
    return List<DownloadableFile>.unmodifiable(files);
  }

  Future<void> _commit() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    _emit();
    await _registry.writeDownloads(_downloads);
  }

  void _schedulePersist() {
    if (_persistTimer?.isActive == true) return;
    _persistTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_registry.writeDownloads(_downloads));
    });
  }

  void _emit() {
    if (!_downloadsController.isClosed) {
      _downloadsController.add(List<DownloadItem>.unmodifiable(_downloads));
    }
  }

  DownloadItem? _findFile(String torrentKey, int fileIndex) {
    for (final item in _downloads) {
      if (item.fileIndex == fileIndex &&
          torrentKeyFromMagnet(item.magnet) == torrentKey) {
        return item;
      }
    }
    return null;
  }

  DownloadItem? _find(String id) {
    for (final item in _downloads) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _replace(DownloadItem item) {
    _downloads = _downloads
        .map((current) => current.id == item.id ? item : current)
        .toList(growable: false);
  }

  Directory _downloadDirectory(String id) {
    return Directory(path.join(_downloadsDirectory.path, 'content', id));
  }

  /// Removes a metadata folder. One that cannot be removed is logged and left
  /// behind: its source is gone either way.
  Future<void> _deleteMetadataFolder(Directory directory) async {
    try {
      if (await directory.exists() && _isInsideDownloadsRoot(directory.path)) {
        await directory.delete(recursive: true);
      }
    } on FileSystemException catch (error, stackTrace) {
      developer.log(
        'Unable to delete a metadata folder.',
        name: 'iris.downloads.repository',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool _isInsideDownloadsRoot(String candidate) {
    return _isWithin(_downloadsDirectory.path, candidate);
  }

  bool _isWithin(String parent, String candidate) {
    final normalizedParent = path.canonicalize(parent);
    final normalizedCandidate = path.canonicalize(candidate);
    return normalizedCandidate == normalizedParent ||
        path.isWithin(normalizedParent, normalizedCandidate);
  }
}

class _PreparedRuntime {
  const _PreparedRuntime({
    required this.torrentId,
    required this.magnet,
    required this.torrentKey,
    required this.metadataDirectory,
  });

  /// A torrent held by the active download or another source.
  const _PreparedRuntime.borrowed({
    required this.torrentId,
    required this.magnet,
    required this.torrentKey,
  }) : metadataDirectory = null;

  final int torrentId;
  final String magnet;
  final String torrentKey;

  /// Null when the torrent is borrowed from the active download and must not
  /// be removed together with this source.
  final Directory? metadataDirectory;
}

String _createDownloadId(String magnet, int fileIndex) {
  return '${torrentKeyFromMagnet(magnet)}-$fileIndex';
}

Future<void> _createFolder(Directory folder) {
  return folder.create(recursive: true);
}
