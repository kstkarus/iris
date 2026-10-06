import 'dart:async';

/// Tracks torrents that are in use for streaming so background downloads of
/// the same torrent can step aside.
///
/// Listeners are notified synchronously: when [acquireStreaming] returns, a
/// download of that torrent has already released its native handle, so the
/// player can add the magnet without hijacking the download's torrent.
class TorrentActivityRegistry {
  final Map<String, int> _streamingCounts = {};
  final StreamController<String> _streamingStarted =
      StreamController<String>.broadcast(sync: true);
  final StreamController<String> _streamingStopped =
      StreamController<String>.broadcast(sync: true);

  /// Emits a torrent key when it starts being streamed.
  Stream<String> get streamingStarted => _streamingStarted.stream;

  /// Emits a torrent key when its last streaming session ends.
  Stream<String> get streamingStopped => _streamingStopped.stream;

  bool get hasActiveStreaming => _streamingCounts.isNotEmpty;

  bool isStreaming(String torrentKey) =>
      (_streamingCounts[torrentKey] ?? 0) > 0;

  void acquireStreaming(String torrentKey) {
    final count = (_streamingCounts[torrentKey] ?? 0) + 1;
    _streamingCounts[torrentKey] = count;
    if (count == 1) _streamingStarted.add(torrentKey);
  }

  void releaseStreaming(String torrentKey) {
    final count = _streamingCounts[torrentKey];
    if (count == null) return;
    if (count > 1) {
      _streamingCounts[torrentKey] = count - 1;
      return;
    }
    _streamingCounts.remove(torrentKey);
    _streamingStopped.add(torrentKey);
  }
}
