import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:iris/features/downloads/data/adapters/app_storage_usage_adapter.dart';
import 'package:iris/features/downloads/data/adapters/download_foreground_service_adapter.dart';
import 'package:iris/features/downloads/data/adapters/libtorrent_download_engine_adapter.dart';
import 'package:iris/features/downloads/data/adapters/online_episode_downloader.dart';
import 'package:iris/features/downloads/data/datasources/download_registry_data_source.dart';
import 'package:iris/features/downloads/domain/entities/download_failure.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/shared/online/online_source_link.dart';
import 'package:iris/shared/storage/directory_size.dart';
import 'package:iris/shared/storage/stream_cache_storage.dart';
import 'package:iris/shared/torrent/preparation_cancelled_exception.dart';
import 'package:iris/shared/torrent/torrent_activity_registry.dart';
import 'package:iris/shared/torrent/torrent_key.dart';
import 'package:iris/shared/torrent/video_file_extensions.dart';
import 'package:iris/shared/utils/serial_queue.dart';

/// Downloads torrent files through libtorrent and online episodes through
/// [OnlineEpisodeDownloader], one at a time from one queue.
class DownloadsRepositoryImpl implements DownloadsRepository {
  DownloadsRepositoryImpl({
    required LibtorrentDownloadEngineAdapter engine,
    required DownloadRegistryDataSource registry,
    required Directory downloadsDirectory,
    required DownloadForegroundServiceAdapter foregroundService,
    required AppStorageUsageAdapter storageUsageAdapter,
    StreamCacheStorage? streamCache,
    TorrentActivityRegistry? activityRegistry,
    OnlineEpisodeDownloader? onlineDownloader,
    DateTime Function() now = DateTime.now,
    Future<void> Function(Directory folder)? createMetadataFolder,
  }) : _engine = engine,
       _onlineDownloader = onlineDownloader,
       _streamCache = streamCache,
       _activityRegistry = activityRegistry ?? TorrentActivityRegistry(),
       _registry = registry,
       _downloadsDirectory = downloadsDirectory,
       _foregroundService = foregroundService,
       _storageUsageAdapter = storageUsageAdapter,
       _createMetadataFolder = createMetadataFolder ?? _createFolder,
       _now = now;

  final LibtorrentDownloadEngineAdapter _engine;

  /// Null where online episodes cannot be downloaded (mock setups).
  final OnlineEpisodeDownloader? _onlineDownloader;
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

  /// Online releases whose episodes a selection screen shows, by token.
  final Map<String, OnlineSourceLink> _preparedReleases = {};

  /// The active download when it is an online episode.
  OnlineDownloadTask? _onlineTask;
  final Map<String, int> _torrentIdByDownloadId = {};
  // Downloads whose files are being removed; a queued start must skip them.
  final Set<String> _deletingIds = {};

  List<DownloadItem> _downloads = const [];
  StreamSubscription<Map<int, DownloadEngineTorrent>>? _engineSubscription;
  StreamSubscription<String>? _streamingStartedSubscription;
  StreamSubscription<String>? _streamingStoppedSubscription;
  Future<void>? _initialization;
  Future<void>? _restoration;
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
    final appBytes = await _storageUsageAdapter.totalBytes();
    return DownloadStorageUsage(
      downloadsBytes: downloadsBytes,
      cacheBytes: cacheBytes,
      totalBytes: appBytes ?? downloadsBytes + cacheBytes,
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
      // The task must let go of its files before they can be removed.
      await _stopOnline(id);
      if (_releaseTorrent(id, deleteFiles: true)) {
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
        current.stopped(switch (current.status) {
          DownloadStatus.downloading ||
          DownloadStatus.queued => DownloadStatus.paused,
          final status => status,
        }),
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
    if (_preparedReleases.remove(sourceToken) != null) return;
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
    final release = _preparedReleases[source.sourceToken];
    if (release != null) {
      return _enqueueEpisode(
        source: source,
        release: release,
        file: file,
        animeId: animeId,
        animeTitle: animeTitle,
        sourceTitle: sourceTitle,
      );
    }
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

  /// Queues episode [file] of an online [release]. Its video's name is
  /// known once its stream is: [DownloadItem.localPath] names the folder
  /// until then.
  Future<DownloadItem> _enqueueEpisode({
    required PreparedDownloadSource source,
    required OnlineSourceLink release,
    required DownloadableFile file,
    required String animeId,
    required String animeTitle,
    required String sourceTitle,
  }) async {
    if (!source.files.contains(file)) {
      throw ArgumentError.value(file, 'file', 'File is not in the source.');
    }
    await disposePreparedSource(sourceToken: source.sourceToken);
    final id = onlineDownloadId(release, file.index);
    final existing = _find(id);
    if (existing != null) return existing;

    final directory = _downloadDirectory(id);
    await directory.create(recursive: true);
    final item = DownloadItem(
      id: id,
      animeId: animeId,
      animeTitle: animeTitle,
      sourceTitle: sourceTitle,
      magnet: release.toString(),
      fileIndex: file.index,
      fileName: file.name,
      relativePath: '',
      localPath: directory.path,
      totalBytes: 0,
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

    await _stopOnline(id);
    if (_releaseTorrent(id, deleteFiles: false, pauseFirst: true)) {
      await _foregroundService.stop();
    }
    _replace((_find(id) ?? item).stopped(DownloadStatus.paused));
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
    final release = OnlineSourceLink.tryParse(magnet);
    if (release != null) return _prepareRelease(token, release, cancelled);
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

  /// The episodes of an online [release], as files to choose from.
  Future<PreparedDownloadSource> _prepareRelease(
    String token,
    OnlineSourceLink release,
    Future<void>? cancelled,
  ) async {
    final downloader = _onlineDownloader;
    if (downloader == null) {
      throw UnsupportedError('Online episodes cannot be downloaded here.');
    }
    final files = await _unlessCancelled(
      downloader.episodes(release),
      cancelled,
    );
    if (files.isEmpty) {
      throw const FormatException('The release has no episodes.');
    }
    _preparedReleases[token] = release;
    return PreparedDownloadSource(
      sourceToken: token,
      files: List.unmodifiable(files),
    );
  }

  Future<void> restore() {
    if (_restored) return Future<void>.value();
    // Concurrent first calls share one read of the registry.
    return _restoration ??= _ensureInitialized()
        .then((_) => _restoreDownloads())
        .whenComplete(() {
          _restoration = null;
        });
  }

  Future<void> _restoreDownloads() async {
    final restored = await _registry.readDownloads();
    final reconciled = <DownloadItem>[];
    for (final item in restored) {
      final fileExists =
          item.status == DownloadStatus.completed &&
          await File(item.localPath).exists();
      reconciled.add(_reconcileOnRestore(item, fileExists: fileExists));
    }
    _downloads = reconciled;
    _restored = true;
    await _commit();
    unawaited(_pumpQueue());
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
    final activeId = _activeDownloadId;
    if (activeId != null) await _stopOnline(activeId);
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

    final percent = (updated.progress * 100).round();
    if (_lastNotificationPercent != percent) {
      _lastNotificationPercent = percent;
      await _foregroundService.update(text: '${item.fileName}: $percent%');
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
        current
            .stopped(DownloadStatus.completed)
            .copyWith(
              downloadedBytes: current.totalBytes,
              completedAt: _now(),
              errorMessage: null,
            ),
      );
      // Forgets the torrent id too: deleting the file later must not remove
      // whatever torrent the engine gives that id next.
      _releaseTorrent(current.id, deleteFiles: false);
      await _foregroundService.stop();
      await _commit();
      unawaited(_pumpQueue());
    }
  }

  Future<void> _failActive(DownloadItem item, String message) async {
    _releaseTorrent(item.id, deleteFiles: false);
    _replace(
      item.stopped(DownloadStatus.failed).copyWith(errorMessage: message),
    );
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
    _releaseTorrent(activeId, deleteFiles: false);
    _replace(item.stopped(DownloadStatus.queued));
    unawaited(_foregroundService.stop());
    unawaited(_commit());
    unawaited(_pumpQueue());
  }

  /// Takes the torrent of [id] out of the engine and frees the active slot
  /// when [id] held it. Returns whether it did; the caller then stops the
  /// foreground service.
  bool _releaseTorrent(
    String id, {
    required bool deleteFiles,
    bool pauseFirst = false,
  }) {
    final torrentId = _torrentIdByDownloadId.remove(id);
    if (torrentId != null) {
      if (pauseFirst) _engine.pause(torrentId);
      _engine.remove(torrentId, deleteFiles: deleteFiles);
    }
    if (_activeDownloadId != id) return false;
    _clearActiveDownload();
    return true;
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
      if (candidate.isOnline) {
        await _startEpisode(candidate);
        return;
      }
      final started = await _startCandidate(candidate);
      if (started == null) {
        _pumpRequested = true;
        return;
      }
      final (:item, :torrentId, :cancellation) = started;
      // A pause or delete during the commit has already stopped the service.
      if (cancellation.isCompleted) return;
      await _foregroundService.start(text: item.fileName);
      await _prioritizeWhenReady(item, torrentId, cancellation);
    } finally {
      _pumping = false;
      if (_pumpRequested) {
        _pumpRequested = false;
        unawaited(_pumpQueue());
      }
    }
  }

  /// Adds [candidate] to the engine and makes it the active download. Null
  /// when it cannot start now; the queue then pumps again.
  Future<({DownloadItem item, int torrentId, Completer<void> cancellation})?>
  _startCandidate(DownloadItem candidate) async {
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
      return null;
    }
    // The create above is an await: pause, delete, streaming or a selection
    // may have changed the item. Skip the start.
    final item = _find(candidate.id);
    if (item == null || !_isStartable(item)) return null;
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
      return null;
    }
    final cancellation = Completer<void>();
    _activeStartCancellation = cancellation;
    _activeDownloadId = item.id;
    _activeFilePrioritized = false;
    _torrentIdByDownloadId[item.id] = torrentId;
    _replace(item.copyWith(status: DownloadStatus.downloading));
    await _commit();
    return (item: item, torrentId: torrentId, cancellation: cancellation);
  }

  /// Once the metadata is in, wants only the selected file of [item].
  Future<void> _prioritizeWhenReady(
    DownloadItem item,
    int torrentId,
    Completer<void> startCancellation,
  ) async {
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
  }

  /// Makes episode [candidate] the active download. Its task runs on its
  /// own; its end frees the slot and pumps the queue.
  Future<void> _startEpisode(DownloadItem candidate) async {
    final item = _find(candidate.id);
    final release = OnlineSourceLink.tryParse(candidate.magnet);
    final downloader = _onlineDownloader;
    if (item == null ||
        !_isStartable(item) ||
        release == null ||
        downloader == null) {
      return;
    }
    final task = downloader.start(
      link: release,
      fileIndex: item.fileIndex,
      directory: _downloadDirectory(item.id),
    );
    _onlineTask = task;
    _activeDownloadId = item.id;
    final progress = task.progress.listen(
      (update) => unawaited(_onEpisodeProgress(item.id, task, update)),
    );
    unawaited(_awaitEpisode(item.id, task, progress));
    _replace(item.copyWith(status: DownloadStatus.downloading));
    await _commit();
    // A pause or delete during the commit has already stopped the service.
    if (!identical(_onlineTask, task)) return;
    await _foregroundService.start(text: item.fileName);
  }

  Future<void> _awaitEpisode(
    String id,
    OnlineDownloadTask task,
    StreamSubscription<OnlineDownloadProgress> progress,
  ) async {
    try {
      final file = await task.done;
      if (file != null) await _finishEpisode(id, task, file);
    } on Object catch (error) {
      await _failEpisode(id, task, _episodeFailureMessage(error));
    } finally {
      await progress.cancel();
    }
  }

  Future<void> _onEpisodeProgress(
    String id,
    OnlineDownloadTask task,
    OnlineDownloadProgress update,
  ) async {
    final item = _find(id);
    if (item == null || !identical(_onlineTask, task)) return;
    final updated = item.copyWith(
      downloadedBytes: update.downloadedBytes,
      totalBytes: update.totalBytes,
      downloadRateBytesPerSecond: update.rateBytesPerSecond,
    );
    _replace(updated);
    _emit();
    _schedulePersist();
    final percent = (updated.progress * 100).round();
    if (_lastNotificationPercent != percent) {
      _lastNotificationPercent = percent;
      await _foregroundService.update(text: '${item.fileName}: $percent%');
    }
  }

  Future<void> _finishEpisode(
    String id,
    OnlineDownloadTask task,
    File file,
  ) async {
    final item = _find(id);
    if (item == null || !identical(_onlineTask, task)) return;
    final bytes = await file.length();
    // Re-read after the await: a pause or delete may have come meanwhile.
    final current = _find(id);
    if (current == null || !identical(_onlineTask, task)) return;
    _onlineTask = null;
    _replace(
      current
          .stopped(DownloadStatus.completed)
          .copyWith(
            relativePath: path.basename(file.path),
            localPath: file.path,
            totalBytes: bytes,
            downloadedBytes: bytes,
            completedAt: _now(),
            errorMessage: null,
          ),
    );
    _clearActiveDownload();
    await _foregroundService.stop();
    await _commit();
    unawaited(_pumpQueue());
  }

  Future<void> _failEpisode(
    String id,
    OnlineDownloadTask task,
    String message,
  ) async {
    final item = _find(id);
    if (item == null || !identical(_onlineTask, task)) return;
    _onlineTask = null;
    await _failActive(item, message);
  }

  /// Stops the online task of [id], if it is the active one, and waits
  /// until it has let go of its files.
  Future<void> _stopOnline(String id) async {
    final task = _onlineTask;
    if (task == null || _activeDownloadId != id) return;
    _onlineTask = null;
    _clearActiveDownload();
    await task.cancel();
    await _foregroundService.stop();
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
    // An episode shares nothing with a player or a selection screen.
    if (item.isOnline) return _onlineDownloader != null;
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

  Future<T> _unlessCancelled<T>(Future<T> work, Future<void>? cancelled) {
    if (cancelled == null) return work;
    return Future.any<T>([
      work,
      cancelled.then<T>((_) => throw const PreparationCancelledException()),
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

/// A download as it comes back after a restart: a loading one waits in the
/// queue again, and a completed one whose file is gone has failed.
DownloadItem _reconcileOnRestore(
  DownloadItem item, {
  required bool fileExists,
}) {
  return switch (item.status) {
    DownloadStatus.completed when !fileExists => item.copyWith(
      status: DownloadStatus.failed,
      errorMessage: downloadFileMissingMessage,
      completedAt: null,
    ),
    DownloadStatus.downloading ||
    DownloadStatus.queued => item.stopped(DownloadStatus.queued),
    _ => item,
  };
}

extension on DownloadItem {
  /// The item with nothing transferring.
  DownloadItem stopped(DownloadStatus status) =>
      copyWith(status: status, downloadRateBytesPerSecond: 0, peers: 0);
}

String _createDownloadId(String magnet, int fileIndex) {
  return '${torrentKeyFromMagnet(magnet)}-$fileIndex';
}

Future<void> _createFolder(Directory folder) {
  return folder.create(recursive: true);
}

/// `online-<provider>-<hash of the release>-<episode>`: a folder name on
/// every platform, and never read as a stream session or a release link.
String onlineDownloadId(OnlineSourceLink release, int fileIndex) {
  final key = torrentKeyFromMagnet('${release.provider}/${release.releaseId}');
  return 'online-${release.provider}-$key-$fileIndex';
}

/// The message stored for an episode that did not load.
String _episodeFailureMessage(Object error) => switch (error) {
  OnlineDownloadException(:final message) => message,
  FileSystemException(:final osError?) => osError.message,
  FileSystemException(:final message) => message,
  _ => downloadConnectionLostMessage,
};
