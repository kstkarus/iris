import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as path;

import 'package:iris/features/downloads/data/adapters/app_storage_usage_adapter.dart';
import 'package:iris/features/downloads/data/adapters/download_foreground_service_adapter.dart';
import 'package:iris/features/downloads/data/adapters/libtorrent_download_engine_adapter.dart';
import 'package:iris/features/downloads/data/datasources/download_registry_data_source.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/entities/download_storage_usage.dart';
import 'package:iris/features/downloads/domain/entities/downloadable_file.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/shared/storage/directory_size.dart';
import 'package:iris/shared/storage/stream_cache_storage.dart';
import 'package:iris/shared/torrent/torrent_activity_registry.dart';
import 'package:iris/shared/torrent/torrent_key.dart';

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
  }) : _engine = engine,
       _streamCache = streamCache,
       _activityRegistry = activityRegistry ?? TorrentActivityRegistry(),
       _registry = registry,
       _downloadsDirectory = downloadsDirectory,
       _foregroundService = foregroundService,
       _storageUsageAdapter = storageUsageAdapter,
       _now = now;

  static const _supportedVideoExtensions = {
    'mkv',
    'mp4',
    'webm',
    'avi',
    'mov',
    'm4v',
    'ts',
    'm2ts',
  };

  final LibtorrentDownloadEngineAdapter _engine;
  final DownloadRegistryDataSource _registry;
  final Directory _downloadsDirectory;
  final DownloadForegroundServiceAdapter _foregroundService;
  final AppStorageUsageAdapter _storageUsageAdapter;
  final StreamCacheStorage? _streamCache;
  final TorrentActivityRegistry _activityRegistry;
  final DateTime Function() _now;
  final StreamController<List<DownloadItem>> _downloadsController =
      StreamController<List<DownloadItem>>.broadcast();
  final Map<String, _PreparedRuntime> _preparedSources = {};
  final Map<String, int> _torrentIdByDownloadId = {};
  final Map<int, String> _downloadIdByTorrentId = {};

  List<DownloadItem> _downloads = const [];
  StreamSubscription<Map<int, DownloadEngineTorrent>>? _engineSubscription;
  StreamSubscription<String>? _streamingStartedSubscription;
  StreamSubscription<String>? _streamingStoppedSubscription;
  Future<void>? _initialization;
  Future<void> _updateSerial = Future<void>.value();
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
    final streamCacheBytes = await _streamCache?.sizeBytes() ?? 0;
    // Android reports the whole app cache, which already contains the stream
    // cache; other platforms only have the folder the app owns.
    final appUsage = await _storageUsageAdapter.getUsage();
    final cacheBytes = appUsage?.cacheBytes ?? streamCacheBytes;
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
    await streamCache.clear();
    return true;
  }

  @override
  Future<List<DownloadItem>> currentDownloads() async {
    await restore();
    return List<DownloadItem>.unmodifiable(_downloads);
  }

  @override
  Future<void> delete({required String id}) async {
    await restore();
    final item = _find(id);
    if (item == null) return;

    final torrentId = _torrentIdByDownloadId.remove(id);
    if (torrentId != null) {
      _downloadIdByTorrentId.remove(torrentId);
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
    await _commit();
    unawaited(_pumpQueue());
  }

  @override
  Future<void> disposePreparedSource({required String sourceToken}) async {
    final runtime = _preparedSources.remove(sourceToken);
    if (runtime == null) return;
    final directory = runtime.metadataDirectory;
    // A borrowed torrent belongs to the active download; leave it running.
    if (directory == null) return;
    _engine.remove(runtime.torrentId, deleteFiles: true);
    if (await directory.exists() && _isInsideDownloadsRoot(directory.path)) {
      await directory.delete(recursive: true);
    }
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
    final existing = _find(id);
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
      _downloadIdByTorrentId.remove(torrentId);
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
  Future<PreparedDownloadSource> prepareSource({required String magnet}) async {
    if (magnet.trim().isEmpty) {
      throw ArgumentError.value(magnet, 'magnet', 'Magnet must not be empty.');
    }
    await restore();
    final token =
        'source-${++_sourceSequence}-${_now().microsecondsSinceEpoch}';
    final torrentKey = torrentKeyFromMagnet(magnet);
    // libtorrent maps a second add of the same info-hash onto the existing
    // torrent, so removing it later would kill the running download too.
    final sharedTorrentId = _sharedTorrentId(torrentKey);
    if (sharedTorrentId != null) {
      await _engine.waitForMetadata(sharedTorrentId);
      final files = _downloadableFiles(sharedTorrentId);
      _preparedSources[token] = _PreparedRuntime(
        torrentId: sharedTorrentId,
        magnet: magnet,
        torrentKey: torrentKey,
        metadataDirectory: null,
      );
      return PreparedDownloadSource(sourceToken: token, files: files);
    }

    final directory = Directory(
      path.join(_downloadsDirectory.path, '.metadata', token),
    );
    await directory.create(recursive: true);
    final torrentId = _engine.addMagnet(
      magnet: magnet,
      savePath: directory.path,
      metadataOnly: true,
    );
    try {
      await _engine.waitForMetadata(torrentId);
      final files = _downloadableFiles(torrentId);
      _preparedSources[token] = _PreparedRuntime(
        torrentId: torrentId,
        magnet: magnet,
        torrentKey: torrentKey,
        metadataDirectory: directory,
      );
      return PreparedDownloadSource(sourceToken: token, files: files);
    } catch (_) {
      _engine.remove(torrentId, deleteFiles: true);
      if (await directory.exists()) await directory.delete(recursive: true);
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
                    errorMessage: 'Downloaded file is missing.',
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
    await _updateSerial;
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
        _updateSerial = _updateSerial.then(
          (_) => _handleEngineUpdates(torrents),
          onError: (_, _) => _handleEngineUpdates(torrents),
        );
      });
    }();
  }

  Future<void> _handleEngineUpdates(
    Map<int, DownloadEngineTorrent> torrents,
  ) async {
    final activeId = _activeDownloadId;
    if (activeId == null) return;
    final torrentId = _torrentIdByDownloadId[activeId];
    final torrent = torrentId == null ? null : torrents[torrentId];
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
    }

    if (torrent.isFinished) {
      final file = File(item.localPath);
      if (!await file.exists()) {
        await _failActive(item, 'Downloaded file was not created.');
        return;
      }
      _replace(
        updated.copyWith(
          downloadedBytes: item.totalBytes,
          downloadRateBytesPerSecond: 0,
          peers: 0,
          status: DownloadStatus.completed,
          completedAt: _now(),
          errorMessage: null,
        ),
      );
      _engine.remove(torrentId!, deleteFiles: false);
      _torrentIdByDownloadId.remove(activeId);
      _downloadIdByTorrentId.remove(torrentId);
      _clearActiveDownload();
      await _foregroundService.stop();
      await _commit();
      unawaited(_pumpQueue());
    }
  }

  Future<void> _failActive(DownloadItem item, String message) async {
    final torrentId = _torrentIdByDownloadId.remove(item.id);
    if (torrentId != null) {
      _downloadIdByTorrentId.remove(torrentId);
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
      _downloadIdByTorrentId.remove(torrentId);
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
      final item = _nextStartableDownload();
      if (item == null) return;
      final directory = _downloadDirectory(item.id);
      await directory.create(recursive: true);
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
            errorMessage: 'Unable to start the download.',
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
      _downloadIdByTorrentId[torrentId] = item.id;
      _replace(item.copyWith(status: DownloadStatus.downloading));
      await _commit();
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
          await _failActive(current, 'Unable to start the download.');
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
      if (item.status != DownloadStatus.queued) continue;
      final torrentKey = torrentKeyFromMagnet(item.magnet);
      // Wait until a selection screen or the player holding the same torrent
      // is closed.
      if (_ownedPreparedTorrentId(torrentKey) != null) continue;
      if (_activityRegistry.isStreaming(torrentKey)) continue;
      return item;
    }
    return null;
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

  List<DownloadableFile> _downloadableFiles(int torrentId) {
    final files =
        _engine
            .getFiles(torrentId)
            .where((file) => file.isStreamable && _isSupportedVideo(file.name))
            .map(
              (file) => DownloadableFile(
                index: file.index,
                name: file.name,
                relativePath: file.relativePath,
                size: file.size,
                extension: _extension(file.name),
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

  final int torrentId;
  final String magnet;
  final String torrentKey;

  /// Null when the torrent is borrowed from the active download and must not
  /// be removed together with this source.
  final Directory? metadataDirectory;
}

bool _isSupportedVideo(String name) {
  return DownloadsRepositoryImpl._supportedVideoExtensions.contains(
    _extension(name),
  );
}

String _extension(String name) {
  return path.extension(name).replaceFirst('.', '').toLowerCase();
}

String _createDownloadId(String magnet, int fileIndex) {
  return '${torrentKeyFromMagnet(magnet)}-$fileIndex';
}
